# 10 — Demo Script (what actually works right now)

Unlike the roadmap, this file only reflects reality. Check an item only after it has been live-verified, not when it's merely coded. Re-run this entire checklist at the end of every sprint, together, across both tracks — anything that breaks gets logged in `07_BUGS.md` before the next sprint's prompts are issued.

- [ ] App launches to splash, resolves auth state correctly
- [ ] Guest can enter instantly, no form
- [ ] Email/Google sign-up works
- [ ] Onboarding preferences save and skip correctly for returning users
- [ ] Home loads with skeleton → real content
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
