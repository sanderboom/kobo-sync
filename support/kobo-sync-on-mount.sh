#!/bin/bash
# Runs kobo sync when Kobo is mounted
# Called by launchd when /Volumes/KOBOeReader changes (mount or unmount)

KOBO_SYNC_DIR="{{KOBO_SYNC_DIR}}"
KOBO_DB="/Volumes/KOBOeReader/.kobo/KoboReader.sqlite"
LOG_FILE="$HOME/.kobo-sync/sync.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date): Script triggered" >> "$LOG_FILE"

# Wait for Kobo to be fully mounted (up to 10 seconds)
TIMEOUT=10
WAITED=0
while [[ ! -f "$KOBO_DB" ]] && [[ $WAITED -lt $TIMEOUT ]]; do
  sleep 1
  WAITED=$((WAITED + 1))
done

# Only proceed if Kobo is actually mounted
if [[ ! -f "$KOBO_DB" ]]; then
  echo "$(date): Kobo DB not found after ${WAITED}s, exiting (unmount or timeout)" >> "$LOG_FILE"
  exit 0
fi

echo "$(date): Kobo DB found after ${WAITED}s, starting sync..." >> "$LOG_FILE"

# Source shell profile to get mise/rbenv/etc
export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

cd "$KOBO_SYNC_DIR"

# Use mise exec if available, otherwise try direct bundle
if command -v mise &> /dev/null; then
  BUNDLE_CMD="mise exec -- bundle"
else
  BUNDLE_CMD="bundle"
fi

# Heal missing gems (e.g. after a Ruby version bump wipes native extensions)
if ! $BUNDLE_CMD check >> "$LOG_FILE" 2>&1; then
  echo "$(date): Gems missing, running bundle install..." >> "$LOG_FILE"
  $BUNDLE_CMD install >> "$LOG_FILE" 2>&1
fi

if $BUNDLE_CMD exec rake sync:run >> "$LOG_FILE" 2>&1; then
  osascript -e 'display notification "Reading sessions synced to BookLore" with title "Kobo Sync"' 2>/dev/null || true
  echo "$(date): Sync completed successfully" >> "$LOG_FILE"
else
  osascript -e 'display notification "Sync failed - check ~/.kobo-sync/sync.log" with title "Kobo Sync" sound name "Basso"' 2>/dev/null || true
  echo "$(date): Sync failed" >> "$LOG_FILE"
fi
