# Haul

Haul is an Android-first Flutter commerce portfolio app built around visual
search, personalized recommendations, resilient offline state, and a
server-authoritative Stripe test checkout.

<img width="340" height="257" alt="Screenshot 2026-07-06 190940" src="https://github.com/user-attachments/assets/ed34a482-691f-4e59-af0c-9384a08c04c4" />


## Product Tour

- Guest and Firebase account flows
- Search, filters, product detail, cart, and wishlist
- Gallery/camera visual search with Gemini and local fallback behavior
- Personalized "For You" recommendations
- Stripe test checkout with totals calculated only by the backend
- Immutable order snapshots and order history
- Responsive Warm Signal design system at 360, 393, and 414 logical pixels

## Architecture

```text
Flutter Android app
  |-- Riverpod state + local SharedPreferences cache
  |-- Firebase Auth
  |-- Firestore cart, wishlist, profiles, events, and orders
  |
  +--> FastAPI gateway on Hugging Face Spaces
         |-- catalog/search APIs
         |-- Gemini visual search and recommendation fallbacks
         |-- server-priced Stripe PaymentIntents
         +-- idempotent Firestore order transactions
```

The client never submits or confirms a trusted order total. FastAPI reads the
real cart and current product prices from Firestore, creates the Stripe
PaymentIntent, verifies payment success with Stripe, and commits inventory,
order, counter, and cart changes in one Firestore transaction.

## Screens

<img width="300" height="250" alt="Screenshot 2026-07-06 180219" src="https://github.com/user-attachments/assets/ea2d1d39-e93a-4178-81ce-24ca218fe947" />
<img width="300" height="250" alt="Screenshot 2026-07-06 182223" src="https://github.com/user-attachments/assets/5aaa75fc-8d2d-40d7-8500-5f018efd0258" />
<img width="300" height="250" alt="Screenshot 2026-07-06 182947" src="https://github.com/user-attachments/assets/0478e9b1-e3da-4bf5-9164-9d5ddd2d8771" />
<img width="300" height="250" alt="Screenshot 2026-07-06 183926" src="https://github.com/user-attachments/assets/1139816c-5b68-440a-8231-dd531d88dba7" />


## Run Android

```powershell
cd app
flutter pub get
flutter run -d <android-device-id> `
  --dart-define=HAUL_API_BASE_URL=http://10.0.2.2:8000 `
  --dart-define=HAUL_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

If you are running the web or desktop app locally, the default backend URL is
`http://127.0.0.1:8000`. On an Android emulator, the client automatically uses
`http://10.0.2.2:8000` so it can reach the host machine.

Firebase Android configuration is included. Stripe checkout requires a test
publishable key at build time; backend secrets remain server-side.

## Catalog Seeding Pipeline

The catalog seeder uses the fixed 50-slot blueprint in
`backend/seed/catalog_blueprints.json`, Unsplash image search, Groq visual review,
and independent Gemini verification. It has a 30-minute deadline, durable SQLite
checkpoints, request budgets, and no metadata or image fallback.

```powershell
cd backend
python scripts/import_unsplash_catalog.py preflight
python scripts/import_unsplash_catalog.py stage
```

The stage command prints a run ID immediately. Progress is emitted continuously,
and an interrupted run can be resumed without repeating accepted provider calls:

```powershell
python scripts/import_unsplash_catalog.py status --run-id <run-id>
python scripts/import_unsplash_catalog.py stage --run-id <run-id>
python scripts/import_unsplash_catalog.py validate --run-id <run-id>
```

Review `backend/seed/runs/<run-id>/contact-sheet.html` and the audit artifacts.
Publication is a separate checksum-approved action; staging and validation never
write Firestore.

```powershell
python scripts/import_unsplash_catalog.py publish `
  --run-id <run-id> `
  --approved-checksum <checksum-from-validate>
```

Before publishing, the command validates the artifact again and creates a
Firestore backup. The 50 upserts, stale-product deletions, and catalog metadata
write are committed as one batch. A named backup can be restored explicitly with
`rollback --backup <backup-path>`.

## Verification

```powershell
cd app
flutter analyze
flutter test
flutter build apk --debug --no-pub
```

Current evidence and known blockers are tracked in
[`progress/08_TEST_LOG.md`](progress/08_TEST_LOG.md) and
[`progress/09_HANDOFF.md`](progress/09_HANDOFF.md).


