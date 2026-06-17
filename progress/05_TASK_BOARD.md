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
| FastAPI skeleton + auth dependency | Track A | Not Started | |
| Firestore rules matching data model | Track A | Not Started | |
| Keep-warm GitHub Action | Track A | Not Started | |

## Sprint 2 - Auth, Onboarding, Navigation

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Splash + onboarding + preferences UI | Track B | Not Started | |
| GoRouter shell + guards | Track B | Not Started | |
| Firebase Auth + user doc creation | Track A | Not Started | |
| Guest-to-account migration, tested | Track A | Not Started | |

## Sprint 3 - Catalog, Home, Search, Product

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Home, Search, Product detail screens | Track B | Not Started | |
| `/search`, `/products/{id}`, `/products/batch`, `/events` | Track A | Not Started | |
| Firestore indexes documented in 02_DATA_MODEL.md | Track A | Not Started | |

## Sprint 4 - Cart, Wishlist, Firestore Sync

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Cart/wishlist UI, optimistic sync, local cache | Track B | Not Started | |
| Cart/wishlist rules + `/cart/validate` | Track A | Not Started | |

## Sprint 5 - Visual Search, Recommendations, Explanations

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Camera flow, results sheet, AI badges | Track B | Not Started | |
| Home For You with real data + staggered reveal | Track B | Not Started | |
| `/visual-search` with fallback | Track A | Not Started | |
| `/recommendations/{uid}` with cold-start fallback | Track A | Not Started | |
| `/explain-product` with cache + template fallback | Track A | Not Started | |

## Sprint 6 - Checkout, Payments, Orders

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Checkout + success animation + Orders screen | Track B | Not Started | |
| `/create-payment-intent`, `/orders/confirm` | Track A | Not Started | |
| Idempotency test (duplicate confirm call) | Track A | Not Started | |

## Sprint 7 - Profile, Polish, Web Build, Release

| Task | Owner | Status | Evidence |
|---|---|---|---|
| Profile screen + full state audit | Track B | Not Started | |
| Flutter Web build deployed | Track B | Not Started | |
| Demo video + README | Track B | Not Started | |
| Deployment hardening + cold-start verification | Track A | Not Started | |
| Final test gate (pytest + emulator rules) | Track A | Not Started | |
