# 05 - Task Board

Update this file at the end of every single session, in either tool. Status values: `Not Started`, `In Progress`, `Blocked`, `Done`. A task is not `Done` without verification evidence existing somewhere in `/progress` (test log entry, screenshot, etc).

## Sprint 0 - Foundation Lock

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Architecture skeleton (/backend, /app) | Codex | Done | `08_TEST_LOG.md` Sprint 0 Foundation / 2026-06-17 |
| Full OpenAPI contract written | Codex | Done | `openapi-spec-validator progress/01_API_CONTRACT.yaml: OK` in `08_TEST_LOG.md` |
| Mock server serving contract examples | Codex | Done | curl sweep for all 12 endpoints in `08_TEST_LOG.md` |
| 50-product seed data, all categories + visual states | Codex | Done | seed sanity check in `08_TEST_LOG.md` |
| Git branches (backend/main, app/main) initialized | Codex | Done | `git branch --list` evidence in `08_TEST_LOG.md` |

## Sprint 1 - Design System + Backend Scaffolding

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Design tokens (color/type/spacing/radius/shadow/motion) | Track B | Not Started | |
| Shared widget library + widget gallery screen | Track B | Not Started | |
| Golden tests, 3 breakpoints | Track B | Not Started | |
| FastAPI skeleton + auth dependency | Track A | Done | `pytest backend/app/tests -q`: 45 passed; local `/health` curl 200 in `08_TEST_LOG.md` |
| Firestore rules matching data model | Track A | Done | Firestore emulator rules passed via `npm.cmd run test:rules`; Java blocker resolved. See `08_TEST_LOG.md` Sprint 4 Track A / 2026-06-17. |
| Keep-warm GitHub Action | Track A | Done | `.github/workflows/keep-warm.yml` curls `/health` every 10 minutes |

## Sprint 2 - Auth, Onboarding, Navigation

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Splash + onboarding + preferences UI | Track B | Done | Screen sequence integrated in `09_UI_LOG.md` |
| GoRouter shell + guards | Track B | Done | flow_golden_test.dart passed, screenshots generated in progress/screenshots/sprint2_flows |
| Firebase Auth + user doc creation | Track A | Done | Real auth implemented via firebase_auth, user profile docs created in Firestore; `flutter analyze` passes |
| Replace placeholders with real keys | Track A | Blocked | Android Firebase config is real and `app/lib/main.dart` now initializes Firebase, but `app/lib/firebase_options.dart` still contains unconfigured iOS/web/desktop placeholders. See `08_TEST_LOG.md` 2026-06-19 QA audit and `BUG-011`. |
| Guest-to-account migration, tested | Track A | Not Started | |

## Sprint 3 - Catalog, Home, Search, Product

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Home, Search, Product detail screens | Track B | Blocked | UI implemented; `dart analyze lib test`: OK; full Flutter suite: 57 passed; refreshed Sprint 3 screenshots/goldens verified on 2026-06-19. Still blocked only on required real-device/profile-mode hero jank verification because no physical device is attached. See `08_TEST_LOG.md`. |
| `/search`, `/products/{id}`, `/products/batch`, `/events` | Track A | Done | `pytest backend/app/tests -q`: 59 passed; OpenAPI validation OK in `08_TEST_LOG.md` |
| Firestore indexes documented in 02_DATA_MODEL.md | Track A | Done | `02_DATA_MODEL.md` composite index table + `firestore.indexes.json` |

## Sprint 4 - Cart, Wishlist, Firestore Sync

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Wishlist & Cart Flutter UI Integration | Track B | Done | Riverpod Controller/Notifier pairs, pessimistic UI updates, offline cache rollback. Blocked on real device for hero animations. |
| Cart/wishlist rules + `/cart/validate` | Track A | Done | `npm.cmd run test:rules`; `python -m pytest backend/app/tests -q`; Firestore emulator drift check via `npx.cmd firebase emulators:exec --only firestore "python -m pytest backend/app/tests/test_cart_validate_firestore.py -q"`. See `08_TEST_LOG.md`. |

## Sprint 5 - Visual Search, Recommendations, Explanations

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Camera flow, results sheet, AI badges | Track B | Blocked | Implemented; Sprint 5 UI tests pass inside the now-green 57-test Flutter suite, screenshot sequence exists, and debug APK builds. Blocked only on required physical-device 3-cycle memory verification because `adb devices -l` is empty. See `08_TEST_LOG.md`. |
| Home For You with real data + staggered reveal | Track B | Done | Authenticated recommendations + identical guest/cold-start trending fallback verified in `sprint5_ai_ui_test.dart`; full 53-test suite passed. |
| `/visual-search` with fallback | Track A | Done | Gemini-disabled fallback + 9.484ms repeated-image cache hit; `08_TEST_LOG.md` Sprint 5 Track A |
| `/recommendations/{uid}` with cold-start fallback | Track A | Done | Distinct home/fitness histories + trending cold start; `08_TEST_LOG.md` Sprint 5 Track A |
| `/explain-product` with cache + template fallback | Track A | Done | Gemini-disabled template, cache hit, no-signal guest suppression; `08_TEST_LOG.md` Sprint 5 Track A |

## Sprint 6 - Checkout, Payments, Orders

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Checkout + success animation + Orders screen | Track B | Blocked | Implemented; re-verified on 2026-06-19 with `dart analyze lib test` and `flutter test test/sprint6_checkout_test.dart` (`4 passed`). Still blocked on required live 4242/decline runs because no Android device/emulator is available, no AVD is installed, and no Flutter `HAUL_STRIPE_PUBLISHABLE_KEY=pk_test_...` is configured. See `08_TEST_LOG.md`. |
| `/create-payment-intent`, `/orders/confirm` | Track A | Done | Server-priced Stripe test-mode intents, Stripe-confirmed payments, atomic Firestore order transaction, daily sequence, inventory decrement, cart clear, and order history. Re-verified in `08_TEST_LOG.md` Sprint 6 Track A Re-Verification / 2026-06-19. |
| Idempotency test (duplicate confirm call) | Track A | Done | Firestore emulator: duplicate confirm returned the same order ID, exactly one order existed, inventory decremented once. Re-verified in `08_TEST_LOG.md` Sprint 6 Track A Re-Verification / 2026-06-19. |

## Sprint 7 - Profile, Polish, Web Build, Release

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Profile screen + full state audit | Track B | Blocked | Profile implemented and live on Android; 61 Flutter tests pass, analyzer clean, responsive widths verified, and screenshots saved. Blocked because live logout still leaves the anonymous Firebase user persisted (`BUG-020`). |
| Flutter Web build deployed | Track B | Blocked | `flutter build web --release --no-pub` succeeds, but no Firebase web app is registered and Hosting deployment was not completed. User clarified Android is the product target. |
| Demo video + README | Track B | Blocked | Portfolio README with architecture and screenshots added. No 2-3 minute demo video was recorded in this terminal environment. |
| Deployment hardening + cold-start verification | Track A | Done | Firebase env-file loading now resolves from repo root, `HUAL_ENV_FILE` can disable file loading in tests, live `products/p017` Firestore read verified from repo root, and `python -m pytest backend/app/tests -q` passed (`74 passed, 2 skipped`). See `08_TEST_LOG.md` 2026-06-20 Firebase fetch debug. |
| Final test gate (pytest + emulator rules) | Track A | Not Started | |
