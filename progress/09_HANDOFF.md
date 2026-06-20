# 09 - Handoff

## What I did on 2026-06-20

- Kept the backend local and verified it serves `/health` and `/search` successfully.
- Changed the Flutter app’s debug API base URL resolution to point at the local backend by default instead of the remote HF deployment.
- Verified the UI entry flow still works: splash, onboarding, auth, preferences, guest home, and returning-user home all passed in `flow_golden_test.dart`.
- Verified live product search against the local backend returned catalog data, including `p017` and `p015`.

## What is true now

- The app no longer depends on the remote HF backend for local debug runs unless `HAUL_API_BASE_URL` is explicitly set.
- Local backend product search is healthy and responsive.
- Entry-flow screens are intact and still render in the expected order.

## What the next session needs to know

- If you want to point the app somewhere else, set `HAUL_API_BASE_URL`.
- For the local backend on Android emulator, the default debug host is `10.0.2.2:8001`; on desktop/web it is `127.0.0.1:8001`.
- The stable verification evidence is in `08_TEST_LOG.md`; the previous Flutter network smoke helper was removed because it was flaky under live Firestore timing.

## Open blocker

- None for the local screen flow or backend wiring path.
