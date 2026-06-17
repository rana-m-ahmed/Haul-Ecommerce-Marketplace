# 00 — Architecture (LOCKED)

Edits to this file require a logged entry in `06_DECISIONS.md` first. This is binding for both Antigravity and Codex sessions.

## Layer Decisions

| Layer | Choice | Reason |
|---|---|---|
| Mobile/web client | Flutter, Riverpod 2 + codegen, GoRouter + ShellRoute | Testable async state; one codebase covers Android + a Web build for client demos |
| Auth | Firebase Auth (anonymous, email, Google) | Free, no card required, native guest flow |
| Database | Cloud Firestore (Spark) | Canonical store: products, users, cart, wishlist, events, recommendations cache, explanations cache, orders |
| Product images | Firebase Hosting (static optimized assets) | Cloud Storage now requires an attached billing account even for free usage — Hosting does not |
| Backend gateway | FastAPI on Hugging Face Spaces (Docker, free CPU) | Only remaining Python-friendly free host needing neither a card nor reliance on a paid tier |
| AI | Gemini Flash/Flash-Lite (server-side) + ML Kit/local fallback on-device | Key stays server-side; app degrades gracefully if Gemini is capped or offline |
| Payments | Stripe test mode, server-confirmed | Demo-realistic, zero real money risk |
| CI/CD | GitHub Actions | Free; also runs the keep-warm ping below |

## Known Trade-off and Its Mitigation

Hugging Face Spaces' free tier can sleep after inactivity — the same failure mode that ruled out Render in earlier drafts of this plan. Mitigated two ways:
1. A GitHub Actions cron job hits `/health` every 10 minutes to keep the Space warm.
2. The Flutter client gives the first AI/checkout call of a session a longer timeout and a "waking up" loading state instead of a flat spinner, so a cold start never reads as a broken app.

## Layer Ownership

| Layer | Owns | Does Not Own |
|---|---|---|
| Flutter | UI, design system, optimistic local state, navigation, camera UX | Secrets, price calculation, inventory decrement, final order creation |
| Firebase Auth | Email/Google/anonymous auth, account linking | Business logic |
| Firestore | Products, profiles, cart, wishlist, events, recs cache, explanations cache, orders | Secret API calls |
| FastAPI (HF Spaces) | AI calls, payment intent, order confirmation, search/product APIs, event ingestion | Long-term storage outside Firestore |
| Stripe | Test payment processing only | Order truth — the Firestore order document is the app's record |

## Non-Negotiable Rules

- No client-side AI keys. No Stripe secret key in Flutter — publishable key only.
- No client-trusted totals. The backend reads price/inventory from Firestore; it never accepts a total in a request body.
- No raw hex, spacing, or font values outside `03_DESIGN_SYSTEM.md` and its generated Dart token files.
- No new screen ships without loading, error, empty, and success states.
- No endpoint ships without a typed schema in `01_API_CONTRACT.yaml` and a fixture for both its success and failure case.
- The category enum is frozen: `fashion`, `electronics`, `home`, `skincare`, `fitness`, `accessories`. Do not introduce variants (e.g. "beauty") anywhere — seed data, filters, visual search prompts, or UI copy.
