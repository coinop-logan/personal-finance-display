# Personal Finance Display - Brainstorming

## End Goal

A dedicated Raspberry Pi in the bedroom connected to a screen, displaying a single full-screen graph of personal finances over time (day by day).

## Architecture

### Display Side (Raspberry Pi)
- The Pi should do ONE thing: load a hardcoded URL and display it full-screen
- Ideally avoid setting up a full X display server
- Need to research lightweight/headless browser options that can render to a screen without full desktop environment
- No mouse or keyboard intended - this is a dedicated display appliance

### Web Application
- A web page showing a financial graph
- **Open question: Elm or Lamdera?**
  - Pure Elm: simpler, just need static hosting
  - Lamdera: adds backend capabilities if we need them later
  - Decision deferred for now

### The Graph
- Day-by-day financial data visualization
- Custom-built rather than using a graphing library
- Likely SVG-based, drawn from scratch in Elm
- Will be built iteratively with specific requirements as we go

## Data Source Options

Two pathways being considered:

### Option A: Google Sheets (Manual Entry)
- Manager manually enters financial data into a Google Sheet
- Web page fetches data via Google Sheets API
- Simpler, more reliable
- Requires manual data entry

### Option B: Automated Bank Scraping
- Robot navigates to banking website
- Logs in with credentials, answers challenge questions
- Scrapes the actual balance/transaction data
- More complex to build and maintain
- Could use tools like Puppeteer or similar
- Worth exploring if feasible

Decision: TBD - will explore both options

## Open Questions

1. Elm vs Lamdera?
2. What exactly should the graph show? (net worth? spending? specific accounts?)

---

## Robot Research: Pi Kiosk Display Options

### The Bad News First
True framebuffer-only browsers (no X or Wayland at all) are essentially not viable for modern web content. Chromium and Firefox require a windowing system. The framebuffer gets "evicted" once any display server runs.

### Recommended Approach: Minimal X or Wayland Kiosk

**Option 1: Minimal X Server (Lighter, well-documented)**

Start with Raspberry Pi OS Lite (no desktop), then install only:
```
xserver-xorg-video-all xserver-xorg-input-all xserver-xorg-core xinit x11-xserver-utils chromium unclutter
```

Configure:
1. `sudo raspi-config` → Console Autologin
2. Add to `~/.bash_profile` to auto-start X only on physical console (not SSH)
3. Create `~/.xinitrc` to launch Chromium with `--kiosk --start-fullscreen`

This is minimal - no window manager, no desktop environment. Just X + browser.

**Option 2: Wayland with Cage (More modern)**

[Cage](https://github.com/cage-kiosk/cage) is a purpose-built Wayland kiosk compositor. It runs a single maximized application and nothing else. Lighter than a full Wayland desktop.

Run with: `cage chromium --kiosk --ozone-platform=wayland`

**Option 3: Wayfire (Default on Pi OS Bookworm)**

If using full Raspberry Pi OS, it now uses Wayland/Wayfire by default. Can configure autostart in `wayfire.ini` to launch Chromium in kiosk mode at boot.

### Pi Zero Caveat
Chromium no longer supports Pi Zero. Firefox ESR or the `surf` browser (from suckless.org, has `-K` kiosk mode) are alternatives for older/smaller Pi models.

### Chosen Approach: Full Raspberry Pi OS + Chromium Kiosk

Simplicity over minimalism. Use full Raspberry Pi OS with desktop:
1. Flash Raspberry Pi OS (full, with desktop)
2. Boot, connect via SSH or keyboard
3. Run: `chromium --kiosk <URL>`

No extra packages to install. Chromium and desktop already included.

The Pi will stay on continuously - no boot automation needed. Just start the kiosk once manually, leave it running.

### Sources
- [Minimal RPi Kiosk Guide](https://blog.r0b.io/post/minimal-rpi-kiosk/)
- [Cage - Wayland Kiosk](https://github.com/cage-kiosk/cage)
- [Wayfire Kiosk Discussion](https://forums.raspberrypi.com/viewtopic.php?t=363992)
- [Pi Forums - Lightweight Browsers](https://forums.raspberrypi.com/viewtopic.php?t=336486)
