# 10 - Demo Script (what actually works right now)

Unlike the roadmap, this file only reflects reality. Check an item only after it has been live-verified, not when it is merely coded. Re-run this entire checklist at the end of every sprint, together, across both tracks; anything that breaks gets logged in `07_BUGS.md` before the next sprint's prompts are issued.

## Foundation

- [x] Mock API starts locally and returns example payloads for every contract endpoint
- [x] OpenAPI contract validates with `openapi-spec-validator`
- [x] Seed catalog contains 50 products across all six frozen categories and all required card states
- [x] Real FastAPI backend starts locally and returns HTTP 200 from `/health`
- [x] Real catalog API starts locally and returns `/search` results from the 50-product seed with contract-shaped fields
- [x] `/cart/validate` reports price drift and stock changes from current catalog truth without backend-owned cart state
- [x] AI backend returns usable visual-search and explanation fallbacks with Gemini disabled
- [x] AI backend personalizes recommendations for different event histories and falls back to trending for cold starts
- [x] Repeated identical visual-search image returns from hash cache in under 200ms

## App And Product Flows

- [ ] App launches to splash, resolves auth state correctly
- [ ] Guest can enter instantly, no form
- [ ] Email/Google sign-up works
- [ ] Onboarding preferences save and skip correctly for returning users
- [ ] Home loads with skeleton -> real content
- [ ] Search returns results, debounced, paginated
- [ ] Product detail opens with hero transition, no jank
- [ ] Add to cart updates instantly with bounce animation
- [ ] Cart persists offline and reconnect-syncs
- [ ] Wishlist heart state matches profile wishlist
- [ ] Camera opens, captures, and returns visual search results
- [ ] Visual search gracefully falls back when AI is disabled/capped
- [ ] Home "For You" shows different results for two different user histories
- [ ] Product AI explanation renders (and is hidden for guests)
- [ ] Checkout completes with a Stripe test success card
- [ ] Checkout fails gracefully with a declined test card, cart preserved
- [ ] Duplicate order-confirm call does not create a duplicate order
- [ ] Order appears correctly in order history
- [ ] Logout clears all state cleanly
- [ ] Flutter Web build loads fresh and the core flow works with no install
- [ ] Backend survives a 2+ hour idle gap without a visibly broken first request

## Sprint 3 Track B Note - 2026-06-17

Home, Search, and first-pass Product detail are implemented and screenshot-tested, but the checklist items above remain unchecked until the required physical-device/profile-mode hero transition verification is completed. Current environment exposes only Windows, Chrome, and Edge as Flutter devices.

## Sprint 4 Track B Note - 2026-06-17

Cart offline sync, swipe-to-delete, and Wishlist integration have been implemented and golden-tested, but similarly wait on physical-device verification before being marked fully checked in this live script.

## Sprint 5 Track B Note - 2026-06-19

Camera/visual search, cold-start processing copy, fallback badges, personalized/trending For You, and delayed product explanations are implemented and covered by 53 passing Flutter tests. Four screenshots exist in `progress/screenshots/sprint5_visual_search/`, and debug/profile Android APKs compile. The live checklist remains unchecked until a USB-debugging-authorized physical Android device completes the required camera and memory run; ADB detected no device in this session.

## Sprint 7 Track B Note - 2026-06-19

The Android guest Profile is now implemented and live-verified on an API 33 emulator, including responsive settings rows, wishlist empty state, order-history link, and portfolio screenshots. The full Flutter suite passes 61 tests, analyzer is clean, and both Android APK and web bundle compile. The demo checklist remains unchecked for logout because the live emulator still retains the anonymous Firebase user after pressing Log out (`BUG-020`). Stripe flows remain blocked by the missing Flutter publishable key, and no demo video or hosted web deployment was completed.
