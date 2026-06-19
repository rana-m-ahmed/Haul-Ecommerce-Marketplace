# 02 — Data Model

## Category Enum (frozen, used everywhere — seed data, filters, visual search prompts, UI copy)
`fashion`, `electronics`, `home`, `skincare`, `fitness`, `accessories`

## Firestore Collections

| Collection | Purpose | Key Fields |
|---|---|---|
| `products/{productId}` | Catalog, public read, no client writes | `name`, `description`, `price`, `salePrice`, `category`, `colors`, `materials`, `style`, `tags`, `searchTokens`, `imageUrls`, `rating`, `reviewCount`, `inventory`, `isNew`, `isSale`, `createdAt` |
| `users/{uid}` | Profile | `email`, `displayName`, `isGuest`, `preferences`, `preferencesCompleted`, `createdAt`, `lastActiveAt` |
| `users/{uid}/cart/{cartItemId}` | Canonical cart | `productId`, `variantId`, `quantity`, `priceSnapshot`, `addedAt`, `updatedAt` |
| `users/{uid}/wishlist/{productId}` | Wishlist | `productId`, `addedAt` |
| `users/{uid}/events/{eventId}` | Behavior signal for recommendations | `eventType`, `productId`, `category`, `timestamp`, `sourceScreen` |
| `users/{uid}/orders/{orderId}` | Order history | `orderNumber`, `items`, `total`, `currency`, `status`, `shippingAddress`, `paymentIntentId`, `createdAt` |
| `recommendations/{uid}` | Cached For You | `forYouProductIds`, `hydratedAt`, `generatedAt`, `reason` |
| `explanations/{uid_productId}` | Cached AI explanations | `uid`, `productId`, `explanationText`, `provider`, `generatedAt`, `expiresAt` |
| `counters/orderSequence/{YYYYMMDD}` | Atomic daily order-number counter | `count` |

## Firestore Rules Policy

| Resource | Client Access |
|---|---|
| Products | Authenticated users read-only. No client writes. |
| User profile | Read/write own safe fields only. |
| Cart | Read/write own cart; quantity must be 1–20. |
| Wishlist | Read/write own wishlist. |
| Events | Create own events only; no update/delete. |
| Orders | Read own orders only. Client cannot create or edit directly — Admin SDK only. |
| Recommendations/Explanations | Read own cached doc only. Backend writes. |

## Firestore Composite Indexes

Catalog search uses the existing `products.category` field from the frozen model; do not introduce `categoryId`.

| Collection | Fields | Supports |
|---|---|---|
| `products` | `category` ASC, `createdAt` DESC | Category filter + newest sort |
| `products` | `category` ASC, `price` ASC | Category filter + price low sort/range |
| `products` | `category` ASC, `price` DESC | Category filter + price high sort/range |
| `products` | `category` ASC, `rating` DESC | Category filter + rating sort |
| `products` | `category` ASC, `searchTokens` ARRAY, `createdAt` DESC | Category + local token search + newest |
| `users/{uid}/events` | `timestamp` DESC | Recent behavior-event reads for Sprint 5 recommendations |

## Recommendation Event Weights

| Event | Weight |
|---|---:|
| Purchase | 10 |
| Add to cart | 8 |
| Wishlist | 6 |
| Long dwell time | 5 |
| Product view > 3s | 4 |
| Visual search match tap | 4 |
| Text search | 3 |
| Category tap | 2 |
| Quick bounce | -1 |

Maintain a `tag → weight` preference vector per user from these events; normalize periodically so one long session doesn't dominate the vector forever. Cold-start users (no events yet) get the onboarding-preference seed vector, falling back to trending if even that's empty.

## Visual Search Matching Weights

| Signal | Weight |
|---|---:|
| Category match | 30% |
| Tag overlap | 25% |
| Color/material match | 15% |
| Text/object match | 10% |
| Popularity/rating | 10% |
| Local embedding similarity (if available) | 10% |

Return top 5–8 products.

## Order Number Format

`HUL-{YYYYMMDD}-{4-digit zero-padded daily sequence}`, e.g. `HUL-20260617-0007`. Generated via an atomic increment on `counters/orderSequence/{YYYYMMDD}` inside the same Firestore transaction that creates the order — never a random suffix, since the sequence guarantees no collision and reads cleanly in a live demo.

## Idempotency

Every `/orders/confirm` call is keyed on `uid + paymentIntentId`. A repeat call with the same key returns the existing order instead of creating a duplicate.
