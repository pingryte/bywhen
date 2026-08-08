# ByWhen

A calm, local-first answer to one question: **how long until I reach my goal?**

The app includes Savings, Debt, Progress, Repetition, Countdown, and Generic calculators, plus reverse Savings. An independent Rust engine compiled to WebAssembly returns calendar-aware results to Elm. Goals can be saved locally and reopened from the overview; result text can be copied for sharing. No calculation leaves the browser.

## Stack

- Elm 0.19.1 for the browser UI
- Rust for all domain calculations, compiled to WebAssembly
- Gleam/BEAM for the optional sharing API foundation
- SQLite for future shared-goal persistence
- Vite for the static build and development server

Everything is open-source and runs locally with no paid service or account.

## Prerequisites

- Node.js 20+
- Rust 1.85+ with `rustup` (`make install` pins a compatible `wasm-pack` release)
- For the optional API: Gleam 1.12+ and Erlang/OTP 27+
- Docker is optional

## Start

```sh
make install
make dev
```

Open the URL Vite prints (normally `http://localhost:5173`). `make install` installs project-local Elm tooling, the Rust WASM target, and `wasm-pack`. After that, calculations require no network access.

## Commands

```sh
make dev      # compile WASM and start the Elm/Vite dev server
make build    # optimized static build in frontend/dist
make test     # Rust and Elm test commands
make lint     # Rust formatting and Elm formatting checks
make api      # optional Gleam API on :4000
```

Run `docker compose up --build api` instead of `make api` to use the container. The frontend is intentionally independent of it.

Run `make api` alongside `make dev` to enable share links. The browser defaults to `http://127.0.0.1:4000`; set `VITE_API_URL` for another free/self-hosted API location. If it is unavailable, calculations and local goals continue to work.

## Project structure

```text
frontend/    Elm app, styles, manifest, service worker
engine/      reusable Rust calculation crate and tests
wasm/        generated wasm-pack browser package
api/         Gleam HTTP API and SQLite shared-goal repository
migrations/  versioned SQLite schema
docs/        architecture, calculation rules, roadmap
```

See [architecture](docs/architecture.md), [calculation rules](docs/calculation-rules.md), and the [roadmap](docs/roadmap.md). The static app shell and fetched same-origin assets are cached by a service worker in production; the calculator remains useful when the optional backend is unavailable.
