"""Offline speech-to-text core (faster-whisper). Used by the desktop app, also runnable from the command line:

    python transcriber.py recording.mp3 --lang mixed --model large-v3-turbo
"""
from __future__ import annotations

import os
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional

# next to Transcribe.exe when packaged, otherwise next to this file
APP_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
MODELS_DIR = APP_DIR / "models"

# name shown in the app -> (faster-whisper model id, approx. download size in bytes, note)
MODELS = {
    "large-v3-turbo": ("large-v3-turbo", 1_620_000_000, "Recommended · 1.6 GB"),
    "large-v3": ("large-v3", 3_090_000_000, "Most accurate, slower · 3.1 GB"),
    "medium": ("medium", 1_530_000_000, "Older · 1.5 GB"),
    "small": ("small", 484_000_000, "Fastest, less accurate · 0.5 GB"),
}

# name shown in the app -> (whisper language code or None, detect language per segment?)
LANGUAGES = {
    "Mixed (Indonesian / Javanese / Sundanese / English)": (None, True),
    "Indonesian": ("id", False),
    "Javanese": ("jw", False),
    "Sundanese": ("su", False),
    "English": ("en", False),
    "Auto-detect (one language)": (None, False),
}
LANG_NAMES = {"id": "Indonesian", "jw": "Javanese", "su": "Sundanese", "en": "English", "ms": "Malay"}

# A short code-mixed example nudges Whisper to write each word in the language it was spoken in,
# instead of translating everything into one language.
MIXED_PROMPT = (
    "Halo, iya, jadi meeting-nya kita mundurin ya. Nggih, mboten napa-napa. "
    "Punten, abdi teu acan terang. Okay, let's continue."
)


@dataclass
class Segment:
    start: float
    end: float
    text: str


@dataclass
class Result:
    segments: list[Segment] = field(default_factory=list)
    language: str = ""
    duration: float = 0.0
    device: str = ""
    seconds_taken: float = 0.0

    @property
    def text(self) -> str:
        return " ".join(s.text for s in self.segments).strip()


def _add_nvidia_dlls() -> None:
    """On Windows, make pip-installed CUDA libraries (nvidia-cublas-cu12, nvidia-cudnn-cu12) findable."""
    if os.name != "nt":
        return
    try:
        import nvidia  # type: ignore
    except ImportError:
        return
    for base in getattr(nvidia, "__path__", []):
        for sub in Path(base).glob("*/bin"):
            try:
                os.add_dll_directory(str(sub))
            except OSError:
                pass
            os.environ["PATH"] = str(sub) + os.pathsep + os.environ.get("PATH", "")


def _folder_size(path: Path) -> int:
    total = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return total


def is_downloaded(model_name: str) -> bool:
    from faster_whisper.utils import download_model

    try:
        download_model(MODELS[model_name][0], local_files_only=True, cache_dir=str(MODELS_DIR))
        return True
    except Exception:
        return False


def load_audio(path: str, sr: int = 16000):
    """Decode any audio/video file to 16 kHz mono float32 with PyAV.
    (faster-whisper's own reader passes an option that newer PyAV versions removed.)"""
    import av
    import numpy as np

    try:
        container = av.open(str(path))
    except Exception as e:
        raise RuntimeError(f"This file couldn't be opened as audio. Try MP3, M4A or WAV.\n\nDetails: {e}") from e
    with container:
        if not container.streams.audio:
            raise RuntimeError("This file has no audio track.")
        stream = container.streams.audio[0]
        resampler = av.AudioResampler(format="s16", layout="mono", rate=sr)
        chunks = []
        frames = container.decode(stream)
        while True:
            try:
                frame = next(frames)
            except StopIteration:
                break
            except av.error.InvalidDataError:  # skip a damaged bit instead of failing the whole file
                continue
            for f in resampler.resample(frame):
                chunks.append(f.to_ndarray().reshape(-1))
        for f in resampler.resample(None):
            chunks.append(f.to_ndarray().reshape(-1))
    if not chunks:
        raise RuntimeError("No sound could be read from this file.")
    return np.concatenate(chunks).astype(np.float32) / 32768.0


_cache: dict[tuple, object] = {}


def load_model(model_name: str, use_gpu: bool = True,
               on_status: Callable[[str], None] = lambda s: None,
               on_download: Callable[[float], None] = lambda f: None):
    """Load a model, downloading it once if needed. Tries the NVIDIA GPU first, then the CPU."""
    model_id, size, _ = MODELS[model_name]
    MODELS_DIR.mkdir(exist_ok=True)

    if not is_downloaded(model_name):
        from faster_whisper.utils import download_model

        on_status(f"Downloading the {model_name} model (about {size / 1e9:.1f} GB, first time only)…")
        before = _folder_size(MODELS_DIR)
        stop = threading.Event()

        def watch():  # report download progress by watching the folder grow
            while not stop.wait(0.5):
                on_download(min(0.99, (_folder_size(MODELS_DIR) - before) / size))

        t = threading.Thread(target=watch, daemon=True)
        t.start()
        try:
            download_model(model_id, cache_dir=str(MODELS_DIR))
        except Exception as e:
            raise RuntimeError(
                "Couldn't download the speech model. Connect to the internet for the first run "
                f"(after that, no internet is needed).\n\nDetails: {e}"
            ) from e
        finally:
            stop.set()
        on_download(1.0)

    from faster_whisper import WhisperModel

    attempts = []
    if use_gpu:
        attempts.append(("cuda", "float16"))
    attempts.append(("cpu", "int8"))
    last_err = None
    for device, compute in attempts:
        key = (model_name, device)
        if key in _cache:
            return _cache[key], device
        on_status(f"Loading the {model_name} model on the {'GPU' if device == 'cuda' else 'CPU'}…")
        try:
            if device == "cuda":
                _add_nvidia_dlls()
            m = WhisperModel(model_id, device=device, compute_type=compute,
                             download_root=str(MODELS_DIR), local_files_only=True)
            _cache.clear()  # keep only one model in memory
            _cache[key] = m
            return m, device
        except Exception as e:  # no NVIDIA GPU / CUDA libraries: fall back to CPU
            last_err = e
    raise RuntimeError(f"Couldn't load the model: {last_err}")


def transcribe(path: str, model_name: str = "large-v3-turbo", language: str = next(iter(LANGUAGES)),
               use_gpu: bool = True, hotwords: str = "",
               on_status: Callable[[str], None] = lambda s: None,
               on_download: Callable[[float], None] = lambda f: None,
               on_segment: Callable[[Segment, float], None] = lambda s, frac: None,
               cancel: Optional[threading.Event] = None) -> Result:
    """Transcribe one audio/video file. on_segment gets each piece of text plus overall progress 0..1."""
    t0 = time.time()
    model, device = load_model(model_name, use_gpu, on_status, on_download)
    code, per_segment = LANGUAGES[language]

    on_status("Reading audio…")
    opts = dict(
        language=code,
        multilingual=per_segment,
        task="transcribe",
        beam_size=5,
        vad_filter=True,  # skip silence: faster, and avoids made-up text during pauses
        vad_parameters=dict(min_silence_duration_ms=700),
        condition_on_previous_text=False,  # prevents repeating-text loops on long recordings
        initial_prompt=MIXED_PROMPT if per_segment or code is None else None,
        hotwords=hotwords.strip() or None,
    )
    audio = load_audio(path)
    segments, info = model.transcribe(audio, **opts)
    res = Result(language=info.language, duration=info.duration, device=device)
    lang = "mixed, detected per segment" if per_segment else LANG_NAMES.get(info.language, info.language)
    on_status(f"Transcribing ({lang})…")
    for s in segments:
        if cancel is not None and cancel.is_set():
            break
        seg = Segment(s.start, s.end, s.text.strip())
        if not seg.text:
            continue
        res.segments.append(seg)
        on_segment(seg, min(1.0, s.end / info.duration) if info.duration else 0.0)
    res.seconds_taken = time.time() - t0
    return res


# ---------- output formats ----------

def clock(s: float) -> str:
    s = int(s)
    h, m, sec = s // 3600, s % 3600 // 60, s % 60
    return f"{h}:{m:02d}:{sec:02d}" if h else f"{m}:{sec:02d}"


def srt_time(s: float) -> str:
    ms = int(round(s * 1000))
    return f"{ms // 3600000:02d}:{ms % 3600000 // 60000:02d}:{ms % 60000 // 1000:02d},{ms % 1000:03d}"


def to_srt(segments: list[Segment]) -> str:
    return "\n".join(f"{i}\n{srt_time(s.start)} --> {srt_time(s.end)}\n{s.text}\n"
                     for i, s in enumerate(segments, 1))


def to_timestamped(segments: list[Segment]) -> str:
    return "\n".join(f"[{clock(s.start)}] {s.text}" for s in segments)


def main(argv=None) -> int:
    import argparse

    lang_keys = {"mixed": next(iter(LANGUAGES)), "id": "Indonesian", "jw": "Javanese", "su": "Sundanese",
                 "en": "English", "auto": "Auto-detect (one language)"}
    p = argparse.ArgumentParser(description="Offline audio-to-text with Whisper.")
    p.add_argument("files", nargs="+")
    p.add_argument("--model", default="large-v3-turbo", choices=list(MODELS))
    p.add_argument("--lang", default="mixed", choices=list(lang_keys))
    p.add_argument("--cpu", action="store_true", help="don't try the NVIDIA GPU")
    p.add_argument("--hotwords", default="", help="names/terms that appear in the audio")
    a = p.parse_args(argv)
    for f in a.files:
        print(f"== {f}", file=sys.stderr)
        r = transcribe(f, a.model, lang_keys[a.lang], not a.cpu, a.hotwords,
                       on_status=lambda s: print(s, file=sys.stderr),
                       on_segment=lambda s, _: print(f"[{clock(s.start)}] {s.text}", file=sys.stderr))
        base = Path(f).with_suffix("")
        Path(f"{base}.txt").write_text(r.text + "\n", encoding="utf-8")
        Path(f"{base}.srt").write_text(to_srt(r.segments), encoding="utf-8")
        print(f"Saved {base}.txt and {base}.srt ({clock(r.seconds_taken)} on {r.device})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
