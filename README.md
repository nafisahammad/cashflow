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

The AI mic flow now calls a Firebase Cloud Function:

- Function name: `aiTransactionDecision`
- Region: `us-central1`
- Route: `https://us-central1-<your-project-id>.cloudfunctions.net/aiTransactionDecision`

### 1) Install and deploy functions

```powershell
cd functions
npm install
cd ..
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

### 2) Run Flutter app with AI endpoint

```powershell
flutter run --dart-define=CASHFLOW_AI_ENDPOINT=https://us-central1-<your-project-id>.cloudfunctions.net/aiTransactionDecision
```

If `CASHFLOW_AI_ENDPOINT` is not provided, the app uses a simple fallback classifier instead of Gemini.
The function validates Firebase Auth bearer tokens, so the user must be signed in.
