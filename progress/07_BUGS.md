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

## Resolved

| ID | Severity | Description | Found In | Resolved In | Notes |
|---|---|---|---|---|---|
| | | | | | |
