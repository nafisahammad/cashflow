# cashflow

A personal finance tracker built with Flutter.

## Firebase Secrets Setup

This project expects Firebase keys/IDs from a local secrets file (not committed).

1. Create `secrets/firebase.secrets.json`.

2. Fill values in `secrets/firebase.secrets.json`.

3. Run app:

```powershell
flutter run
```

## Notes

- `secrets/firebase.secrets.json` is gitignored.
- Firebase options are loaded from `secrets/firebase.secrets.json` by `lib/firebase_options.dart`.

## AI Assistant (Gemini Backend)

The AI mic flow supports:

- Remote AI endpoint (preferred): Cloudflare Worker or Firebase Function.
- Offline parser fallback (always available).

### Option A: Cloudflare Worker (no Firebase Blaze required)

Files:
- [workers/cloudflare/worker.js](/e:/one%20drive/OneDrive/Documents/GitHub/CashFlow/cashflow/workers/cloudflare/worker.js)
- [workers/cloudflare/wrangler.toml](/e:/one%20drive/OneDrive/Documents/GitHub/CashFlow/cashflow/workers/cloudflare/wrangler.toml)

Deploy:

```powershell
cd workers/cloudflare
npm create cloudflare@latest . -- --type=hello-world --lang=js
npx wrangler secret put GEMINI_API_KEY
npx wrangler deploy
```

Then set endpoint locally in `secrets/firebase.secrets.json`:

```json
"AI_ASSISTANT_ENDPOINT": "https://<your-worker-subdomain>.workers.dev"
```

Run app:

```powershell
flutter run
```

### 1) Install and deploy functions

```powershell
cd functions
npm install
cd ..
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

### 2) Run Flutter app (endpoint auto-detected)

The app now auto-builds the endpoint from Firebase project ID:

- `https://us-central1-<project-id>.cloudfunctions.net/aiTransactionDecision`

So this works with no extra flag:

```powershell
flutter run
```

Optional override (if you want custom endpoint/environment):

```powershell
flutter run --dart-define=CASHFLOW_AI_ENDPOINT=https://us-central1-<your-project-id>.cloudfunctions.net/aiTransactionDecision
```

If `CASHFLOW_AI_ENDPOINT` is not provided, the app uses a simple fallback classifier instead of Gemini.
The function validates Firebase Auth bearer tokens, so the user must be signed in.

Important: client-side Gemini keys are not supported in this app anymore.
If no remote endpoint is available, AI falls back to local heuristic mode.
