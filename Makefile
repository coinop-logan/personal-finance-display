# Finance Display Build System
#
# This Makefile enforces the correct build order:
# 1. Generate Elm types from Rust (if Rust types changed)
# 2. Build Elm frontend (if Elm source changed)
# 3. Build Rust backend (for deployment)
#
# The type generation ensures frontend-backend contract safety.

.PHONY: all build generate-elm build-elm build-backend deploy clean help

# Default: full build
all: build

# Full build: types -> frontend -> backend
build: generate-elm build-elm build-backend
	@echo "Build complete!"

# Generate Elm types from Rust structs
generate-elm:
	@echo "Generating Elm types from Rust..."
	cd backend && cargo run --bin generate-elm --release
	@echo "Elm types generated: frontend/src/Api/Types.elm"

# Build Elm frontend (depends on generated types)
build-elm: generate-elm
	@echo "Building Elm frontend..."
	cd frontend && elm make src/Main.elm --output=elm.js --optimize
	cp frontend/elm.js frontend/index.html dist/
	@echo "Frontend built: dist/"

# Build Rust backend for target platform
build-backend:
	@echo "Building Rust backend..."
	cd backend && cargo build --release --bin server
	@echo "Backend built: backend/target/release/server"

# Build for Raspberry Pi (ARM) and copy to repo root
build-pi:
	@echo "Cross-compiling for Raspberry Pi..."
	cd backend && PATH="$(HOME)/.cargo/bin:$(PATH)" cross build --release --bin server --target armv7-unknown-linux-gnueabihf
	cp backend/target/armv7-unknown-linux-gnueabihf/release/server server
	@echo "ARM binary copied to: server"

# Full Pi deployment: build everything for Pi
deploy: generate-elm build-elm build-pi
	@echo "Deployment ready! Commit and push to deploy to Pi."

# Clean build artifacts
clean:
	cd backend && cargo clean
	rm -rf frontend/elm-stuff
	rm -f frontend/elm.js
	rm -f dist/elm.js

# Development: run locally
dev: build-elm
	@echo "Starting dev server..."
	cd backend && cargo run --bin server

help:
	@echo "Finance Display Build Targets:"
	@echo "  make build        - Full build (types + frontend + backend)"
	@echo "  make generate-elm - Regenerate Elm types from Rust"
	@echo "  make build-elm    - Build Elm frontend"
	@echo "  make build-backend- Build Rust server"
	@echo "  make build-pi     - Cross-compile for Raspberry Pi"
	@echo "  make dev          - Build and run locally"
	@echo "  make clean        - Clean build artifacts"
