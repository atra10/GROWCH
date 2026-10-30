// Growch "Tanya AI" endpoint (Vercel serverless function).
// Needs two Environment Variables in Vercel → Project → Settings → Environment Variables:
//   ANTHROPIC_API_KEY  — your key from console.anthropic.com (keep it secret; never put it in the page)
//   AI_ACCESS_CODE     — any password you choose; the site asks for it once so strangers can't spend your credit
// Optional: AI_MODEL (default "claude-haiku-5-5"; e.g. "claude-sonnet-5-5" for deeper answers, higher cost)

const MAX_CHARS = 60000;

module.exports = async function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  const key = process.env.ANTHROPIC_API_KEY;
  const code = process.env.AI_ACCESS_CODE;

  if (req.method === "GET") {
    // availability check used by the page: no secrets returned
    return res.status(200).json({ ok: Boolean(key && code) });
  }
  if (req.method !== "POST") return res.status(405).json({ error: "method" });
  if (!key || !code) return res.status(503).json({ error: "not_configured" });
  if ((req.headers["x-ai-code"] || "") !== code) return res.status(401).json({ error: "code" });

  let body = req.body;
  if (typeof body === "string") { try { body = JSON.parse(body); } catch (e) { body = null; } }
  const msgs = body && Array.isArray(body.messages) ? body.messages : null;
  if (!msgs || !msgs.length) return res.status(400).json({ error: "bad_request" });

  // keep only valid turns, trim the oldest chat turns (never the first instruction turn) to the size cap
  let clean = msgs
    .filter(m => m && (m.role === "user" || m.role === "assistant") && typeof m.content === "string" && m.content.trim())
    .map(m => ({ role: m.role, content: m.content.slice(0, 30000) }));
  const size = a => a.reduce((n, m) => n + m.content.length, 0);
  while (clean.length > 3 && size(clean) > MAX_CHARS) clean.splice(2, 1);
  if (!clean.length || clean[0].role !== "user" || clean[clean.length - 1].role !== "user")
    return res.status(400).json({ error: "bad_request" });

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model: process.env.AI_MODEL || "claude-haiku-5-5", max_tokens: 1500, messages: clean }),
    });
    const j = await r.json().catch(() => ({}));
    if (r.status === 429) return res.status(429).json({ error: "rate_limited" });
    if (!r.ok) return res.status(502).json({ error: (j.error && j.error.type) || "upstream" });
    const text = (j.content || []).filter(c => c.type === "text").map(c => c.text).join("");
    return res.status(200).json({ text, truncated: j.stop_reason === "max_tokens" });
  } catch (e) {
    return res.status(502).json({ error: "upstream" });
  }
};
