# 04 — Roadmap

This is the single, current hour estimate. It supersedes any earlier estimate from prior planning documents — those are now historical reference only, not active targets.

| Sprint | Name | Duration | Track A (Backend) | Track B (Frontend) |
|---:|---|---:|---|---|
| 0 | Foundation Lock | 8–12h | Contract, mock server, seed data, repo split | — (single combined run) |
| 1 | Design System + Backend Scaffolding | 14–18h | FastAPI skeleton, auth dependency, Firestore rules, keep-warm CI | Design tokens, shared widgets, widget gallery |
| 2 | Auth, Onboarding, Navigation | 12–16h | Firebase Auth, user doc, guest migration | Splash, onboarding, preferences, shell routes |
| 3 | Catalog, Home, Search, Product | 20–26h | `/search`, `/products/{id}`, `/products/batch`, `/events` | Home, Search, Product detail (no AI section yet) |
| 4 | Cart, Wishlist, Firestore Sync | 14–18h | Cart/wishlist rules, `/cart/validate` | Cart + wishlist UI, optimistic sync, local cache |
| 5 | Visual Search, Recommendations, Explanations | 20–28h | `/visual-search`, `/recommendations/{uid}`, `/explain-product` | Camera flow, results sheet, For You, AI explanation UI |
| 6 | Checkout, Payments, Orders | 20–26h | `/create-payment-intent`, `/orders/confirm`, idempotency | Checkout, success animation, Orders screen |
| 7 | Profile, Polish, Web Build, Release | 18–24h | Deployment hardening, keep-warm verification, final test gate | Profile, polish pass, Flutter Web build, demo video, README |

**Total: 126–168 hours.**

## Scope Control

### Keep for the portfolio build
Splash/onboarding/preferences, Home (For You/categories/banner/trending), Search with filters, Product detail with variants/reviews-preview/similar products/AI explanation, Cart with optimistic Firestore sync, Visual search with fallback, Stripe test checkout, Order success + history, Profile with wishlist + logout, Flutter Web demo build.

### Cut or defer (not worth the QA surface for a demo)
Real push notifications, promo code engine, live order tracking (a static status badge is enough), profile editing, review submission (read-only reviews are enough), frequently-bought-together (static seed only if time allows), uptime monitoring beyond the keep-warm ping.
