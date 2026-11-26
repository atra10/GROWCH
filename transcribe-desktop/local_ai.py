"""Optional: summarize or tidy a transcript with a local AI model through Ollama (https://ollama.com).
Everything stays on this computer: Ollama listens on localhost only."""
from __future__ import annotations

import json
import re
import urllib.request
from typing import Callable, Optional
import threading

OLLAMA = "http://127.0.0.1:11434"
DEFAULT_MODEL = "qwen3:8b"
CHUNK_CHARS = 12000  # long transcripts are summarized in parts, then combined

PROMPTS = {
    "summary": (
        "Below is a transcript of a call or recording. It may mix Indonesian, Javanese, Sundanese and English. "
        "Write a clear summary in Indonesian with these sections:\n"
        "**Ringkasan** (2-4 kalimat)\n**Poin penting** (bullet)\n**Keputusan**\n**Tindak lanjut** (siapa, apa, kapan, kalau disebut)\n"
        "Leave a section out if nothing fits. Don't invent anything that isn't in the transcript.\n\nTranscript:\n"
    ),
    "combine": (
        "These are summaries of consecutive parts of one long call. Merge them into one summary in Indonesian with "
        "the sections **Ringkasan**, **Poin penting**, **Keputusan**, **Tindak lanjut**. Remove repeats. "
        "Don't invent anything.\n\nPart summaries:\n"
    ),
    "tidy": (
        "Fix punctuation, capitalisation and paragraph breaks in this transcript. Keep every word in the language "
        "it was spoken in (Indonesian, Javanese, Sundanese or English): do NOT translate, summarize or remove content. "
        "Only fix obvious speech-recognition typos. Return only the corrected text.\n\nTranscript:\n"
    ),
}


def list_models() -> Optional[list[str]]:
    """Installed Ollama models, or None when Ollama isn't running."""
    try:
        with urllib.request.urlopen(OLLAMA + "/api/tags", timeout=2) as r:
            return [m["name"] for m in json.load(r).get("models", [])]
    except Exception:
        return None


def _strip_think(text: str) -> str:
    return re.sub(r"<think>.*?</think>\s*", "", text, flags=re.S)


def _generate(model: str, prompt: str, on_text: Callable[[str], None], cancel: Optional[threading.Event]) -> str:
    body = json.dumps({
        "model": model, "prompt": prompt, "stream": True, "think": False,
        "options": {"num_ctx": 16384, "temperature": 0.3},
    }).encode()
    req = urllib.request.Request(OLLAMA + "/api/generate", body, {"Content-Type": "application/json"})
    out, in_think = [], False
    with urllib.request.urlopen(req, timeout=600) as r:
        for line in r:
            if cancel is not None and cancel.is_set():
                break
            msg = json.loads(line)
            if msg.get("error"):
                raise RuntimeError(msg["error"])
            piece = msg.get("response", "")
            # hide a model's "thinking" if it still sends it
            if "<think>" in piece:
                in_think = True
            if not in_think and piece:
                out.append(piece)
                on_text(piece)
            if "</think>" in piece:
                in_think = False
            if msg.get("done"):
                break
    return _strip_think("".join(out)).strip()


def _split(text: str, size: int) -> list[str]:
    parts, cur = [], ""
    for line in text.splitlines(keepends=True):
        if len(cur) + len(line) > size and cur:
            parts.append(cur)
            cur = ""
        cur += line
    if cur:
        parts.append(cur)
    return parts


def run(kind: str, transcript: str, model: str = DEFAULT_MODEL,
        on_text: Callable[[str], None] = lambda t: None,
        on_status: Callable[[str], None] = lambda s: None,
        cancel: Optional[threading.Event] = None) -> str:
    """kind: 'summary' or 'tidy'. Streams text through on_text and returns the full result."""
    if list_models() is None:
        raise RuntimeError("Ollama isn't running. Install it from ollama.com, open it, then run:\n"
                           f"  ollama pull {DEFAULT_MODEL}")
    parts = _split(transcript, CHUNK_CHARS)
    if kind == "tidy":
        results = []
        for i, p in enumerate(parts, 1):
            on_status(f"Tidying part {i} of {len(parts)}…")
            results.append(_generate(model, PROMPTS["tidy"] + p, on_text, cancel))
            on_text("\n\n")
        return "\n\n".join(results)
    if len(parts) == 1:
        on_status("Summarizing…")
        return _generate(model, PROMPTS["summary"] + transcript, on_text, cancel)
    notes = []
    for i, p in enumerate(parts, 1):
        on_status(f"Reading part {i} of {len(parts)}…")
        notes.append(_generate(model, PROMPTS["summary"] + p, lambda t: None, cancel))
        if cancel is not None and cancel.is_set():
            return ""
    on_status("Combining into one summary…")
    return _generate(model, PROMPTS["combine"] + "\n\n---\n\n".join(notes), on_text, cancel)
