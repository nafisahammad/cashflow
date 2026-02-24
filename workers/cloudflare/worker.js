export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (!env.GEMINI_API_KEY) {
      return json({ error: "Missing GEMINI_API_KEY secret" }, 500);
    }

    let body = {};
    try {
      body = await request.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const text = safeString(body.text);
    if (!text) {
      return json({ error: "Missing text" }, 400);
    }

    const context = normalizeContext(body.context);
    const history = normalizeHistory(body.history);
    const prompt = buildPrompt(text, context, history);

    try {
      const modelText = await callGemini(env.GEMINI_API_KEY, prompt);
      const parsed = parseModelJson(modelText);
      const decision = normalizeDecision(parsed);
      return json({ decision }, 200);
    } catch (error) {
      return json(
        {
          error: "Gemini proxy failed",
          details: error instanceof Error ? error.message : String(error),
        },
        500,
      );
    }
  },
};

const MODEL_CHAIN = ["gemini-2.5-flash", "gemini-2.0-flash"];

async function callGemini(apiKey, prompt) {
  let lastErr = null;
  for (const model of MODEL_CHAIN) {
    try {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            topP: 0.9,
            responseMimeType: "application/json",
          },
        }),
      });
      if (!response.ok) {
        lastErr = new Error(`Gemini ${model} failed (${response.status}): ${await response.text()}`);
        continue;
      }
      const data = await response.json();
      const text = extractGeminiText(data);
      if (!text) {
        lastErr = new Error(`Gemini ${model} returned empty text`);
        continue;
      }
      return text;
    } catch (error) {
      lastErr = error;
    }
  }
  throw lastErr || new Error("All Gemini models failed");
}

function buildPrompt(text, context, history) {
  const schema = {
    mode: "main | tour | clarify",
    confidence: "number 0..1",
    missingFields: ["string"],
    clarificationQuestion: "string | null",
    assistantMessage: "string | null",
    main: {
      amount: "number | null",
      type: "income | expense | null",
      accountName: "string | null",
      categoryName: "string | null",
      dateIso: "ISO-8601 string | null",
      note: "string | null",
    },
    tour: {
      amount: "number | null",
      tourId: "string | null",
      tourName: "string | null",
      contributorName: "string | null",
      sharerNames: ["string"],
      dateIso: "ISO-8601 string | null",
      note: "string | null",
    },
  };

  return [
    "You are CashFlow transaction intent router.",
    "Classify into main, tour, or clarify.",
    "If unclear, ask one short clarification question.",
    "Return only JSON, no markdown.",
    "Use only names from context when possible.",
    "",
    "Schema:",
    JSON.stringify(schema),
    "",
    "Context:",
    JSON.stringify(context),
    "",
    "History:",
    JSON.stringify(history),
    "",
    "User text:",
    text,
  ].join("\n");
}

function normalizeContext(context) {
  const ctx = context && typeof context === "object" ? context : {};
  const categories = ctx.categories && typeof ctx.categories === "object" ? ctx.categories : {};
  return {
    entryPoint: safeString(ctx.entryPoint) || "mainDashboard",
    currentTourId: safeString(ctx.currentTourId) || null,
    accounts: normalizeNamedList(ctx.accounts),
    categories: {
      expense: normalizeNamedList(categories.expense),
      income: normalizeNamedList(categories.income),
    },
    tours: normalizeNamedList(ctx.tours),
  };
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) return [];
  return history
    .filter((item) => item && typeof item === "object")
    .map((item) => ({
      role: safeString(item.role) || "user",
      text: safeString(item.text) || "",
    }))
    .filter((item) => item.text);
}

function normalizeNamedList(items) {
  if (!Array.isArray(items)) return [];
  return items
    .filter((item) => item && typeof item === "object")
    .map((item) => ({
      id: safeString(item.id) || "",
      name: safeString(item.name) || "",
    }))
    .filter((item) => item.id || item.name);
}

function extractGeminiText(data) {
  const candidates = Array.isArray(data?.candidates) ? data.candidates : [];
  for (const candidate of candidates) {
    const parts = Array.isArray(candidate?.content?.parts) ? candidate.content.parts : [];
    const text = parts.map((part) => safeString(part?.text) || "").join("\n").trim();
    if (text) return text;
  }
  return "";
}

function parseModelJson(rawText) {
  const trimmed = rawText.trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  try {
    return JSON.parse(trimmed);
  } catch {}

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end > start) {
    return JSON.parse(trimmed.slice(start, end + 1));
  }
  throw new Error("Model output is not valid JSON");
}

function normalizeDecision(parsed) {
  const modeRaw = safeString(parsed?.mode)?.toLowerCase() || "clarify";
  const mode = modeRaw === "main" || modeRaw === "tour" ? modeRaw : "clarify";
  const missingFields = Array.isArray(parsed?.missingFields)
    ? parsed.missingFields.map((x) => safeString(x)).filter(Boolean)
    : [];
  const main = parsed?.main && typeof parsed.main === "object" ? parsed.main : {};
  const tour = parsed?.tour && typeof parsed.tour === "object" ? parsed.tour : {};

  return {
    mode,
    confidence: clamp(toNumber(parsed?.confidence) ?? 0, 0, 1),
    missingFields,
    clarificationQuestion: safeString(parsed?.clarificationQuestion) || null,
    assistantMessage: safeString(parsed?.assistantMessage) || null,
    main: {
      amount: positiveNumberOrNull(toNumber(main.amount)),
      type: normalizeTxType(main.type),
      accountName: safeString(main.accountName) || null,
      categoryName: safeString(main.categoryName) || null,
      dateIso: safeString(main.dateIso) || null,
      note: safeString(main.note) || null,
    },
    tour: {
      amount: positiveNumberOrNull(toNumber(tour.amount)),
      tourId: safeString(tour.tourId) || null,
      tourName: safeString(tour.tourName) || null,
      contributorName: safeString(tour.contributorName) || null,
      sharerNames: Array.isArray(tour.sharerNames)
        ? tour.sharerNames.map((x) => safeString(x)).filter(Boolean)
        : [],
      dateIso: safeString(tour.dateIso) || null,
      note: safeString(tour.note) || null,
    },
  };
}

function normalizeTxType(v) {
  const raw = safeString(v)?.toLowerCase();
  return raw === "income" || raw === "expense" ? raw : null;
}

function toNumber(v) {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const n = Number(v.trim());
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function positiveNumberOrNull(v) {
  return typeof v === "number" && v > 0 ? v : null;
}

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

function safeString(v) {
  if (typeof v !== "string") return null;
  const s = v.trim();
  return s.length ? s : null;
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json",
    },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}
