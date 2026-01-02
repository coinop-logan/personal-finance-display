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

# Make deploy script executable
chmod +x "$REPO_DIR/pi-setup/deploy.sh"

# Install systemd services
echo "Installing systemd services..."
sudo cp "$REPO_DIR/pi-setup/finance-display.service" /etc/systemd/system/
sudo cp "$REPO_DIR/pi-setup/finance-deploy-watcher.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable finance-display
sudo systemctl enable finance-deploy-watcher

# Start services
echo "Starting services..."
sudo systemctl start finance-display
sudo systemctl start finance-deploy-watcher

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Server running at http://localhost:3000"
echo "Deploy watcher checking for updates every 2 seconds"
echo ""
echo "To view graph on this Pi:"
echo "  chromium --kiosk http://localhost:3000"
echo ""
echo "To enter data from another device on your network:"
echo "  http://$(hostname -I | awk '{print $1}'):3000/entry"
echo ""
