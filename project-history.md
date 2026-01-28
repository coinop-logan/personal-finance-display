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

---

## Session 6

**Date:** 2026-01-06

### Summary

Bug fixes and deployment reliability improvements.

### Key Changes

**Build Fix:**
- Previous session built Elm to `main.js` instead of `elm.js`, but `index.html` loads `elm.js`
- Clock overlay change was never actually deployed; rebuilt correctly

**Graph Display Adjustments:**
- Start date changed from Dec 20 to Dec 29
- Y-axis max changed from $20k to $15k

**Deployment Delay Fix:**
- Investigated 10+ minute delay between pushing code and seeing updates on Pi
- Root cause: Browser caching `elm.js` without Cache-Control headers
- Fix: Added `Cache-Control: no-cache, no-store, must-revalidate` header to Rust server
- Added `set-header` feature to tower-http in Cargo.toml
- Future deployments should update within seconds

### Files Modified

- `frontend/src/Graph.elm` - Date range and Y-axis constants
- `backend/src/main.rs` - Added SetResponseHeaderLayer for cache control
- `backend/Cargo.toml` - Added set-header feature

---

## Session 7

**Date:** 2026-01-16

### Summary

Feature development session adding daily pay visualization, note annotations, and various fixes/polish.

### Key Changes

**Orange Daily Pay Indicator:**
- Added orange vertical bars showing pay earned each day (behind the blue "earned money" line)
- Properly accounts for Alaska overtime rules: daily (>8hrs) and weekly (>40hrs) at 1.5x rate
- Added tax withholding estimation (25% / 0.75 multiplier)
- Extracted `calculateDailyPay` function in `Calculations.elm` for DRY
- Added comprehensive overtime tests before refactoring

**Note Annotations:**
- Added ability to mark special events on the graph (e.g., bonuses)
- Note field now supports color encoding: `color:text` format (green/blue/red/yellow)
- Entry form has color radio buttons for note color selection
- Graph displays colored dot above blue line with 45° angled black text

**Graph Adjustments:**
- Y-axis range increased from 15k to 20k
- Orange pay indicators use sharp rectangles (not rounded)
- Added warning comment not to change graph dimensions

**Deployment/Infrastructure Fixes:**
- Fixed elm.js vs main.js confusion (Makefile copies to correct filename)
- Fixed `chromium-browser` → `chromium` in launch-kiosk.sh
- Set up SSH access to Pi (port 2222) for debugging
- Added Makefile principle to practices-and-principles.md

**Weather Display:**
- Changed format from separate fields to "low° - high°" format

### Files Modified

- `frontend/src/Graph.elm` - Orange pay segments, note annotations, Y-range
- `frontend/src/Main.elm` - Note color dropdown, weather format
- `frontend/src/Calculations.elm` - `calculateDailyPay` function with overtime
- `frontend/tests/CalculationsTest.elm` - Overtime tests, creditLimit field fix
- `pi-setup/launch-kiosk.sh` - chromium command fix
- `~/robot-config/practices-and-principles.md` - Added Makefile principle

### Principles Added

**Build Systems (Makefiles):** Every project should have a Makefile defining the canonical build/deploy process. Always use it—don't "wing it" with ad-hoc commands.

---

## Session 8

**Date:** 2026-01-28

### Summary

Major data model refactoring session introducing multi-job support, payCashed functionality, data migration, and x-axis redesign.

### Key Changes

**Multi-Job Support:**
- Split single `Entry` type into separate `BalanceSnapshot` and `WorkLog` types
- `BalanceSnapshot`: date, checking, creditAvailable, creditLimit, personalDebt, note
- `WorkLog`: date, jobId, hours, payRate, taxRate, payCashed
- Each job has its own work logs with independent pay rates and tax rates
- Overtime calculated per-job using Alaska rules (daily >8hrs, weekly >40hrs at 1.5x)
- Jobs managed via `Job` type with id/name, stored in `FinanceData.jobs`

**PayCashed Functionality:**
- Added `payCashed` boolean to WorkLog
- When any work log in the current week has `payCashed=true`, previous week's pay is excluded from incoming pay calculation
- Checkbox added to work log entry form

**Data Migration:**
- Created `migrate-data.sh` script to convert old Entry format to new FinanceData format
- Script is idempotent (safe to run multiple times)
- Successfully migrated Pi data (23 balance snapshots, 19 work logs)

**Color Picker UX Improvement:**
- Replaced note color radio buttons with single clickable dot
- Dot cycles through colors (none → green → blue → red → yellow → none) when clicked
- Only appears when note text is present

**X-Axis Redesign:**
- Start date fixed at Jan 4, 2026
- End date now dynamic: current day + 3 days
- Day labels split into two lines: weekday name (Mon) and day number (5)
- Three stacked sections below x-axis: weeks ("week of 1/5"), months (January), years (2026)
- Alternating background shades for visual distinction

**X-Axis Fixes:**
- Added SVG clipPath to prevent graph elements drawing outside plot area (left of Y axis)
- Added final tick mark at right edge of last day
- Increased marginBottom from 50 to 100 for stacked sections

**Pi Deployment:**
- Updated CLAUDE.md with Pi SSH info (IP: 216.152.181.254, port 2222, user: pi)
- Deploy watcher requires manual restart when not running

### Files Modified

- `backend/src/types.rs` - New BalanceSnapshot, WorkLog, Job, FinanceData types
- `backend/src/main.rs` - Separate endpoints for balance snapshots and work logs
- `frontend/src/Main.elm` - Split entry forms, payCashed checkbox, color picker UX
- `frontend/src/Calculations.elm` - Per-job overtime, payCashed logic
- `frontend/src/Graph.elm` - X-axis redesign, clipping, dynamic date range
- `frontend/src/Api/Types.elm` - Regenerated
- `migrate-data.sh` - New migration script
- `CLAUDE.md` - Pi SSH info

