#!/bin/bash
# Auto-deploy script for finance-display
# This script is run by cron on the Pi to check for updates

REPO_DIR="$HOME/finance-display"

cd "$REPO_DIR" || exit 1

# Fetch latest from origin
git fetch origin main --quiet 2>/dev/null

# Check if there are new commits
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null)

if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - New changes detected, updating..."

    git pull origin main --quiet

    # Restart the service
    sudo systemctl restart finance-display

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Update complete, service restarted"
fi
