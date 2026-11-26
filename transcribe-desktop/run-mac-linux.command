#!/bin/bash
# Double-click (Mac) or run ./run-mac-linux.command (Linux) to start Transcribe.
# The first run sets everything up (needs internet, takes a few minutes).
cd "$(dirname "$0")" || exit 1
if [ ! -x .venv/bin/python ]; then
  echo "First run: setting up Transcribe. This needs internet and takes a few minutes..."
  PY=""
  for c in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c "import tkinter" >/dev/null 2>&1; then PY="$c"; break; fi
  done
  if [ -z "$PY" ]; then
    echo "Python with Tk wasn't found. Install Python 3.12 from https://www.python.org/downloads/"
    echo "(Linux: sudo apt install python3-venv python3-tk) and run this again."
    read -r -p "Press Enter to close."; exit 1
  fi
  "$PY" -m venv .venv && .venv/bin/python -m pip install --upgrade pip && .venv/bin/python -m pip install -r requirements.txt || {
    echo "Installing failed. Check your internet connection and run this again."; rm -rf .venv
    read -r -p "Press Enter to close."; exit 1
  }
fi
exec .venv/bin/python app.py
