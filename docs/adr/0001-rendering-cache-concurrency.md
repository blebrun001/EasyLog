# ADR 0001: Rendering Cache Concurrency Strategy

- Date: 2026-04-15
- Status: Accepted

## Context
The renderer previously used mutable `static` globals with `nonisolated(unsafe)` and `NSLock`.
This pattern is fragile in Swift 6 strict-concurrency mode and hard to audit.

## Decision
Use dedicated lock-encapsulated cache containers (`TextWidthCache`, `SymbolRenderCache`) and expose only thread-safe methods.
No caller directly mutates global cache dictionaries.

## Consequences
- Better concurrency hygiene and narrower mutation surface.
- Slight indirection cost per cache lookup.
- Future migration to actor-backed async caches remains straightforward.
