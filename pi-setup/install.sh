#!/bin/bash
# One-time setup script for the Pi
# Run this after cloning the repo

set -e

echo "=== Finance Display Setup ==="

REPO_DIR="$HOME/finance-display"

# Python3 should already be on Pi OS, just verify
if ! command -v python3 &> /dev/null; then
    echo "Error: Python3 not found. Installing..."
    sudo apt-get update && sudo apt-get install -y python3
fi

echo "Python version: $(python3 --version)"

# Install systemd service
echo "Installing systemd service..."
sudo cp "$REPO_DIR/pi-setup/finance-display.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable finance-display

# Set up cron for auto-deploy (every 5 minutes)
echo "Setting up auto-deploy cron..."
CRON_CMD="*/5 * * * * $REPO_DIR/pi-setup/deploy.sh >> $HOME/finance-deploy.log 2>&1"
(crontab -l 2>/dev/null | grep -v "deploy.sh"; echo "$CRON_CMD") | crontab -

# Make deploy script executable
chmod +x "$REPO_DIR/pi-setup/deploy.sh"

# Start the service
echo "Starting service..."
sudo systemctl start finance-display

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Server running at http://localhost:3000"
echo ""
echo "To view graph on this Pi:"
echo "  chromium --kiosk http://localhost:3000"
echo ""
echo "To enter data from another device on your network:"
echo "  http://$(hostname -I | awk '{print $1}'):3000/entry"
echo ""
