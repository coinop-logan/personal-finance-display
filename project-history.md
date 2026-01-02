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
