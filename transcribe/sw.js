/* Offline support for the Transcribe app. The speech models themselves are cached by the library (Cache "transformers-cache"). */
const VER = "transcribe-v1";
const LIB = "https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.2/dist/transformers.min.js";
const CORE = ["./", "./index.html", "./worker.js", "./manifest.webmanifest", "/icons/icon-192.png", "/icons/icon-512.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VER).then(async c => {
    await c.addAll(CORE);
    try { await c.add(new Request(LIB, { mode: "cors" })); } catch {} // offline install: cached later on first use
  }).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith("transcribe-") && k !== VER).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const same = url.origin === location.origin;
  if (!same && url.hostname !== "cdn.jsdelivr.net") return; // model downloads are cached by the library itself
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(VER).then(x => x.put("./index.html", c)); return r; })
      .catch(() => caches.match("./index.html")));
    return;
  }
  if (same) { // app files: fresh when online, saved copy when offline
    e.respondWith(fetch(req).then(r => { if (r.ok) { const c = r.clone(); caches.open(VER).then(x => x.put(req, c)); } return r; })
      .catch(() => caches.match(req)));
    return;
  }
  // pinned library version never changes: saved copy first
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
    if (r.ok) { const c = r.clone(); caches.open(VER).then(x => x.put(req, c)); }
    return r;
  })));
});
