#!/bin/bash
# Runs kobo sync when Kobo is mounted
# Called by launchd when /Volumes/KOBOeReader changes (mount or unmount)

KOBO_SYNC_DIR="{{KOBO_SYNC_DIR}}"
KOBO_DB="/Volumes/KOBOeReader/.kobo/KoboReader.sqlite"
LOG_FILE="$HOME/.kobo-sync/sync.log"

# Only proceed if Kobo is actually mounted
if [[ ! -f "$KOBO_DB" ]]; then
  exit 0
fi

# Source shell profile to get mise/rbenv/etc
export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

cd "$KOBO_SYNC_DIR"

echo "$(date): Kobo mounted, starting sync..." >> "$LOG_FILE"

# Use mise exec if available, otherwise try direct bundle
if command -v mise &> /dev/null; then
  BUNDLE_CMD="mise exec -- bundle"
else
  BUNDLE_CMD="bundle"
fi

if $BUNDLE_CMD exec rake sync:run >> "$LOG_FILE" 2>&1; then
  osascript -e 'display notification "Reading sessions synced to BookLore" with title "Kobo Sync"' 2>/dev/null || true
  echo "$(date): Sync completed successfully" >> "$LOG_FILE"
else
  osascript -e 'display notification "Sync failed - check ~/.kobo-sync/sync.log" with title "Kobo Sync" sound name "Basso"' 2>/dev/null || true
  echo "$(date): Sync failed" >> "$LOG_FILE"
fi
