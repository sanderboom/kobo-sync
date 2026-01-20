# Kobo Sync for BookLore

Sync reading sessions from your Kobo e-reader to BookLore.

## The Problem

Kobo tracks reading sessions in its `AnalyticsEvents` table, but this data gets **wiped every time the device syncs online**. This tool:

1. Installs a trigger to preserve the data
2. Extracts reading sessions (pairing OpenContent/LeaveContent events)
3. Syncs them to BookLore's `/api/v1/reading-sessions` endpoint

## Setup

```bash
bundle install
```

## First-Time Setup

### 1. Install the preservation trigger

Connect your Kobo and run:

```bash
rake kobo:install_trigger
```

This prevents the `AnalyticsEvents` table from being cleared on sync.

### 2. Configure BookLore connection

```bash
rake booklore:configure
```

Enter your BookLore URL, username, and password. Credentials are stored in `~/.kobo-sync/state.db`.

### 3. Install automatic sync (recommended)

```bash
rake automation:install
```

This installs a launchd agent that automatically syncs when you mount your Kobo. You'll get a macOS notification when sync completes.

## Usage

### Manual sync

```bash
rake sync:run
```

### Preview what will be synced

```bash
rake sync:preview
```

### Check sync statistics

```bash
rake sync:stats
```

## Automation

The automation uses macOS launchd to watch for Kobo mount events.

```bash
rake automation:install    # Install auto-sync on mount
rake automation:uninstall  # Remove auto-sync
rake automation:status     # Check if automation is running
rake automation:logs       # View sync logs
```

When installed, the workflow is simply:
1. Plug in your Kobo
2. Reading sessions sync automatically
3. You get a notification when done

## How Idempotency Works

- Local state stored in `~/.kobo-sync/state.db`
- Tracks which Kobo event IDs have been synced
- Re-running `sync:run` only sends new sessions
- Use `sync:reset` to clear the sync state if needed

## All Tasks

```
rake kobo:check            # Check if Kobo is mounted
rake kobo:install_trigger  # Install trigger to preserve AnalyticsEvents data
rake kobo:remove_trigger   # Remove the PreserveAnalyticsEvents trigger
rake kobo:schema           # Show AnalyticsEvents table schema
rake kobo:triggers         # Show installed triggers

rake booklore:configure    # Configure BookLore API connection
rake booklore:config       # Show current configuration

rake sync:preview          # Show reading sessions that would be synced (dry run)
rake sync:run              # Sync reading sessions to BookLore
rake sync:stats            # Show sync statistics
rake sync:reset            # Reset sync state (mark all sessions as not synced)

rake automation:install    # Install launchd agent to auto-sync when Kobo is mounted
rake automation:uninstall  # Uninstall the launchd agent
rake automation:status     # Check automation status
rake automation:logs       # Show automation logs
```

## Files

```
~/.kobo-sync/
├── state.db              # Sync state and credentials
├── sync.log              # Automation logs
└── sync-on-mount.sh      # Installed sync script

~/Library/LaunchAgents/
└── com.kobo-sync.plist   # launchd agent (when automation installed)
```

## Data Flow

```
Kobo AnalyticsEvents
    ↓
    OpenContent event (start reading)
    LeaveContent event (stop reading, has SecondsRead)
    ↓
Paired into reading session
    ↓
POST /api/v1/reading-sessions
    {
      bookId, bookType,
      startTime, endTime, durationSeconds,
      startProgress, endProgress, progressDelta,
      startLocation, endLocation
    }
```
