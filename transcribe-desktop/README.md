# Transcribe (desktop, offline)

Turn recordings and calls into text **on your own laptop**. Supports Indonesian, Javanese, Sundanese, English, and calls that mix them. No internet needed after the first setup, and nothing is uploaded.

It uses **Whisper large-v3-turbo** (open source, MIT licence) through [faster-whisper](https://github.com/SYSTRAN/faster-whisper). You don't need DeepSeek, Qwen or any other chat AI to transcribe. One can *optionally* write summaries for you (see below).

## Setup (once, needs internet)

1. Install **Python 3.12** from <https://www.python.org/downloads/>.
   On Windows, tick **"Add python.exe to PATH"** in the installer.
2. Download this folder. On GitHub use **Code → Download ZIP**, then unzip it.
3. Start the app:
   - **Windows:** double-click `run-windows.bat`
   - **Mac:** right-click `run-mac-linux.command` → **Open** (the first time only, so macOS allows it)
   - **Linux:** `./run-mac-linux.command`

   The first start installs what the app needs (~300 MB, a few minutes).
4. Transcribe any short file once. This downloads the speech model (large-v3-turbo is **1.6 GB**) into the `models` folder.

After that, everything works with **Wi-Fi off**.

## Using it

1. **Add files…** You can pick several at once (mp3, m4a, wav, ogg, opus, flac, mp4, WhatsApp voice notes, …).
2. **Language:**
   - Keep **Mixed** for calls that switch between languages. It detects the language again every few seconds.
   - If a whole recording is in one language, choose that language. That's more accurate, especially for Javanese or Sundanese.
3. **Names / terms (optional):** type names or jargon that come up, e.g. `Pak Budi, Cirebon, invoice`. This helps them get spelled right.
4. Press **Transcribe**. The text appears as it goes. When it finishes, `name.txt` and `name.srt` are saved next to each audio file.

The **Transcript** tab can be edited before you copy or save it.

## How long, how big?

There's no real file-size limit. A 2–3 hour call is fine on a laptop with 8 GB of RAM.

Rough speed for 1 hour of audio with large-v3-turbo:

| Laptop | Time |
|---|---|
| NVIDIA graphics card | ~2–5 min |
| Apple M1–M4 (CPU) | ~10–20 min |
| Recent Intel / AMD (CPU) | ~15–40 min |

If it's too slow, choose the `small` model: about 3× faster, but less accurate.

### Using an NVIDIA graphics card (Windows, optional)

Run this once in the app folder:

```
.venv\Scripts\python -m pip install nvidia-cublas-cu12 "nvidia-cudnn-cu12==9.*"
```

The app uses the card automatically. If the card doesn't work, the app quietly falls back to the CPU.

## Accuracy, honestly

- **Indonesian and English:** very good.
- **Javanese and Sundanese:** usable, but clearly weaker. Whisper saw much less training data for them. In Mixed mode it sometimes writes Javanese or Sundanese speech in Indonesian spelling.
- **Biggest accuracy boosts:** choosing `large-v3`, picking the language when it's not mixed, and adding names in *Names / terms*.
- **Phone recordings:** if the far side is quiet or cut off, accuracy drops. Record both sides clearly if you can.
- **Who said what:** the app doesn't label speakers.

## Optional: summaries with a local AI (Qwen via Ollama)

The **Summarize** and **Tidy text** buttons use a chat AI that also runs on your laptop:

1. Install **Ollama** from <https://ollama.com> and open it.
2. In a terminal, download a model:
   - `ollama pull qwen3:8b`: good Indonesian, needs ~16 GB RAM
   - `ollama pull qwen3:4b`: for 8 GB RAM laptops
3. Restart the app and pick the model next to **Local AI**.

What the buttons do:
- **Summarize:** writes *Ringkasan / Poin penting / Keputusan / Tindak lanjut*.
- **Tidy text:** fixes punctuation without translating.

Both run offline too. Always check the output against the transcript, because AI can get things wrong.

## Command line

```
.venv/bin/python transcriber.py call.m4a --lang mixed --model large-v3-turbo --hotwords "Pak Budi"
```

`--lang` can be: `mixed`, `id`, `jw`, `su`, `en`, `auto`.
