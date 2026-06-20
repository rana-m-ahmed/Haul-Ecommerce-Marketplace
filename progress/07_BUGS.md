# 07 — Bug Log

Log every bug found, even ones you fix immediately in the same session — this is how the next session (and you, next week) knows what's already been chased down once.

## Severity Legend

| Severity | Definition | SLA |
|---|---|---|
| P0 | Blocks a core demo flow or crashes the app | Fix immediately, before any new feature work |
| P1 | Major user-facing break (wrong total, stuck loading, broken nav) | Fix in the same sprint |
| P2 | Noticeable but non-blocking (jank, minor overflow, weak fallback copy) | Fix before release candidate |
| P3 | Polish (spacing, microcopy, icon alignment) | Fix only if time remains |

## Open

| ID | Severity | Description | Found In | Status |
|---|---|---|---|---|
| BUG-001 | P1 | `app/lib/main.dart` uses `colorScheme: .fromSeed(...)`, which is invalid Dart and will block `flutter analyze` until corrected or replaced. | Sprint 0 foundation flatten | Open |
| BUG-005 | P2 | The older tail of `progress/08_TEST_LOG.md` contains embedded NUL bytes from a prior mixed-encoding write, causing tools such as `rg` to classify the log as binary. Current Sprint 5 evidence remains readable near the top. | Sprint 5 Track A final verification | Open |
| BUG-009 | P2 | Full `dart analyze lib test` still exits nonzero on seven pre-existing cart/wishlist/shell issues: four warnings and three `use_build_context_synchronously` infos. No Sprint 5 files report analyzer issues. | Sprint 5 Track B final verification | Open |
| BUG-011 | P1 | `app/lib/firebase_options.dart` is only truly configured for Android. iOS/macOS/Windows/Linux throw unsupported Firebase configuration errors, and the web block is still marked as a placeholder. | 2026-06-19 auth/storage/key QA audit | Open |
| BUG-013 | P2 | `app/test/flow_golden_test.dart` currently fails all three home-flow goldens with about 20% pixel diffs, even though `debug_router_test.dart` still passes. | 2026-06-19 startup/auth verification | Open |
| BUG-014 | P1 | Active-looking Firebase, Gemini, and Stripe credentials are stored in the ignored local `backend/.env`. The file is git-ignored, but credentials should be rotated if this workspace or any captured agent/tool transcript has been shared. | Sprint 6 Track A credential audit | Open |
| BUG-016 | P1 | All 44 non-empty seed product image URLs at `hual-assets.web.app` are unreachable, and six products intentionally have no image. Production Firestore is populated, but real product imagery cannot be completed until Firebase Hosting assets are created/deployed. | Sprint 6 catalog production import | Open |
| BUG-018 | P2 | `flutter build apk --debug --no-pub` succeeds, but Flutter warns that the app project and `stripe_android` still apply the Kotlin Gradle Plugin in a way that will break in future Flutter releases unless migrated to Built-in Kotlin. | 2026-06-19 frontend verification | Open |
| BUG-020 | P1 | Android logout navigates away from Profile but the anonymous Firebase user remains in the persisted Firebase Auth store. Firebase-first sign-out ordering did not resolve the live emulator failure. | Sprint 7 Android live run | Open |

## Resolved

| ID | Severity | Description | Found In | Resolved In | Notes |
|---|---|---|---|---|---|
| BUG-002 | P2 | Sprint 3 catalog grids used tiles too short for existing product cards/skeletons at 393px, causing RenderFlex bottom overflows. | Sprint 3 Track B Home/Search implementation | Sprint 3 Track B Home/Search implementation | Increased Home/Search grid tile height and verified via Flutter tests/screenshots. |
| BUG-003 | P2 | Product detail sticky add-to-cart CTA overflowed horizontally at 393px when rendered with icon + label. | Sprint 3 Track B Product detail implementation | Sprint 3 Track B Product detail implementation | Made the sticky CTA text-only and widened its flex allocation; verified via screenshot test. |
| BUG-004 | P1 | Firestore-backed catalog initialization could silently fall back to seed data because Firebase initialization cached an unhashable `Settings` object, and emulator access required ADC credentials. | Sprint 4 Track A cart validation | Sprint 4 Track A cart validation | Removed the invalid cache and added anonymous Firestore emulator credentials; verified by mutating a product price in the emulator and calling `/cart/validate`. |
| BUG-007 | P1 | A stalled Riverpod generator run reverted `app_router.dart` to an old placeholder-only source, removing real Home/Search/Product/Cart/Wishlist routes. | Sprint 5 Track B implementation | Sprint 5 Track B implementation | Restored the previously inspected route structure and added the real Camera route; full Flutter suite passes. |
| BUG-008 | P2 | `widget_golden_test.dart` mounted the consumer-based `HaulProductCard` without a `ProviderScope`, causing 24 exception-screen golden failures. | Sprint 5 Track B regression verification | Sprint 5 Track B regression verification | Wrapped the golden harness in `ProviderScope`; all 39 shared-widget golden tests pass. |
| BUG-010 | P0 | Flutter app startup never initialized Firebase, so `FirebaseAuth` and Firestore-backed flows could fail immediately at runtime even with real project keys present. | 2026-06-19 auth/storage/key QA audit | 2026-06-19 auth/storage/key QA audit | Added `WidgetsFlutterBinding.ensureInitialized()` plus `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `app/lib/main.dart`; backend regression tests and direct Dart analysis passed afterward. |
| BUG-012 | P1 | Checkout was not wired end-to-end to Stripe: `backend/app/services/checkout_service.py` returned contract examples and never called Stripe. | 2026-06-19 auth/storage/key QA audit | Sprint 6 Track A / 2026-06-19 | Implemented server-side cart pricing, Stripe create/retrieve calls, atomic Firestore confirmation, order history, and emulator/live test-mode verification. |
| BUG-017 | P2 | Full Flutter suite currently had nine failures: stale cart/home/product goldens plus existing Sprint 3/Sprint 5 async/content expectations. | Sprint 6 final regression run | 2026-06-19 frontend verification | Fixed deterministic API/auth test harness gaps, refreshed affected goldens, and reran the full Flutter suite to 57 passing tests. |
| BUG-019 | P1 | Guest tapping Profile was redirected to `/auth`, then immediately redirected back to Home, making the Sprint 7 guest profile and account-link CTA unreachable. | Sprint 7 Android live run | Sprint 7 portfolio pass / 2026-06-19 | Removed the obsolete Profile protection guard; guest Profile remains reachable while account-link actions still use `/auth?link=true`. |
| BUG-015 | P2 | Backend settings only load `backend/.env` when commands start inside `backend/`; running the documented import script from repo root fell back to ADC and failed. | Sprint 6 catalog production import | 2026-06-20 Firebase fetch debug | Resolved with a repo-root-aware `get_settings()` env-file resolver plus a `HUAL_ENV_FILE` test escape hatch. Verified by loading Firebase config from repo root, reading `products/p017` live, and rerunning the full backend suite. |
