# ADR 0002: Centralized Render Tuning

- Date: 2026-04-15
- Status: Accepted

## Context
Rendering and UI refresh behavior relied on hardcoded constants in `ProjectViewModel`.
That made performance tuning and regression analysis difficult.

## Decision
Introduce `RenderTuning` and inject it into `ProjectViewModel`.
All key limits and debounce values now come from this type.

## Consequences
- Better testability and environment-specific tuning.
- Reduced risk of hidden "magic numbers" drift.
- Backward-compatible defaults preserve existing runtime behavior.
