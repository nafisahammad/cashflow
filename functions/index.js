const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

admin.initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.0-flash"];
const GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

exports.aiTransactionDecision = onRequest(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [geminiApiKey],
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      const authResult = await verifyAuthFromBearer(req);
      if (!authResult.ok) {
        res.status(401).json({ error: authResult.error });
        return;
      }

      const body = req.body && typeof req.body === "object" ? req.body : {};
      const text = safeString(body.text);
      if (!text) {
        res.status(400).json({ error: "Missing text" });
        return;
      }

      const context = normalizeContext(body.context);
      const history = normalizeHistory(body.history);
      const prompt = buildPrompt({ text, context, history });
      const rawModelText = await callGemini(prompt);
      const parsed = parseModelJson(rawModelText);
      const decision = normalizeDecision(parsed);

      res.status(200).json({ decision });
    } catch (error) {
      logger.error("aiTransactionDecision failed", error);
      res.status(500).json({
        error: "Failed to classify transaction intent.",
        details: safeErrorMessage(error),
      });
    }
  }
);

async function verifyAuthFromBearer(req) {
  try {
    const authHeader = req.get("Authorization") || req.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return { ok: false, error: "Missing bearer token" };
    }
    const token = authHeader.slice("Bearer ".length).trim();
    if (!token) {
      return { ok: false, error: "Empty bearer token" };
    }

    await admin.auth().verifyIdToken(token);
    return { ok: true };
  } catch (error) {
    logger.warn("Bearer verification failed", error);
    return { ok: false, error: "Invalid auth token" };
  }
}

function normalizeContext(context) {
  const ctx = context && typeof context === "object" ? context : {};
  const categories = ctx.categories && typeof ctx.categories === "object"
    ? ctx.categories
    : {};

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

function normalizeNamedList(list) {
  if (!Array.isArray(list)) {
    return [];
  }
  return list
    .filter((item) => item && typeof item === "object")
    .map((item) => ({
      id: safeString(item.id) || "",
      name: safeString(item.name) || "",
    }))
    .filter((item) => item.id || item.name);
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) {
    return [];
  }
  return history
    .filter((item) => item && typeof item === "object")
    .map((item) => ({
      role: safeString(item.role) || "user",
      text: safeString(item.text) || "",
    }))
    .filter((item) => item.text);
}

function buildPrompt({ text, context, history }) {
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
      dateIso: "ISO-8601 date/time string | null",
      note: "string | null",
    },
    tour: {
      amount: "number | null",
      tourId: "string | null",
      tourName: "string | null",
      contributorName: "string | null",
      sharerNames: ["string"],
      dateIso: "ISO-8601 date/time string | null",
      note: "string | null",
    },
  };

  return [
    "You are CashFlow's transaction intent router.",
    "Goal: classify one user utterance into MAIN personal transaction or TOUR transaction.",
    "If ambiguous, respond with mode=clarify and ask exactly one short question.",
    "Return only JSON. No markdown. No prose outside JSON.",
    "Use only entity names that are present in context lists.",
    "If user says a close misspelling, map it to the nearest available name.",
    "If amount/date missing, include them in missingFields and ask concise clarification.",
    "When entryPoint is tourDashboard and context.currentTourId is present, prefer that tour unless text clearly points to another tour.",
    "",
    "Output JSON schema:",
    JSON.stringify(schema),
    "",
    "Context JSON:",
    JSON.stringify(context),
    "",
    "Conversation history JSON:",
    JSON.stringify(history),
    "",
    "Latest user utterance:",
    text,
  ].join("\n");
}

async function callGemini(prompt) {
  const key = geminiApiKey.value();
  if (!key) {
    throw new Error("Missing GEMINI_API_KEY secret.");
  }

  let lastError = null;
  for (const model of GEMINI_MODELS) {
    const endpoint = `${GEMINI_API_BASE}/${model}:generateContent?key=${encodeURIComponent(key)}`;
    const payload = {
      contents: [
        {
          role: "user",
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        temperature: 0.2,
        topP: 0.9,
        responseMimeType: "application/json",
      },
    };

    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const bodyText = await response.text();
      lastError = new Error(
        `Gemini request failed for ${model} (${response.status}): ${bodyText}`
      );
      continue;
    }

    const data = await response.json();
    const text = extractTextFromGeminiResponse(data);
    if (!text) {
      lastError = new Error(`Gemini returned empty content for ${model}.`);
      continue;
    }
    return text;
  }

  throw lastError || new Error("Gemini request failed for all configured models.");
}

function extractTextFromGeminiResponse(data) {
  const candidates = Array.isArray(data?.candidates) ? data.candidates : [];
  for (const candidate of candidates) {
    const parts = Array.isArray(candidate?.content?.parts)
      ? candidate.content.parts
      : [];
    const joined = parts.map((part) => safeString(part?.text) || "").join("\n").trim();
    if (joined) {
      return joined;
    }
  }
  return "";
}

function parseModelJson(rawText) {
  const trimmed = rawText.trim();
  const deFenced = trimmed
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  const direct = tryParseJson(deFenced);
  if (direct) {
    return direct;
  }

  const start = deFenced.indexOf("{");
  const end = deFenced.lastIndexOf("}");
  if (start >= 0 && end > start) {
    const sliced = deFenced.slice(start, end + 1);
    const recovered = tryParseJson(sliced);
    if (recovered) {
      return recovered;
    }
  }

  throw new Error(`Model output was not valid JSON: ${rawText}`);
}

function tryParseJson(input) {
  try {
    const parsed = JSON.parse(input);
    if (parsed && typeof parsed === "object") {
      return parsed;
    }
    return null;
  } catch {
    return null;
  }
}

function normalizeDecision(parsed) {
  const modeRaw = safeString(parsed.mode)?.toLowerCase() || "clarify";
  const mode = modeRaw === "main" || modeRaw === "tour" ? modeRaw : "clarify";

  const missingFields = Array.isArray(parsed.missingFields)
    ? parsed.missingFields.map((x) => safeString(x)).filter(Boolean)
    : [];

  const main = parsed.main && typeof parsed.main === "object" ? parsed.main : {};
  const tour = parsed.tour && typeof parsed.tour === "object" ? parsed.tour : {};

  return {
    mode,
    confidence: clampNumber(toNumber(parsed.confidence) ?? 0, 0, 1),
    missingFields,
    clarificationQuestion: safeString(parsed.clarificationQuestion) || null,
    assistantMessage: safeString(parsed.assistantMessage) || null,
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

function normalizeTxType(value) {
  const raw = safeString(value)?.toLowerCase();
  if (raw === "income" || raw === "expense") {
    return raw;
  }
  return null;
}

function toNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const num = Number(value.trim());
    return Number.isFinite(num) ? num : null;
  }
  return null;
}

function positiveNumberOrNull(value) {
  if (typeof value !== "number") {
    return null;
  }
  return value > 0 ? value : null;
}

function clampNumber(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function safeString(value) {
  if (typeof value !== "string") {
    return null;
  }
  const s = value.trim();
  return s.length ? s : null;
}

function safeErrorMessage(error) {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}
