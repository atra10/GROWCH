"""Transcribe — offline audio-to-text desktop app (Windows / macOS / Linux)."""
from __future__ import annotations

import json
import os
import queue
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

if getattr(sys, "frozen", False):  # packaged Transcribe.exe has no console: log to a file instead
    _log = open(Path(sys.executable).resolve().parent / "transcribe.log", "a", encoding="utf-8", buffering=1)
    sys.stdout = sys.stdout or _log
    sys.stderr = sys.stderr or _log
    os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")

import local_ai
import transcriber as T

SETTINGS = T.APP_DIR / "settings.json"
AUDIO_TYPES = [("Audio / video", "*.mp3 *.wav *.m4a *.aac *.ogg *.opus *.flac *.wma *.amr *.3gp *.webm *.mp4 *.mkv *.mov"),
               ("All files", "*.*")]


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Transcribe — offline")
        self.geometry("1060x760")
        self.minsize(760, 560)
        self.q: queue.Queue = queue.Queue()
        self.cancel = threading.Event()
        self.busy = False
        self.files: list[str] = []
        self.results: dict[str, T.Result] = {}
        self.summaries: dict[str, str] = {}
        self.current: str | None = None
        self.prefs = self._load_prefs()
        self._build()
        self.after(100, self._poll)
        self.after(300, self._refresh_ai_models)

    # ---------- settings ----------
    def _load_prefs(self) -> dict:
        try:
            return json.loads(SETTINGS.read_text(encoding="utf-8"))
        except Exception:
            return {}

    def _save_prefs(self, *_):
        p = {"model": self.model.get(), "lang": self.lang.get(), "gpu": self.gpu.get(),
             "hotwords": self.hotwords.get(), "autosave": self.autosave.get(), "ai_model": self.ai_model.get()}
        try:
            SETTINGS.write_text(json.dumps(p, indent=1), encoding="utf-8")
        except OSError:
            pass

    # ---------- layout ----------
    def _build(self):
        style = ttk.Style(self)
        if "clam" in style.theme_names() and self.tk.call("tk", "windowingsystem") == "x11":
            style.theme_use("clam")
        style.configure("Accent.TButton", font=("TkDefaultFont", 10, "bold"))
        pad = dict(padx=10, pady=6)

        root = ttk.Frame(self, padding=10)
        root.pack(fill="both", expand=True)
        root.columnconfigure(1, weight=1)
        root.rowconfigure(1, weight=1)

        # left: files
        left = ttk.LabelFrame(root, text="Audio files", padding=8)
        left.grid(row=0, column=0, rowspan=2, sticky="nsw", padx=(0, 10))
        left.rowconfigure(0, weight=1)
        self.listbox = tk.Listbox(left, width=26, activestyle="none", exportselection=False)
        self.listbox.grid(row=0, column=0, columnspan=2, sticky="nsew")
        self.listbox.bind("<<ListboxSelect>>", self._on_select)
        ttk.Button(left, text="Add files…", command=self._add_files).grid(row=1, column=0, sticky="ew", pady=(8, 0))
        ttk.Button(left, text="Remove", command=self._remove_file).grid(row=1, column=1, sticky="ew", pady=(8, 0))

        # right top: settings
        st = ttk.LabelFrame(root, text="Settings", padding=8)
        st.grid(row=0, column=1, sticky="new")
        st.columnconfigure(1, weight=1)
        ttk.Label(st, text="Language").grid(row=0, column=0, sticky="w")
        self.lang = tk.StringVar(value=self.prefs.get("lang", next(iter(T.LANGUAGES))))
        if self.lang.get() not in T.LANGUAGES:
            self.lang.set(next(iter(T.LANGUAGES)))
        ttk.Combobox(st, textvariable=self.lang, values=list(T.LANGUAGES), state="readonly").grid(row=0, column=1, sticky="ew", **pad)

        ttk.Label(st, text="Model").grid(row=1, column=0, sticky="w")
        self.model = tk.StringVar(value=self.prefs.get("model", "large-v3-turbo"))
        if self.model.get() not in T.MODELS:
            self.model.set("large-v3-turbo")
        mrow = ttk.Frame(st)
        mrow.grid(row=1, column=1, sticky="ew", **pad)
        ttk.Combobox(mrow, textvariable=self.model, values=list(T.MODELS), state="readonly", width=16).pack(side="left")
        self.model_note = ttk.Label(mrow, foreground="#666")
        self.model_note.pack(side="left", padx=8)
        self.model.trace_add("write", lambda *_: self._update_model_note())

        ttk.Label(st, text="Names / terms").grid(row=2, column=0, sticky="w")
        self.hotwords = tk.StringVar(value=self.prefs.get("hotwords", ""))
        e = ttk.Entry(st, textvariable=self.hotwords)
        e.grid(row=2, column=1, sticky="ew", **pad)
        ttk.Label(st, text="Optional: names or jargon in the audio (e.g. “Pak Budi, Cirebon, invoice”) so they're spelled right.",
                  foreground="#666", wraplength=440).grid(row=3, column=1, sticky="w", padx=10)

        opts = ttk.Frame(st)
        opts.grid(row=4, column=0, columnspan=2, sticky="w", pady=(6, 0))
        self.gpu = tk.BooleanVar(value=self.prefs.get("gpu", True))
        ttk.Checkbutton(opts, text="Use NVIDIA graphics card if available", variable=self.gpu).pack(side="left")
        self.autosave = tk.BooleanVar(value=self.prefs.get("autosave", True))
        ttk.Checkbutton(opts, text="Save .txt and .srt next to each audio file", variable=self.autosave).pack(side="left", padx=16)
        for v in (self.lang, self.model, self.gpu, self.hotwords, self.autosave):
            v.trace_add("write", self._save_prefs)

        run = ttk.Frame(st)
        run.grid(row=5, column=0, columnspan=2, sticky="ew", pady=(10, 0))
        run.columnconfigure(2, weight=1)
        self.go = ttk.Button(run, text="Transcribe", style="Accent.TButton", command=self._start)
        self.go.grid(row=0, column=0)
        self.stop = ttk.Button(run, text="Cancel", command=self.cancel.set, state="disabled")
        self.stop.grid(row=0, column=1, padx=6)
        self.progress = ttk.Progressbar(run, maximum=1000)
        self.progress.grid(row=0, column=2, sticky="ew", padx=6)
        self.status = ttk.Label(st, text="Add audio files to start.", foreground="#444")
        self.status.grid(row=6, column=0, columnspan=2, sticky="w", pady=(6, 0))

        # right bottom: output
        out = ttk.Frame(root)
        out.grid(row=1, column=1, sticky="nsew", pady=(10, 0))
        out.columnconfigure(0, weight=1)
        out.rowconfigure(0, weight=1)
        self.tabs = ttk.Notebook(out)
        self.tabs.grid(row=0, column=0, sticky="nsew")
        self.txt_plain = self._text_tab("Transcript")
        self.txt_times = self._text_tab("With timestamps")
        self.txt_ai = self._text_tab("AI summary")

        bar = ttk.Frame(out)
        bar.grid(row=1, column=0, sticky="ew", pady=(8, 0))
        ttk.Button(bar, text="Copy", command=self._copy).pack(side="left")
        ttk.Button(bar, text="Save .txt…", command=self._save_txt).pack(side="left", padx=6)
        ttk.Button(bar, text="Save .srt…", command=self._save_srt).pack(side="left")
        bar2 = ttk.Frame(out)
        bar2.grid(row=2, column=0, sticky="ew", pady=(8, 0))
        bar = bar2
        ttk.Label(bar, text="Local AI (Ollama):").pack(side="left")
        self.ai_model = tk.StringVar(value=self.prefs.get("ai_model", local_ai.DEFAULT_MODEL))
        self.ai_combo = ttk.Combobox(bar, textvariable=self.ai_model, width=18)
        self.ai_combo.pack(side="left", padx=6)
        self.ai_model.trace_add("write", self._save_prefs)
        self.btn_sum = ttk.Button(bar, text="Summarize", command=lambda: self._ai("summary"))
        self.btn_sum.pack(side="left")
        self.btn_tidy = ttk.Button(bar, text="Tidy text", command=lambda: self._ai("tidy"))
        self.btn_tidy.pack(side="left", padx=6)
        self._update_model_note()

    def _text_tab(self, title: str) -> tk.Text:
        f = ttk.Frame(self.tabs)
        f.rowconfigure(0, weight=1)
        f.columnconfigure(0, weight=1)
        t = tk.Text(f, wrap="word", undo=True, font=("TkDefaultFont", 11), padx=10, pady=8, relief="flat")
        sb = ttk.Scrollbar(f, command=t.yview)
        t.configure(yscrollcommand=sb.set)
        t.grid(row=0, column=0, sticky="nsew")
        sb.grid(row=0, column=1, sticky="ns")
        self.tabs.add(f, text=title)
        return t

    def _update_model_note(self):
        name = self.model.get()
        note = T.MODELS[name][2]
        ready = T.is_downloaded(name)
        self.model_note.configure(text=note + ("  ✓ downloaded" if ready else "  · downloads on first use"))

    # ---------- files ----------
    def _add_files(self):
        paths = filedialog.askopenfilenames(title="Choose audio or video files", filetypes=AUDIO_TYPES)
        for p in paths:
            if p not in self.files:
                self.files.append(p)
                self.listbox.insert("end", "   " + Path(p).name)
        if paths and self.current is None:
            self.listbox.selection_set(0)
            self._on_select()
        if self.files and not self.busy:
            self.status.configure(text=f"{len(self.files)} file(s) ready. Press Transcribe.")

    def _remove_file(self):
        sel = self.listbox.curselection()
        if not sel or self.busy:
            return
        i = sel[0]
        p = self.files.pop(i)
        self.listbox.delete(i)
        self.results.pop(p, None)
        self.summaries.pop(p, None)
        self.current = None
        self._show(None)

    def _mark(self, path: str, mark: str):
        i = self.files.index(path)
        self.listbox.delete(i)
        self.listbox.insert(i, f"{mark} {Path(path).name}")
        if self.current == path:
            self.listbox.selection_set(i)

    def _on_select(self, *_):
        sel = self.listbox.curselection()
        if sel:
            self.current = self.files[sel[0]]
            self._show(self.current)

    def _show(self, path):
        for t in (self.txt_plain, self.txt_times, self.txt_ai):
            t.delete("1.0", "end")
        if path and path in self.results:
            r = self.results[path]
            self.txt_plain.insert("1.0", r.text)
            self.txt_times.insert("1.0", T.to_timestamped(r.segments))
        if path and path in self.summaries:
            self.txt_ai.insert("1.0", self.summaries[path])

    # ---------- transcription ----------
    def _set_busy(self, busy: bool):
        self.busy = busy
        self.go.configure(state="disabled" if busy else "normal")
        self.stop.configure(state="normal" if busy else "disabled")
        for b in (self.btn_sum, self.btn_tidy):
            b.configure(state="disabled" if busy else "normal")

    def _start(self):
        todo = [p for p in self.files if p not in self.results]
        if not todo:
            sel = self.listbox.curselection()
            if sel:  # everything done: re-run the selected file (e.g. with other settings)
                todo = [self.files[sel[0]]]
            else:
                messagebox.showinfo("Transcribe", "Add audio files first.")
                return
        self.cancel.clear()
        self._set_busy(True)
        args = dict(model_name=self.model.get(), language=self.lang.get(), use_gpu=self.gpu.get(),
                    hotwords=self.hotwords.get())
        threading.Thread(target=self._worker, args=(todo, args, self.autosave.get()), daemon=True).start()

    def _worker(self, todo, args, autosave):
        put = self.q.put
        for n, path in enumerate(todo, 1):
            if self.cancel.is_set():
                break
            put(("start", path, n, len(todo)))
            try:
                r = T.transcribe(path, **args,
                                 on_status=lambda s: put(("status", s)),
                                 on_download=lambda f: put(("download", f)),
                                 on_segment=lambda seg, frac, p=path: put(("segment", p, seg, frac)),
                                 cancel=self.cancel)
            except Exception as e:
                put(("error", path, str(e)))
                continue
            if self.cancel.is_set():
                put(("cancelled", path, r))
                break
            saved = ""
            if autosave and r.segments:
                try:
                    base = Path(path).with_suffix("")
                    Path(f"{base}.txt").write_text(r.text + "\n", encoding="utf-8")
                    Path(f"{base}.srt").write_text(T.to_srt(r.segments), encoding="utf-8")
                    saved = f"{base.name}.txt / .srt"
                except OSError as e:
                    saved = f"couldn't save next to the file ({e})"
            put(("done", path, r, saved))
        put(("finished",))

    def _poll(self):
        try:
            while True:
                self._handle(self.q.get_nowait())
        except queue.Empty:
            pass
        self.after(100, self._poll)

    def _handle(self, m):
        kind = m[0]
        if kind == "status":
            self.status.configure(text=self._prefix + m[1])
        elif kind == "download":
            self.progress.configure(value=int(m[1] * 1000))
        elif kind == "start":
            _, path, n, total = m
            self._prefix = f"[{n}/{total}] {Path(path).name}: " if total > 1 else ""
            self.results.pop(path, None)
            self.current = path
            self.listbox.selection_clear(0, "end")
            self._mark(path, "…")
            self._show(path)
            self.progress.configure(value=0)
        elif kind == "segment":
            _, path, seg, frac = m
            self.progress.configure(value=int(frac * 1000))
            if self.current == path:
                self.txt_plain.insert("end", (" " if self.txt_plain.get("1.0", "end-1c") else "") + seg.text)
                self.txt_times.insert("end", f"[{T.clock(seg.start)}] {seg.text}\n")
                self.txt_plain.see("end")
                self.txt_times.see("end")
        elif kind == "done":
            _, path, r, saved = m
            self.results[path] = r
            self._mark(path, "✓")
            speed = r.duration / r.seconds_taken if r.seconds_taken else 0
            msg = (f"Done: {T.clock(r.duration)} of audio in {T.clock(r.seconds_taken)} "
                   f"({speed:.1f}× real time, {'GPU' if r.device == 'cuda' else 'CPU'}).")
            if saved:
                msg += f" Saved {saved}."
            self.status.configure(text=self._prefix + msg)
            self.progress.configure(value=1000)
            self._update_model_note()
        elif kind == "cancelled":
            self._mark(m[1], "✗")
            self.status.configure(text="Cancelled. The partial text is shown but wasn't saved.")
        elif kind == "error":
            self._mark(m[1], "!")
            self.progress.configure(value=0)
            self.status.configure(text=self._prefix + "Failed.")
            messagebox.showerror("Couldn't transcribe", f"{Path(m[1]).name}\n\n{m[2]}")
        elif kind == "finished":
            self._set_busy(False)
        elif kind == "ai-text":
            self.txt_ai.insert("end", m[1])
            self.txt_ai.see("end")
        elif kind == "ai-status":
            self.status.configure(text=m[1])
        elif kind == "ai-done":
            _, path, kind2, text = m
            self._set_busy(False)
            self.txt_ai.delete("1.0", "end")
            self.txt_ai.insert("1.0", text)
            if kind2 == "summary":
                self.summaries[path] = text
                self.status.configure(text="Summary ready (AI tab). Check it against the transcript.")
            else:
                self.status.configure(text="Tidied text is in the AI tab. Copy it into the Transcript tab if you like it.")
        elif kind == "ai-error":
            self._set_busy(False)
            self.status.configure(text="Local AI failed.")
            messagebox.showerror("Local AI", m[1])

    _prefix = ""

    # ---------- output ----------
    def _active_text(self) -> str:
        tab = self.tabs.index(self.tabs.select())
        return (self.txt_plain, self.txt_times, self.txt_ai)[tab].get("1.0", "end-1c")

    def _copy(self):
        self.clipboard_clear()
        self.clipboard_append(self._active_text())
        self.status.configure(text="Copied to clipboard.")

    def _default_name(self, ext):
        return (Path(self.current).stem if self.current else "transcript") + ext

    def _save_txt(self):
        p = filedialog.asksaveasfilename(defaultextension=".txt", initialfile=self._default_name(".txt"),
                                         filetypes=[("Text", "*.txt")])
        if p:
            Path(p).write_text(self._active_text() + "\n", encoding="utf-8")
            self.status.configure(text=f"Saved {Path(p).name}")

    def _save_srt(self):
        r = self.results.get(self.current or "")
        if not r:
            messagebox.showinfo("Save .srt", "Transcribe the file first.")
            return
        p = filedialog.asksaveasfilename(defaultextension=".srt", initialfile=self._default_name(".srt"),
                                         filetypes=[("Subtitles", "*.srt")])
        if p:
            Path(p).write_text(T.to_srt(r.segments), encoding="utf-8")
            self.status.configure(text=f"Saved {Path(p).name}")

    # ---------- local AI ----------
    def _refresh_ai_models(self):
        def work():
            models = local_ai.list_models()
            self.after(0, lambda: self._set_ai_models(models))
        threading.Thread(target=work, daemon=True).start()

    def _set_ai_models(self, models):
        if models:
            self.ai_combo.configure(values=models)
            if self.ai_model.get() not in models:
                self.ai_model.set(models[0])

    def _ai(self, kind):
        if self.busy:
            return
        text = self.txt_plain.get("1.0", "end-1c").strip()
        if not text or not self.current:
            messagebox.showinfo("Local AI", "Transcribe a file first.")
            return
        self.cancel.clear()
        self._set_busy(True)
        self.txt_ai.delete("1.0", "end")
        self.tabs.select(2)
        path, model = self.current, self.ai_model.get().strip() or local_ai.DEFAULT_MODEL

        def work():
            try:
                out = local_ai.run(kind, text, model,
                                   on_text=lambda t: self.q.put(("ai-text", t)),
                                   on_status=lambda s: self.q.put(("ai-status", s)),
                                   cancel=self.cancel)
                self.q.put(("ai-done", path, kind, out))
            except Exception as e:
                msg = str(e)
                if "not found" in msg.lower():
                    msg += f"\n\nDownload it first in a terminal:\n  ollama pull {model}"
                self.q.put(("ai-error", msg))
        threading.Thread(target=work, daemon=True).start()


def selftest() -> int:
    """Checks the packaged app has everything it needs (used by the build): speech engine + silence detector."""
    import numpy as np
    import ctranslate2
    from faster_whisper.vad import VadOptions, get_speech_timestamps

    import av

    # write a short MP3 (stereo, 44.1 kHz) and read it back the same way real recordings are read
    sr = 44100
    t = np.arange(sr * 3) / sr
    tone = (0.5 * np.sin(2 * np.pi * 220 * t) * np.sin(2 * np.pi * 3 * t)).astype(np.float32)
    test = T.APP_DIR / "selftest.mp3"
    with av.open(str(test), "w") as out:
        st = out.add_stream("mp3", rate=sr, layout="stereo")
        frame = av.AudioFrame.from_ndarray(np.stack([tone, tone]), format="fltp", layout="stereo")
        frame.sample_rate = sr
        for pkt in st.encode(frame):
            out.mux(pkt)
        for pkt in st.encode(None):
            out.mux(pkt)
    audio = T.load_audio(str(test))
    test.unlink()
    if not 2.5 * 16000 < len(audio) < 3.5 * 16000:
        raise RuntimeError(f"decoded audio has wrong length: {len(audio)} samples")
    get_speech_timestamps(audio, VadOptions())
    msg = f"selftest ok: ctranslate2 {ctranslate2.__version__}, cuda devices {ctranslate2.get_cuda_device_count()}, models dir {T.MODELS_DIR}"
    (T.APP_DIR / "selftest.txt").write_text(msg + "\n", encoding="utf-8")
    print(msg)
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    App().mainloop()
