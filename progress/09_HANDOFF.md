# 09 - Handoff

**Session:** Sprint 0 / Foundation / Codex / 2026-06-17

**What I did:**
- Flattened the project to root-level `progress/`, `backend/`, and `app/` layout. The previous Flutter scaffold from `haul/` now lives in `app/`.
- Replaced `progress/01_API_CONTRACT.yaml` with the complete OpenAPI 3.0.3 contract for all 12 Sprint API endpoints.
- Added the FastAPI mock server in `backend/mock/`, backed by examples read from the OpenAPI contract.
- Added `backend/seed/products.json` with 50 products across `fashion`, `electronics`, `home`, `skincare`, `fitness`, and `accessories`, covering normal, sale, new, out-of-stock, multi-variant, and missing-image card states.
- Installed Python 3.12 user-scope on this machine because only the Microsoft Store Python stub existed initially.
- Validated the OpenAPI contract and live-curl tested every mock route.
- Initialized git with a shared `main` foundation commit containing only `progress/` and `backend/seed/products.json`; created `backend/main` and `app/main` branches from it.

**What's now true about the app that wasn't true before:**
- The API contract is complete and validates with `openapi-spec-validator`.
- Track B has a local mock API target that returns the contract's success examples.
- Seed product data is available before the real Firestore backend exists.
- Sprint 0 rows in `progress/05_TASK_BOARD.md` are marked Done with verification evidence in `progress/08_TEST_LOG.md`.

**What the next session needs to know:**
- Run the mock server from repo root:
  ```powershell
  C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m uvicorn backend.mock.app:app --host 127.0.0.1 --port 8000
  ```
- Flutter should point its API base URL at `http://127.0.0.1:8000` for desktop/web runs against the mock. For Android emulator runs, use `http://10.0.2.2:8000`.
- The mock reads `progress/01_API_CONTRACT.yaml` at startup. To change a mocked response, update the contract example and restart uvicorn.
- Success examples are returned by default. Alternate examples are available with `?example=...`, such as `?example=failure`, `?example=cold_start_fallback`, `?example=fallback`, or `?example=template_fallback`.
- `progress/06_DECISIONS.md` already contains Decision-001 for FastAPI on Hugging Face Spaces, including the cold-start trade-off and keep-warm/client-loading mitigation. Do not reopen that debate without a new decision entry.
- `app/lib/main.dart` still contains the invalid starter-code expression `colorScheme: .fromSeed(...)`; it is logged as `BUG-001` in `progress/07_BUGS.md` and was not fixed in Sprint 0.

**Open blockers (if any):**
- None for Sprint 0. The only known issue is BUG-001 in the Flutter starter screen, which belongs to Sprint 1 app cleanup or replacement.
