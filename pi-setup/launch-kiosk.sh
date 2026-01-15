#!/bin/bash
# Launch Chromium in kiosk mode with minimal background noise

chromium --kiosk \
  --disable-background-networking \
  --disable-component-update \
  --disable-sync \
  --disable-translate \
  --no-first-run \
  http://localhost:3000
