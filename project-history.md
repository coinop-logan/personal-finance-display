# Personal Finance Display - Project History

---

## Session 1

**Date:** 2025-12-13

### Project Created

New project to display personal finance data on a dedicated Raspberry Pi screen in the bedroom.

### Decisions Made

**Hardware & Display:**
- Raspberry Pi 4 (micro HDMI adapter acquired)
- Full Raspberry Pi OS with desktop (simplicity over minimalism)
- Chromium in `--kiosk` mode for true full-screen display (no title bars)
- No boot automation needed - Pi stays on, start kiosk manually once

**Web Application:**
- Elm-based (Elm vs Lamdera still TBD - depends on data source)
- Custom-built graph, not using a graphing library
- Rendering method TBD (possibly SVG, possibly other)
- Graph content: Manager has clear vision, will specify when basics are settled

**Data Source Architecture:**
- Cloud-based scraping approach chosen over local Pi scraping
- GitHub Actions (free tier) runs scraper on hourly schedule
- Scraper outputs to publicly accessible JSON file
- Elm app fetches JSON via simple HTTP GET
- Public data is acceptable (no auth needed for fetching)

### Research Completed

**Pi Kiosk Options:**
- Explored minimal X, Cage/Wayland, full desktop
- Chose full Pi OS for simplicity of setup
- Confirmed `chromium --kiosk <URL>` provides true full-screen

**Pi 4 Hardware:**
- Uses micro HDMI (Type D), not standard HDMI
- Need "micro HDMI to HDMI" adapter

**Bank Scraping Tools (Rust):**
- `chromiumoxide` - async, tokio-based, actively maintained
- `headless_chrome` - Puppeteer equivalent for Rust
- Playwright/Puppeteer cannot run from browser context (Node.js only)

**Scraping Challenges Identified:**
- Security questions: Solvable with stored Q&A pairs
- 2FA: TOTP doable if we have secret; SMS/email harder
- Bot detection: Banks may block; stealth plugins help
- Maintenance: Script breaks when bank updates UI

### Files Created

- `brainstorming.md` - Initial ideas and research notes
- `project-plan.md` - Decisions, open questions, and project phases
- `scraper/` - Rust project with chromiumoxide, compiles successfully

### Current State

- Rust scraper prototype compiles but not yet tested against actual bank
- Awaiting bank URL to test scraping feasibility
- Pi OS flashing to SD card (in progress at session end)

### Next Steps

1. Test Rust scraper against actual bank login page
2. Set up GitHub Actions workflow for scheduled scraping
3. Create Elm app with basic graph and hardcoded test data
4. Connect Pi to display and test kiosk mode
