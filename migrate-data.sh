#!/bin/bash
# Migration script: converts old data.json (list of Entry) to new format (FinanceData)
# Run this on the Pi after pulling the multi-job-support branch
#
# Usage: ./migrate-data.sh [data_file]
#   data_file defaults to data.json in current directory

set -e

DATA_FILE="${1:-data.json}"
BACKUP_FILE="${DATA_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$DATA_FILE" ]; then
    echo "Data file not found: $DATA_FILE"
    echo "If this is a fresh install, no migration needed."
    exit 0
fi

# Check if already migrated (new format has "jobs" at top level)
if grep -q '"jobs"' "$DATA_FILE" 2>/dev/null; then
    echo "Data appears to already be in new format (found 'jobs' key)."
    echo "No migration needed."
    exit 0
fi

echo "Backing up $DATA_FILE to $BACKUP_FILE"
cp "$DATA_FILE" "$BACKUP_FILE"

echo "Migrating data..."

# Use Python for the migration since jq isn't always available
python3 << 'PYTHON_SCRIPT'
import json
import sys

data_file = sys.argv[1] if len(sys.argv) > 1 else "data.json"

with open(data_file, 'r') as f:
    old_entries = json.load(f)

if not isinstance(old_entries, list):
    print("Data is not in old format (expected a list of entries)")
    sys.exit(1)

# Convert to new format
work_logs = []
balance_snapshots = []
work_log_id = 1
snapshot_id = 1

for entry in old_entries:
    # Create balance snapshot for every entry
    snapshot = {
        "id": snapshot_id,
        "date": entry["date"],
        "checking": entry.get("checking", 0),
        "creditAvailable": entry.get("creditAvailable", 0),
        "creditLimit": entry.get("creditLimit", 0),
        "personalDebt": entry.get("personalDebt", 0),
        "note": entry.get("note", "")
    }
    balance_snapshots.append(snapshot)
    snapshot_id += 1

    # Create work log only if hours > 0
    hours = entry.get("hoursWorked", 0)
    if hours > 0:
        work_log = {
            "id": work_log_id,
            "date": entry["date"],
            "jobId": "alborn",  # Default to alborn for old data
            "hours": hours,
            "payRate": entry.get("payPerHour", 0),
            "taxRate": 0.25,  # Default tax rate
            "payCashed": entry.get("payCashed", False)
        }
        work_logs.append(work_log)
        work_log_id += 1

# Build new structure
new_data = {
    "jobs": [
        {"id": "alborn", "name": "Alborn"},
        {"id": "museum", "name": "Museum"}
    ],
    "workLogs": work_logs,
    "balanceSnapshots": balance_snapshots
}

with open(data_file, 'w') as f:
    json.dump(new_data, f, indent=2)

print(f"Migration complete!")
print(f"  - {len(balance_snapshots)} balance snapshots created")
print(f"  - {len(work_logs)} work logs created (entries with hours > 0)")
PYTHON_SCRIPT

echo "Migration successful!"
echo "Backup saved to: $BACKUP_FILE"
