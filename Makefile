.PHONY: dev build test lint api wasm install clean

install:
	npm install
	rustup target add wasm32-unknown-unknown
	cargo install wasm-pack --version 0.13.1 --locked

dev:
	npm run build:wasm
	npm run dev

build:
	npm run build

test:
	npm test

lint:
	npm run lint

api:
	cd api && gleam run

clean:
	cargo clean --manifest-path engine/Cargo.toml
	rm -rf frontend/dist frontend/elm-stuff wasm/pkg
