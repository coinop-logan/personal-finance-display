# Personal Finance Display - Project History

---

## Session 1

**Date:** 2025-12-13

### Summary

Project created. Goal: dedicated Raspberry Pi screen in bedroom displaying personal finance graph.

**Key decisions:**
- Raspberry Pi 4 with full Pi OS, Chromium in kiosk mode
- Elm for frontend, custom-built graph
- Explored bank scraping as data source (Rust prototype created)

**Explored but later abandoned:**
- Bank scraping approach (too fragile, can't capture non-bank data like daily pay)
- Cloud-based architecture with GitHub Actions
- Rust scraper prototype

---

## Session 1.5

**Date:** Between sessions 1 and 2

Pi was set up and kiosk mode confirmed working.

---

## Session 2

**Date:** 2026-01-02

### Architecture Pivot

Realized bank scraping wouldn't capture manually-tracked values (like "I worked today, earned $X"). Pivoted to fully self-contained local system:

**New architecture:**
- Pi hosts everything - no cloud services
- Python backend (stdlib only, no dependencies) serves API and static files
- Elm frontend with graph display (`/`) and data entry form (`/entry`)
- Data stored in local JSON file on Pi
- Entry from any device on local network via `http://<pi-ip>:3000/entry`

**Deployment system:**
- Code built on dev machine, committed to GitHub
- Pi runs deploy watcher (systemd service) checking every 2 seconds
- Frontend checks for code changes every 500ms, auto-reloads when updated

### Files Created

- `frontend/` - Elm app with graph and entry form
- `server/server.py` - Python HTTP server with JSON storage
- `dist/` - Built frontend (committed for Pi to serve directly)
- `pi-setup/` - Install script, systemd services, deploy watcher

### Cleanup

Removed deprecated files from session 1:
- `scraper/` - Rust bank scraping prototype
- `brainstorming.md` - Early exploration notes
- `project-plan.md` - Outdated planning doc

---

## Session 3

**Date:** 2026-01-02

### Rust Backend Migration

Replaced Python backend with Rust for type safety between frontend and backend.

**New stack:**
- Rust/Axum backend with elm_rs for generating Elm types from Rust structs
- Makefile enforcing correct build order (types → frontend → backend)
- Cross-compilation for Pi 4 (aarch64) using `cross` tool
- CLAUDE.md with instructions for future robots

**Key files:**
- `backend/src/types.rs` - Single source of truth for shared types
- `backend/src/main.rs` - Axum server
- `backend/src/generate_elm.rs` - Type generator binary
- `frontend/src/Api/Types.elm` - Auto-generated Elm types (DO NOT EDIT)
- `server` - Cross-compiled ARM64 binary (committed to repo)

**Deployment workflow:**
```bash
make deploy    # Generates types, builds Elm, cross-compiles ARM binary
git add -A && git commit -m "..." && git push
# Pi auto-pulls and restarts within 2 seconds
```

### Cleanup

- Removed `server/server.py` (replaced by Rust)

---

## Session 4

**Date:** 2026-01-05

### Summary

Major feature development session focusing on the graph visualization and UX improvements.

### Key Changes

**payCashed Logic Fix:**
- Fixed `incomingPayForEntry` algorithm in `Calculations.elm`
- Now correctly checks if ANY entry in current week has `payCashed=true`, then counts only hours from current week (starting Sunday)

**Edit Button:**
- Added edit button next to delete in entry rows
- Clicking populates the form with that row's data for editing (leverages existing upsert behavior)

**elm-ui Refactor:**
- Migrated entire frontend from inline HTML/CSS to `mdgriffith/elm-ui`
- Cleaner layout code with proper Element-based structure

**Credit Limit Field:**
- Added `creditLimit` to Entry type (Rust and Elm)
- New form field between credit available and hours worked

**Graph Implementation (1920x1080 Full HD):**
- SVG-based visualization for Raspberry Pi display
- X-axis: dates from Dec 20 to Jan 31, with weekday+day labels (e.g., "M6")
- Y-axis: dollar amounts in "k" notation ($5k, $10k, etc.), extends below zero for credit
- Green filled bars: checking balance (above x-axis)
- Yellow filled bars: credit drawn (below x-axis, calculated as creditLimit - creditAvailable)
- Cerulean step line: earned money (checking + incoming pay)
- Red step line: personal debt
- End labels on right margin showing current values

**Graph Technical Details:**
- Gap handling: when data points are non-consecutive, extends previous value horizontally to prevent sloping lines
- Step-based rendering: values remain constant until next data point
- No padding/header on graph page (fills entire 1920x1080 display)
- 25 recent entries shown on entry page (up from 5)

### Files Modified

- `frontend/src/Graph.elm` - New graph rendering module
- `frontend/src/Main.elm` - elm-ui refactor, edit button, credit limit field
- `frontend/src/Calculations.elm` - payCashed logic fix
- `backend/src/types.rs` - Added creditLimit field
- `frontend/src/Api/Types.elm` - Regenerated via elm_rs

### Deployment

All changes deployed via `make deploy` with ARM64 cross-compilation for Pi.

---

## Session 5

**Date:** 2026-01-05

### Summary

Polish and styling session. Project reached 1.0 - now running live on bedroom Pi with TV auto-wake in the morning.

### Key Changes

**Graph Polling:**
- Graph page now polls for new data every second (entry page does not poll)
- New entries appear automatically without page reload

**Kiosk Launch Script:**
- Added `pi-setup/launch-kiosk.sh` with Chromium flags to suppress Google background network requests
- Flags: `--disable-background-networking`, `--disable-component-update`, `--disable-sync`, `--disable-translate`, `--no-first-run`

**Graph Styling:**
- Background changed from dark blue (#252542) to medium blue (#6b7aa0)
- Axis/tick marks now black, axis labels dark gray
- Earned money line changed from cerulean to dark blue (#1e40af)
- Debt line changed to stronger red (#dc2626)
- Draw order fixed: data first, then axes, then end labels on top

**Anti-aliasing:**
- Added `shape-rendering="crispEdges"` to SVG for crisp shapes
- Added `text-rendering="optimizeSpeed"` to end labels group for crisp text

**End Labels Improvements:**
- Labels now positioned just right of last data point (not fixed right margin)
- Labels sorted by Y position and pushed down if they would overlap
- Zero-value labels hidden (earned, credit drawn, personal debt)

### Project Status

**1.0 Complete** - Pi running in bedroom, TV turns on before morning alarm.
