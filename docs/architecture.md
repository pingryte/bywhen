# Architecture

ByWhen is deliberately local-first. The dependency direction is:

```text
Elm UI → typed port → tiny JavaScript bridge → Rust/WASM engine
                                              ↘ JSON result → Elm

Elm UI ── optional save/share ──→ Gleam HTTP API → SQLite
```

The Rust crate is a UI-independent library and is the only source of calculation rules. Its `rlib` target supports native tests and future server validation; its `cdylib` target is compiled by `wasm-pack`. JavaScript only initializes WASM and moves JSON across Elm ports.

The browser calculation path never calls the API. This preserves instant updates, offline use, and privacy. The API currently provides the Phase 1 health endpoint; the SQLite migration establishes the Phase 5 persistence shape without prematurely coupling it to the calculator.

## Language roles

- **Elm:** predictable state transitions, typed forms, accessible HTML, rendering.
- **Rust:** domain validation, calendar arithmetic, scenarios, milestones, native/WASM portability.
- **Gleam:** a small fault-tolerant BEAM HTTP boundary for later sharing and persistence.
- **JavaScript:** browser/WASM interoperability only.
- **SQLite:** account-free, zero-cost shared-goal persistence.
