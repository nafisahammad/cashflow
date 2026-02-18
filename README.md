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
