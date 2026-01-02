# Personal Finance Display - Project Plan

## What's Been Decided

1. **Hardware**: Raspberry Pi 4 (micro HDMI adapter acquired)
2. **OS**: Full Raspberry Pi OS with desktop (currently flashing)
3. **Display method**: Chromium in `--kiosk` mode, full screen, no title bars
4. **Boot automation**: Not needed - Pi stays on, start kiosk manually once
5. **Graph**: Custom-built iteratively in Elm (rendering method TBD - possibly SVG, possibly other)
6. **Web tech**: Elm-based (Elm vs Lamdera still TBD)
7. **Graph content**: Manager has clear vision, will specify when basics are settled

## Unresolved Questions (Need Decisions)

1. **Elm or Lamdera?**
   - Pure Elm: Simpler, static hosting only, data fetched client-side
   - Lamdera: Has backend, could store data, handle scheduled fetches
   - *Depends on data source decision* - scraping likely needs a backend

2. **Data source: Google Sheets or Bank Scraping?**
   - Currently exploring bank scraping feasibility (see research below)

## Project Phases

### Phase 1: Basic Web App
- Set up Elm (or Lamdera) project
- Create a simple graph with hardcoded test data
- Deploy somewhere accessible (e.g., Lamdera hosting or static host)

### Phase 2: Pi Setup
- Flash Raspberry Pi OS to SD card
- Connect Pi 4 to display (with micro HDMI adapter)
- Test `chromium --kiosk <URL>` with the deployed page

### Phase 3: Real Data
- Implement chosen data source (Sheets API or scraping)
- Connect graph to live data
- Set up refresh mechanism

### Phase 4: Polish
- Graph styling and layout refinements
- Handle edge cases (no data, errors, etc.)
- Any Pi-side tweaks (screen timeout, etc.)

---

## Robot Research: Bank Scraping Options

### Tool Comparison

**Playwright** (recommended over Puppeteer)
- Modern, well-maintained by Microsoft
- Better cross-browser support
- Good documentation for auth flows
- Has stealth plugins to avoid bot detection

**Puppeteer**
- Original tool, Node.js based
- Large community, many examples
- Someone has documented [automating personal finance with Puppeteer](https://jdc-cunningham.medium.com/automating-my-finances-with-puppeteer-47bf2563fec0) including bank logins

### How It Would Work

1. Script launches headless browser
2. Navigates to bank login page
3. Enters username/password
4. Handles security challenge questions (pre-stored answers)
5. Handles 2FA if present (options below)
6. Navigates to account page
7. Scrapes balance data from DOM
8. Outputs to file/API

### Handling Security Questions

Security questions (like "What's your mother's maiden name?") are answerable - we'd store the Q&A pairs and match/respond automatically.

### Handling 2FA

This is trickier. Options:
- **TOTP (authenticator app)**: Can be automated if you have the secret key - use a library like `otplib` to generate codes
- **SMS codes**: Harder - would need Twilio or similar to receive SMS programmatically
- **Email codes**: Could potentially scrape email too, but adds complexity
- **Session persistence**: Log in once manually, save cookies/session, reuse until they expire

### Challenges

1. **Bot detection**: Banks often detect automation. Stealth plugins help but aren't foolproof
2. **Site changes**: If bank updates their UI, script breaks
3. **Terms of Service**: Most banks prohibit automated access - legal grey area for personal use
4. **Maintenance burden**: Ongoing work to keep it running

### Alternative: Aggregation APIs

Services like **Plaid**, **Yodlee**, **MX** handle bank connections professionally:
- They maintain integrations with thousands of banks
- Handle auth, security questions, 2FA
- Provide clean API for balance/transaction data
- **Downside**: Cost money, require approval, may not support your specific bank

### My Assessment

Bank scraping is *doable* for personal use but expect:
- Initial setup: Several hours to get working
- Ongoing maintenance: Script will break periodically
- Challenge questions: Solvable
- 2FA: Depends on your bank's method - TOTP is easiest

**If your bank uses simple password + security questions**: Very feasible
**If your bank uses SMS/email 2FA**: More complex but possible
**If your bank has aggressive bot detection**: May be frustrating

### Sources
- [Playwright 2FA guide](https://playwrightsolutions.com/playwright-login-test-with-2-factor-authentication-2fa-enabled/)
- [Scraping behind login with Playwright](https://www.checklyhq.com/learn/playwright/scraping-behind-login/)
- [Login automation with Puppeteer](https://automize.dev/whwk7svci5y/)
- [Plaid alternatives comparison](https://www.yapily.com/blog/plaid-alternatives)
