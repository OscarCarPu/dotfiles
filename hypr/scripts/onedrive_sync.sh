#!/bin/bash
set -euo pipefail

LOG_FILE="$HOME/.cache/onedrive_sync.log"

# Verify onedrive is installed
if ! command -v onedrive &> /dev/null; then
    echo "Error: onedrive not found" >&2
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log sync start
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting OneDrive sync..." >> "$LOG_FILE"

# Run sync in background and log output
onedrive --synchronize >> "$LOG_FILE" 2>&1 &

echo "[$(date '+%Y-%m-%d %H:%M:%S')] OneDrive sync started in background" >> "$LOG_FILE"
