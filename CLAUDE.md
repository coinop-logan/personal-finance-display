# Claude Code Instructions for Finance Display

## Critical: Build Order

**ALWAYS follow this build order when making changes:**

1. **If you change Rust types** (`backend/src/types.rs`):
   ```bash
   make generate-elm   # Regenerates frontend/src/Api/Types.elm
   make build-elm      # Rebuilds Elm with new types
   ```

2. **If you change Elm code** (`frontend/src/*.elm`):
   ```bash
   make build-elm      # Rebuilds and copies to dist/
   ```

3. **For full build**:
   ```bash
   make build          # Does all steps in correct order
   ```

## Why This Matters

The `backend/src/types.rs` file defines the data structures shared between frontend and backend. The `elm_rs` crate generates matching Elm types and decoders in `frontend/src/Api/Types.elm`.

**If you change a field in Rust but don't regenerate Elm types, the app will have runtime errors.** The build order enforcement ensures compile-time type safety across the frontend-backend boundary.

## File Structure

```
backend/
  src/
    types.rs          # Shared types - SINGLE SOURCE OF TRUTH
    main.rs           # Axum server
    generate_elm.rs   # Type generator binary

frontend/
  src/
    Main.elm          # Main application
    Api/
      Types.elm       # AUTO-GENERATED - DO NOT EDIT

dist/                 # Built frontend files (committed for Pi deployment)
```

## Adding New API Types

1. Define the type in `backend/src/types.rs` with derives:
   ```rust
   #[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
   #[serde(rename_all = "camelCase")]
   pub struct MyNewType { ... }
   ```

2. Add generation in `backend/src/generate_elm.rs`

3. Run `make generate-elm`

4. Import and use in `frontend/src/Main.elm`

## Deployment

The Pi pulls from this repo and runs the server. The deploy watcher checks for updates every 2 seconds and restarts the server automatically.

**For full deployment (run this before committing):**
```bash
make deploy   # Generates types, builds Elm, cross-compiles ARM binary
```

This updates:
- `dist/` - Frontend assets
- `server` - ARM binary in repo root (Pi runs this)

**Then commit and push:**
```bash
git add -A && git commit -m "description" && git push
```

The Pi will auto-pull and restart within 2 seconds.

## Do NOT

- Edit `frontend/src/Api/Types.elm` manually
- Skip type regeneration after changing `types.rs`
- Commit without running `make deploy` after changes
- Push without the `server` binary (ARM) in repo root
