#!/bin/bash
# Auto-deploy watcher for finance-display
# Checks for updates every 2 seconds

REPO_DIR="$HOME/finance-display"
INTERVAL=2

cd "$REPO_DIR" || exit 1

echo "Watching for updates every ${INTERVAL}s..."

while true; do
    # Fetch latest from origin
    git fetch origin master --quiet 2>/dev/null

    # Check if there are new commits
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/master 2>/dev/null)

    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - New changes detected, updating..."

        git pull origin master --quiet

        # Restart the server
        sudo systemctl restart finance-display

        echo "$(date '+%Y-%m-%d %H:%M:%S') - Update complete, service restarted"
    fi

    sleep $INTERVAL
done
