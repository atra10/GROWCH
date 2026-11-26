/* Runs Whisper speech recognition off the main thread. Everything after the first model download comes from the browser cache. */
import { pipeline, env, WhisperTextStreamer } from "https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.2/dist/transformers.min.js";

env.allowLocalModels = false; // models come from the Hugging Face hub once, then from the browser cache
env.useBrowserCache = true;

let asr = null;
let loadedKey = "";

async function hasWebGPU() {
  try { return !!(navigator.gpu && await navigator.gpu.requestAdapter()); } catch { return false; }
}

async function load(model, wantGpu) {
  const gpu = wantGpu && await hasWebGPU();
  const key = model + (gpu ? "|gpu" : "|cpu");
  if (asr && loadedKey === key) return { device: gpu ? "webgpu" : "wasm" };
  if (asr) { try { await asr.dispose(); } catch {} asr = null; }
  const progress_callback = p => postMessage({ type: "load-progress", data: p });
  const opts = gpu
    ? { device: "webgpu", dtype: { encoder_model: "fp32", decoder_model_merged: "q4" }, progress_callback }
    : { device: "wasm", dtype: "q8", progress_callback };
  try {
    asr = await pipeline("automatic-speech-recognition", model, opts);
  } catch (err) {
    if (!gpu) throw err;
    // WebGPU can fail on some drivers: fall back to the CPU engine
    postMessage({ type: "note", text: "Graphics acceleration failed, using the CPU instead." });
    asr = await pipeline("automatic-speech-recognition", model, { device: "wasm", dtype: "q8", progress_callback });
    loadedKey = model + "|cpu";
    return { device: "wasm" };
  }
  loadedKey = key;
  return { device: gpu ? "webgpu" : "wasm" };
}

self.onmessage = async ({ data: msg }) => {
  try {
    if (msg.type === "load") {
      const r = await load(msg.model, msg.gpu);
      postMessage({ type: "loaded", device: r.device });
      return;
    }
    if (msg.type === "run") {
      const r = await load(msg.model, msg.gpu);
      postMessage({ type: "loaded", device: r.device });
      const audio = msg.audio; // Float32Array, 16 kHz mono
      const SR = 16000, CHUNK = 30, STRIDE = 5;
      const win = CHUNK * SR, jump = (CHUNK - 2 * STRIDE) * SR;
      const total = audio.length <= win ? 1 : Math.ceil((audio.length - win) / jump) + 1;
      let done = 0;
      const streamer = new WhisperTextStreamer(asr.tokenizer, {
        skip_prompt: true,
        callback_function: text => postMessage({ type: "partial", text }),
        on_finalize: () => { done++; postMessage({ type: "progress", done, total }); },
      });
      const opts = {
        chunk_length_s: CHUNK,
        stride_length_s: STRIDE,
        return_timestamps: true,
        task: msg.task || "transcribe",
        streamer,
      };
      if (msg.language) opts.language = msg.language;
      const out = await asr(audio, opts);
      postMessage({ type: "result", text: out.text, chunks: out.chunks || [] });
    }
  } catch (err) {
    postMessage({ type: "error", text: String(err && err.message || err) });
  }
};
