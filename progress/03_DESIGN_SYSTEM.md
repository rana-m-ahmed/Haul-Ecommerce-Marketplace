# 03 — Design System: "Warm Signal"

No raw color, font, spacing, radius, or shadow value should ever appear outside this file and its generated Dart token files (`/app/lib/core/design/*.dart`). If a screen needs a new value, it gets added here first.

## Color

| Token | Hex | Use |
|---|---|---|
| `background` | `#FAF6EF` | Warm ivory base |
| `surface` | `#FFFFFF` | Cards |
| `textPrimary` | `#2B2520` | Deep charcoal-brown |
| `textSecondary` | `#6B6258` | Warm gray |
| `accent` | `#FF5A36` | Signal coral — CTAs, active states, AI badges |
| `accentSoft` | `#FFB199` | Light coral — badge backgrounds |
| `success` | `#2F9E5B` | Success states |
| `error` | `#C73E3A` | Error states |
| `border` | `#EDE6DA` | Dividers, card outlines |

## Typography

- Display/headings: **Syne** — distinctive, geometric, not a default Material/iOS look.
- Body/UI text: **Inter**.
- Scale: Display 32/28, H1 24, H2 20, H3 18, Body 16/14, Caption 12.
- Micro labels: 10/11, reserved for compact badges where Caption cannot fit.

## Spacing Scale

4, 8, 12, 16, 24, 32, 48, 64

`2` is reserved for optical micro-gaps inside compact badges and indicators.

## Radius

- Card: 20
- Button: 14
- Bottom sheet (top corners): 28
- Chip/pill: 999
- Micro indicator: 4

## Shadow

- Card: soft diffuse, roughly `0 8 24 rgba(0,0,0,0.06)` — no hard Material elevation look.
- Button/floating elements: `0 4 12 rgba(0,0,0,0.08)`.

## Motion

| Token | Value |
|---|---|
| `durationFast` | 150ms |
| `durationBase` | 250ms |
| `durationSlow` | 400ms |
| `durationHero` | 500ms |
| `curveStandard` | `Curves.easeOutCubic` |
| `curveSpring` | Custom spring simulation: mass 1, stiffness 180, damping 20 — used for bounce/elastic interactions (add-to-cart, bottom sheets) |
| `curveEmphasis` | `Curves.easeInOutQuart` — used for hero transitions |
| `staggerInterval` | 40–60ms per item, for list reveals |

## Required Motion Moments

Staggered home card reveal, camera FAB pulse, camera scanning line, focus rectangle corner animation, product card → product page hero transition, add-to-cart bounce, bottom sheet spring slide-up, checkout success animation, shimmer skeleton loaders matching the real layout's exact dimensions (no layout pop on load).

## Component State Checklist

Every shared widget (especially `HaulProductCard`) must be verified at 360px, 393px, and 414px widths, in these states: normal, sale, new, out of stock, wishlisted, horizontal-scroll variant, grid variant, visual-search-result with match badge.
