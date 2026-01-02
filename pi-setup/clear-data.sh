#!/bin/bash
# Clear all finance data on the Pi
# Run this when the data format has changed and old data is incompatible

DATA_FILE="$HOME/finance-display/data.json"

if [ -f "$DATA_FILE" ]; then
    echo "Removing $DATA_FILE..."
    rm "$DATA_FILE"
    echo "Data cleared. Restarting server..."
    sudo systemctl restart finance-display
    echo "Done."
else
    echo "No data file found at $DATA_FILE"
fi
