# Kobo Sync for Grimmory (formerly Booklore)

Sync reading sessions from your Kobo e-reader to your [Grimmory](https://github.com/grimmory-tools/grimmory) instance.

## The Problem

Kobo tracks reading sessions in its `AnalyticsEvents` table, but this data gets **wiped every time the device syncs online**.  
This tool:

1. Installs a trigger to preserve the data
2. Extracts reading sessions (pairing OpenContent/LeaveContent events)
3. Syncs them to Grimmory's `/api/v1/reading-sessions` endpoint

## Setup

```bash
bundle install
```

## First time setup

### 1. Analytics must be enabled on the Kobo

The `PrivacyPermissions` field in the user-table of the Kobo database (at `.kobo/KoboReader.sqlite`) must be populated — if it's empty, no reading events will be recorded.

It's a bit unclear what exactly causes the analytics tracking to not be enabled, but after several reset-setup-flows the following worked:

1. Visit https://www.kobo.com/ and _be sure to accept all cookies_  
2. Create an account  
  Be sure to pick the country where you'd want to buy content from. This can differ from the country the site detects.
1. Reset the Kobo  
  This starts the activation flow. It can be done by signing out (`More > Settings > Accounts`).  
  NOTE: notes and bookmarks are lost.
1. Activate  
  You'll be asked to connect wifi. Then you'll be shown a page with a QR-code and activation code.  
  Visit https://kobo.com/activate and fill out the activation code. This ties the device to the online account.
1. Connect your Kobo to your computer  
  Confirm connecting on the device.
1. Verify analytics are enabled  
  The following installs a trigger to prevent the `AnalyticsEvents` table from being cleared on sync, and verifies that analytics tracking is enabled on the device.
   ```bash
   rake kobo:setup
   ```

### 2. Config the api endpoint on the Kobo

This is how you receive your books from your Grimmory instance - it's not strictly necessary for syncing the analytics data.  
NOTE: Setting this doesn't prevent you from buying books from the official Kobo store (or using Kobo plus).

1. Grimmory: Grab your Kobo sync token  
  On your Grimmory instance: Visit `Settings > Devices`, ensure `Enable Kobo Sync` is enabled and copy the token.
1. Kobo: Set the api_endpoint  
  In `.kobo/Kobo/Kobo eReader.conf`, set `api_endpoint=https://grimmory-instance.org/api/kobo/<token>`.  
  On OSX:
    ```bash
    $EDITOR /Volumes/KOBOeReader/.kobo/Kobo/Kobo\ eReader.conf
    ```

### 3. Configure BookLore connection

```bash
rake grimmory:configure
```

Enter your Grimmory URL, username, and password. Credentials are stored in `~/.kobo-sync/state.db`.

### 4. Install automatic sync (recommended)

```bash
rake automation:install
```

This installs a launchd agent that automatically syncs when you mount your Kobo. You'll get a macOS notification when sync completes.  
See Usage below for manual sync.

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
rake kobo:setup            # Set up Kobo for syncing (install trigger, check analytics)
rake kobo:install_trigger  # Install trigger to preserve AnalyticsEvents data
rake kobo:remove_trigger   # Remove the PreserveAnalyticsEvents trigger
rake kobo:schema           # Show AnalyticsEvents table schema
rake kobo:triggers         # Show installed triggers

rake grimmory:configure    # Configure Grimmory API connection
rake grimmory:config       # Show current configuration

rake sync:preview          # Show reading sessions that would be synced (dry run)
rake sync:run              # Sync reading sessions to Grimmory
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
