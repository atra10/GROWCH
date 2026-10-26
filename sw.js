/* Growch service worker: works offline, always prefers fresh pages when online. */
const VER = "growch-20261026142037";
const CORE = ["/", "/index.html", "/manifest.webmanifest", "/icons/icon-192.png", "/icons/icon-512.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VER).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VER).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname.endsWith("supabase.co")) return; // account data: always live, never cached
  // pages: network first, fall back to the saved copy when offline
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(VER).then(x => x.put("/index.html", c)); return r; })
      .catch(() => caches.match("/index.html")));
    return;
  }
  // everything else (PDFs, icons, fonts, chart library): saved copy first, then network
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
    if (r && (r.ok || r.type === "opaque")) { const c = r.clone(); caches.open(VER).then(x => x.put(req, c)); }
    return r;
  })));
});
