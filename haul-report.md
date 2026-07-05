# Haul Project Report

**Repository:** Haul-Ecommerce-Marketplace  
**Generated:** 2026-06-30  
**Scope:** Comprehensive audit of the codebase, documented progress notes, test logs, and project configuration files in this repository

## Executive Summary

Haul is an Android-first Flutter commerce app backed by a FastAPI service. The product is built around a curated catalog, personalized recommendations, visual search, cart and wishlist management, and server-authoritative Stripe test checkout.

The repo is unusually well documented: architecture decisions, data model, design tokens, roadmap, bugs, test logs, and handoff notes all live in `progress/`. That makes the implementation easier to verify and gives this project a strong audit trail.

The main architectural idea is simple and sound:

- Flutter owns the UI, local interaction state, and navigation.
- Firebase Auth owns identity.
- Firestore is the canonical data store for catalog, cart, wishlist, events, recommendations cache, explanations cache, and orders.
- FastAPI owns trusted server work such as search/catalog access, AI fallbacks, payment intent creation, and order confirmation.
- Stripe is used in test mode only, and the backend, not the client, decides the amount that gets charged.

## What This Project Is

Haul is a portfolio-grade ecommerce demo with:

- Guest and account-based auth flows
- Home, search, product detail, cart, wishlist, profile, checkout, and order history experiences
- AI-assisted visual search and product explanations
- Personalized "For You" recommendations
- Responsive design tuned for 360, 393, and 414 logical pixel widths
- A real backend plus a separate mock API for contract-driven development

The repo README describes the app as an Android-first Flutter commerce portfolio app with visual search, personalized recommendations, offline-friendly state, and a server-authoritative Stripe checkout.

## Stack

### Frontend

- Flutter
- Dart 3.12
- Riverpod 3 with code generation
- GoRouter with `StatefulShellRoute`
- Firebase Auth
- Cloud Firestore
- SharedPreferences
- Flutter Stripe
- Camera and image picker
- Google ML Kit image labeling
- Cached network images
- Flutter SVG
- Google Fonts
- Shimmer skeleton loaders

### Backend

- FastAPI
- Uvicorn
- Pydantic Settings
- Firebase Admin SDK
- Stripe Python SDK
- Google GenAI SDK
- PyYAML
- Pytest
- httpx
- Python multipart upload support

### Firebase and Cloud

- Firebase Auth
- Firestore
- Firestore rules
- Firestore composite indexes
- Firebase Hosting for static optimized product images
- Firebase Emulator Suite for Firestore rules and backend validation
- GitHub Actions keep-warm workflow

### Tooling

- Flutter analyzer
- Flutter widget and golden tests
- Python backend tests
- OpenAPI validation
- Firestore rules unit tests
- Firebase emulator-driven integration tests
- Screenshot-based QA artifacts in `progress/screenshots/`

## Repo Layout

| Path | Purpose |
|---|---|
| `app/` | Flutter client |
| `backend/` | FastAPI backend, repositories, services, tests, scripts, mock API |
| `progress/` | Architecture, roadmap, data model, decisions, bug log, test log, screenshots, handoff docs |
| `tests/` | Firestore rules test harness |
| `firebase.json` | Firestore emulator config |
| `firestore.rules` | Security rules |
| `firestore.indexes.json` | Composite indexes |
| `.github/workflows/keep-warm.yml` | Health ping for the hosted API |
| `README.md` | Project summary and run instructions |

## Product Architecture

```text
Flutter app
  |-- Riverpod state
  |-- GoRouter navigation
  |-- Firebase Auth
  |-- Firestore-backed cart, wishlist, profile, events, orders
  |-- Local cache and UI tokens
  |
  +--> FastAPI backend
         |-- Catalog/search
         |-- Visual search
         |-- Recommendations
         |-- Product explanations
         |-- Cart validation
         |-- Stripe payment intents
         |-- Order confirmation
```

The trust boundary is intentionally strict:

- The client never decides the final price.
- The client never sends a trusted order total.
- The backend reads current catalog and cart state from Firestore before creating a Stripe payment intent.
- Order confirmation happens server-side after Stripe reports success.
- Orders are committed through Firestore transactions so inventory, cart clearing, and order records stay consistent.

## Client Functionality

### App Shell and Navigation

The app uses a bottom navigation shell with:

- Home
- Search
- Camera
- Cart
- Profile

The center camera button is a prominent floating action with a pulse animation. The shell is implemented with `StatefulShellRoute.indexedStack`, so each main tab preserves its own state while the user moves around.

### Entry Flow

The entry experience includes:

- Splash screen
- Onboarding carousel
- Email sign-in
- Email sign-up
- Google sign-in
- Guest login
- New-user preferences selection

Routing logic distinguishes between:

- Unauthenticated users
- Guest sessions
- New users who still need preferences
- Fully authenticated users

That routing is not just visual. It is backed by the auth controller and Firestore user profile state.

### Home

The home screen combines several discovery surfaces:

- App header and search entry
- "For You" rail
- Category chips
- Featured banner
- Trending product grid

The home page uses:

- Skeleton loading states
- Pull-to-refresh
- Staggered card reveals
- Hero transitions into product detail

### Search

Search supports:

- Text query
- Category filtering
- Color filtering
- Material filtering
- Tag filtering
- Price range filtering
- Sort modes: relevance, newest, price low, price high, rating
- Pagination
- Recent search chips

The search UI debounces typing and loads more results when the list approaches the end. The backend applies the same filter dimensions and returns `appliedFilters` metadata.

### Product Detail

The product page includes:

- Hero image gallery
- Category label
- Price and sale price display
- Rating and review count
- Description
- Color variants
- Quantity selector
- Material/style/tag chips
- AI explanation section for signed-in users
- Add to cart CTA with bounce animation

If a product is missing, the page shows a snackbar and routes back to `/home`.

### Cart

The cart screen supports:

- Listing items from Firestore-backed cart state
- Quantity changes
- Swipe-to-delete
- Empty state
- Checkout entry point

Cart items preserve a `priceSnapshot`, which is important because the backend later validates price drift before checkout.

### Wishlist

The wishlist screen supports:

- Saved item display
- Empty state
- Loading and error states
- Navigation to product details
- A profile preview rail for saved items

The backend exposes a batch product endpoint, and the repo also includes a local fallback path for loading wishlist products if needed.

### Visual Search

The visual search flow is one of the strongest parts of the app. It includes:

- Native camera capture
- Gallery fallback
- Permission-denied recovery
- Camera warm-up and scanning animations
- Processing overlay
- ML Kit labels passed to the backend
- Bottom-sheet results with match badges
- Fallback handling when Gemini is disabled or unavailable

The camera implementation also registers and disposes session resources so the app can clean up correctly across runs.

### Checkout and Orders

Checkout is server-authoritative and includes:

- Shipping address form
- Backend pricing review
- Checkout summary
- Stripe payment sheet
- Success screen with order number
- Order history
- Order detail snapshots

The success screen also offers guest users a path to link an account so the purchase history follows them across devices.

### Profile

The profile screen includes:

- User identity card
- Guest badge
- Wishlist preview
- Order history link
- Wishlist link
- Recommendation settings
- Privacy note
- Logout action

The project uses profile state as both a user hub and a retention surface for saved signals.

## Backend Functionality

### API Surface

The FastAPI app mounts a single versioned router collection covering:

- `/health`
- `/search`
- `/products/{id}`
- `/products/batch`
- `/recommendations/{uid}`
- `/visual-search`
- `/explain-product`
- `/events`
- `/cart/validate`
- `/create-payment-intent`
- `/orders/confirm`
- `/orders/{uid}`

### Catalog

Catalog behavior includes:

- Full product list access
- Single product fetch
- Batch product fetch
- Query, category, color, material, tag, and price filtering
- Pagination via encoded page tokens
- Sorting by relevance, newest, price, and rating

The backend uses a local seed repository when Firestore is not configured, and a Firestore repository when project credentials are available.

### Cart Validation

`/cart/validate` checks:

- Missing products
- Price drift
- Out-of-stock items
- Quantities that exceed inventory

That endpoint is used to keep the cart honest before checkout.

### AI Recommendations

Recommendations are built from:

- User preferences
- User event history
- Product metadata
- Popularity fallback

If a user has no meaningful signal yet, the backend falls back to trending products.

### Visual Search Matching

Visual search supports:

- Gemini-based attribute extraction when configured
- ML Kit label fallback when Gemini is unavailable
- Product scoring based on category, tag overlap, color/material match, text/object match, popularity, and token similarity
- Result caching

The backend caches visual search responses by image hash and recommendation/explanation outputs by cache keys with TTLs.

### Product Explanations

Product explanations are:

- User-specific
- Cached
- Grounded in user preference tags and product attributes
- Generated by Gemini when available
- Fallback-generated from template text when Gemini is unavailable

Guests without preference signal do not get explanations.

### Checkout and Orders

The checkout service:

- Prices the cart from current Firestore product data
- Creates Stripe PaymentIntents
- Verifies succeeded PaymentIntents before order confirmation
- Confirms ownership of the payment intent
- Uses Firestore transactions to commit orders, decrement inventory, and clear the cart
- Enforces idempotency with `uid + paymentIntentId`

Order numbers follow the `HUL-YYYYMMDD-NNNN` format.

### Events

The backend accepts user events and invalidates recommendation caches so the "For You" feed can react to user behavior.

### Health

The health endpoint returns:

- status
- version
- UTC timestamp

The repo includes a GitHub Actions workflow that pings this endpoint every 10 minutes to keep the hosted backend warm.

## Data Model

The locked data model in `progress/02_DATA_MODEL.md` and the Firestore rules reflect these collections:

| Collection | Purpose |
|---|---|
| `products/{productId}` | Catalog source of truth |
| `users/{uid}` | User profile |
| `users/{uid}/cart/{cartItemId}` | Canonical cart |
| `users/{uid}/wishlist/{productId}` | Wishlist |
| `users/{uid}/events/{eventId}` | Behavioral events |
| `users/{uid}/orders/{orderId}` | Order history |
| `recommendations/{uid}` | Cached recommendations |
| `explanations/{uid_productId}` | Cached product explanations |
| `counters/orderSequence/days/{YYYYMMDD}` | Daily order sequence counter |

The frozen category enum is:

- fashion
- electronics
- home
- skincare
- fitness
- accessories

The repo treats that enum as fixed across seed data, filters, prompts, and UI labels.

## Security and Access Control

The security posture is strong for a portfolio app:

- Firestore rules restrict product data to read-only for authenticated users.
- Users can only read and modify their own profile, cart, wishlist, and order data.
- Event writes are owner-scoped and append-only.
- Orders cannot be created or edited directly by the client.
- Recommendations and explanations are readable only by the owning user.
- The backend verifies Firebase ID tokens and ignores `X-API-Key` for auth.
- Stripe secret keys remain server-side.
- The Flutter app only receives a publishable key at build time.

## Design System

The UI is built around the "Warm Signal" design system:

- Warm ivory background
- Coral accent color
- Charcoal-brown text
- Syne for display typography
- Inter for body copy
- Soft card shadows
- Rounded cards, buttons, and sheets
- Staggered motion and springy feedback

The design system is enforced through Dart tokens in `app/lib/core/design/` and documented in `progress/03_DESIGN_SYSTEM.md`.

Shared components include:

- Product cards
- Empty states
- Error states
- Buttons
- Bottom sheets
- Skeleton loaders
- AI badges

The project also keeps screenshot goldens for these shared widgets at multiple screen widths.

## Platform Support

The repository includes scaffolding for:

- Android
- iOS
- macOS
- Windows
- Linux
- Web

Android is the primary target, but the repo also contains platform folders, build files, and documented web build verification. The README notes the web bundle compiles, while the final demo release still depends on remaining blockers.

## Mock API and Contract-First Development

The repo includes a separate mock backend at `backend/mock/` that reads `progress/01_API_CONTRACT.yaml` and returns documented examples.

That setup is useful because it lets the team:

- Develop the Flutter client against stable responses
- Validate request and response shapes early
- Keep contract drift visible

The repo also includes schema generation and OpenAPI validation scripts.

## Verification Evidence

Documented verification in the repo includes:

- Backend pytest suites passing, with the latest logs showing 74 passed and 2 skipped
- Flutter test suite passing, with the README and test logs citing a 61-test suite
- Flutter analyzer clean in the latest logs
- OpenAPI contract validation passing
- Firestore rules tests passing
- Backend health and search smoke tests passing locally
- Android debug APK builds succeeding
- Web release bundle builds succeeding

The `progress/08_TEST_LOG.md` file is the best source for run-by-run evidence. It is unusually detailed and includes both commands and outcomes.

## Open Blockers and Known Gaps

The repo is not pretending to be finished. The current docs and bug log still record real issues:

- `BUG-011`: Firebase options are only truly configured for Android
- `BUG-014`: local secrets in `backend/.env` should be rotated if the workspace was shared
- `BUG-016`: the seeded product image URLs are unreachable until Firebase Hosting assets are deployed
- `BUG-018`: Flutter/Kotlin Gradle Plugin migration warning is still present
- `BUG-020`: Android logout still leaves the anonymous Firebase user persisted in the emulator flow
- Stripe live checkout still needs a real Flutter publishable key for end-to-end verification

The demo script also shows that some acceptance checklist items remain unchecked because they require a real device, live Stripe configuration, or deployment work.

## Notable Implementation Details

- The backend falls back to local seed data when Firestore credentials are missing.
- The client resolves local backend URLs differently for Android emulator, desktop, web, and release builds.
- Search uses encoded page tokens rather than raw offsets.
- Recommendations and explanations are cache-backed to keep repeat responses stable and fast.
- The checkout flow is idempotent and transactionally consistent.
- The app uses generated Riverpod and router code, which keeps the state and navigation layers explicit.

## Source References

Primary files and docs used to build this report:

- [README.md](README.md)
- [progress/00_ARCHITECTURE.md](progress/00_ARCHITECTURE.md)
- [progress/01_API_CONTRACT.yaml](progress/01_API_CONTRACT.yaml)
- [progress/02_DATA_MODEL.md](progress/02_DATA_MODEL.md)
- [progress/03_DESIGN_SYSTEM.md](progress/03_DESIGN_SYSTEM.md)
- [progress/04_ROADMAP.md](progress/04_ROADMAP.md)
- [progress/06_DECISIONS.md](progress/06_DECISIONS.md)
- [progress/07_BUGS.md](progress/07_BUGS.md)
- [progress/08_TEST_LOG.md](progress/08_TEST_LOG.md)
- [progress/09_HANDOFF.md](progress/09_HANDOFF.md)
- [progress/10_DEMO_SCRIPT.md](progress/10_DEMO_SCRIPT.md)
- [app/pubspec.yaml](app/pubspec.yaml)
- [app/lib/main.dart](app/lib/main.dart)
- [app/lib/core/router/app_router.dart](app/lib/core/router/app_router.dart)
- [app/lib/core/api/api_client.dart](app/lib/core/api/api_client.dart)
- [backend/requirements.txt](backend/requirements.txt)
- [backend/app/main.py](backend/app/main.py)
- [backend/app/api/v1/router.py](backend/app/api/v1/router.py)
- [backend/app/services/catalog_service.py](backend/app/services/catalog_service.py)
- [backend/app/services/cart_service.py](backend/app/services/cart_service.py)
- [backend/app/services/checkout_service.py](backend/app/services/checkout_service.py)
- [backend/app/services/ai_service.py](backend/app/services/ai_service.py)
- [backend/app/services/event_repository.py](backend/app/services/event_repository.py)
- [backend/app/services/checkout_repository.py](backend/app/services/checkout_repository.py)
- [backend/app/core/firebase.py](backend/app/core/firebase.py)
- [backend/app/core/config.py](backend/app/core/config.py)
- [.github/workflows/keep-warm.yml](.github/workflows/keep-warm.yml)

## Bottom Line

Haul is a thoughtfully structured ecommerce demo with real product scope, a real backend, a carefully constrained trust boundary, and a strong supporting documentation trail.

Its strongest qualities are:

- A clear split between client and trusted server logic
- A rich, coherent feature set
- Strong use of contract-first and token-driven design
- Good attention to loading, error, and fallback states
- A well-instrumented progress and QA story

Its main remaining weaknesses are operational and integration-related, not architectural:

- live Stripe wiring
- full non-Android Firebase configuration
- product image hosting
- logout persistence on Android emulator

