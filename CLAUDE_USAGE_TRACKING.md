# Claude Usage Tracking for Gas Town Tmux

Display Claude usage metrics in your Gas Town tmux status bar - inspired by [claude-counter](https://github.com/she-llac/claude-counter).

## Credits

**Original Project:** [claude-counter](https://github.com/she-llac/claude-counter) by [@she-llac](https://github.com/she-llac)

This implementation adapts the browser userscript's functionality for Claude Code CLI + Gas Town's tmux environment. The original project displays Claude usage on the claude.ai web interface; this brings similar functionality to your terminal.

## What It Does

Adds Claude usage information to your tmux second status bar (bottom right):

```
🟢abp 🔨listen          🤖 5h:45% 7d:12% | 6333msg 21k↑60k↓
└─ rigs (left)          └─ claude usage (right)
```

### Display Elements

| Element | Source | Description |
|---------|--------|-------------|
| `5h:45%` | Claude.ai API | 5-hour usage limit percentage |
| `7d:12%` | Claude.ai API | 7-day usage limit percentage |
| `6333msg` | Local stats | Total messages sent today |
| `21k↑` | Local stats | Input tokens (thousands) |
| `60k↓` | Local stats | Output tokens (thousands) |

### Color Indicators

When API data is available:
- 🟢 Green - Usage < 50%
- 🟡 Yellow - Usage 50-80%
- 🔴 Red - Usage > 80%

## How It Works

### Architecture Comparison with Original

| Component | claude-counter (Browser) | This Implementation (CLI) |
|-----------|-------------------------|---------------------------|
| **Platform** | Browser userscript on claude.ai | Bash script in tmux |
| **Data Source** | Intercepts SSE streams | Calls same REST API endpoints |
| **API Endpoint** | `GET /api/organizations/{orgId}/usage` | Same endpoint |
| **Authentication** | Browser cookies (`sessionKey`) | OAuth from `~/.claude/.credentials.json` |
| **Display** | Overlay on web page | tmux status bar (second line, right side) |
| **Update Frequency** | Real-time during conversations | Every 5 seconds (tmux refresh interval) |
| **Caching** | Browser memory | File-based (5-minute TTL) |
| **Scope** | Per-conversation statistics | Daily aggregate statistics |

### Data Sources

1. **Local Statistics** (Real-time)
   - Source: `~/.claude/stats-cache.json`
   - Provides: Message counts, token usage per model
   - Updates: Continuously by Claude Code

2. **Web API Limits** (Cached 5 minutes)
   - Source: `https://claude.ai/api/organizations/{orgId}/usage`
   - Provides: 5-hour and 7-day usage percentages
   - Authentication: OAuth token from `~/.claude/.credentials.json`
   - Updates: Background fetch every 5 minutes

### Technical Implementation

```
┌─────────────────────────────────────────┐
│   tmux status bar (refreshes every 5s)  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│     claude-usage.sh (bash script)        │
│  ┌─────────────┬────────────────────┐   │
│  │ Local Stats │   Web API (cached) │   │
│  │  ~/.claude/ │  claude.ai/api/... │   │
│  │             │  (5min cache TTL)  │   │
│  └─────────────┴────────────────────┘   │
└─────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Second tmux status bar (status-format[1])│
│  [rigs on left] [claude usage on right] │
└─────────────────────────────────────────┘
```

## Installation

### Prerequisites

- Gas Town installed with tmux configuration
- Claude Code authenticated (for API access)
- `~/.claude/.credentials.json` exists (run `claude auth login` if not)

### Quick Install

```bash
cd /path/to/gthelper
bash install-claude-usage.sh
```

This will:
1. Copy `claude-usage.sh` to your `mayor/rig/` directory
2. Update your tmux second status bar configuration
3. Make the script executable
4. Verify the setup

### Manual Installation

If you prefer manual setup:

#### 1. Copy the Script

```bash
# Copy to your Gas Town mayor/rig directory
cp claude-usage.sh ~/.../mayor/rig/claude-usage.sh
chmod +x ~/.../mayor/rig/claude-usage.sh
```

#### 2. Update Tmux Configuration

Add to your tmux second status bar (status-format[1]):

```bash
# Get the full path to the script
SCRIPT_PATH="/full/path/to/mayor/rig/claude-usage.sh"

# Update tmux second status bar to add Claude usage on the right
tmux set-option -g 'status-format[1]' \
  "#[fill=colour232,align=left,bg=colour232,fg=colour245]#(/path/to/tmux-rig-status.sh)#[align=right,fg=colour245]#($SCRIPT_PATH)"
```

#### 3. Reload Tmux

```bash
tmux source-file ~/.config/tmux/tmux.conf
# Or just restart tmux
```

#### 4. Verify Installation

The second status bar should now show Claude usage on the right side:

```bash
# Test the script directly
bash /path/to/claude-usage.sh
# Should output: 🤖 XXXmsg XXk↑XXk↓
```

## Configuration

### Change API Cache Duration

Edit `claude-usage.sh` and modify:

```bash
CACHE_TTL=300  # 5 minutes (default)
CACHE_TTL=60   # 1 minute (more frequent API calls)
CACHE_TTL=900  # 15 minutes (less frequent)
```

**Note:** Lower values may hit rate limits. 5 minutes is recommended.

### Customize Display Format

Edit the `format_output()` function in `claude-usage.sh`:

```bash
# Example: Change emoji or format
parts.append(f'📊{$messages}msg')  # Different emoji
parts.append(f'{five_pct}%')       # Remove "5h:" prefix
```

### Position in Status Bar

#### Right side of second bar (current):
```bash
tmux set-option -g 'status-format[1]' \
  "...[rigs]#[align=right]#(claude-usage.sh)"
```

#### Left side of second bar:
```bash
tmux set-option -g 'status-format[1]' \
  "#[align=left]#(claude-usage.sh) [rigs]..."
```

#### First status bar instead:
```bash
tmux set-option -g status-right \
  "#(claude-usage.sh) %H:%M %d %b"
```

## Troubleshooting

### No API data (only shows local stats)

**Symptom:** Only see `🤖 XXXmsg XXk↑XXk↓`, no 5h/7d percentages

**Causes:**
1. First run (cache building in background) - wait 5 minutes
2. Not authenticated with Claude Code
3. No internet connection
4. API rate limited

**Fix:**
```bash
# Check credentials exist
ls -l ~/.claude/.credentials.json

# Re-authenticate if needed
claude auth login

# Check if cache file is being created
ls -l ~/.claude/usage-cache.json

# View cache content
cat ~/.claude/usage-cache.json
```

### Script shows errors

**Fix line endings** (if copied from Windows):
```bash
sed -i 's/\r$//' /path/to/claude-usage.sh
```

**Check execute permission:**
```bash
chmod +x /path/to/claude-usage.sh
```

### Status bar not updating

**Check tmux refresh interval:**
```bash
tmux show-option -g status-interval
# Should be 5 or less for responsive updates
```

**Manually trigger:**
```bash
tmux refresh-client
```

### Cache file issues

**Location:** `~/.claude/usage-cache.json`

**Clear cache to force refresh:**
```bash
rm ~/.claude/usage-cache.json
```

**Check cache age:**
```bash
stat ~/.claude/usage-cache.json
```

## What Gets Tracked

### Local Statistics (from Claude Code)

Source: `~/.claude/stats-cache.json`

```json
{
  "dailyActivity": [{
    "date": "2026-02-14",
    "messageCount": 6333,
    "sessionCount": 23
  }],
  "modelUsage": {
    "claude-sonnet-4-5-20250929": {
      "inputTokens": 21013,
      "outputTokens": 47599,
      "cacheReadInputTokens": 161254151,
      "cacheCreationInputTokens": 4968721
    }
  }
}
```

### API Limits (from Claude.ai)

Source: `https://claude.ai/api/organizations/{orgId}/usage`

```json
{
  "five_hour": {
    "utilization": 0.45,
    "resets_at": "2026-02-14T21:30:00Z"
  },
  "seven_day": {
    "utilization": 0.12,
    "resets_at": "2026-02-21T14:00:00Z"
  }
}
```

## Privacy & Security

### What Data is Accessed

- **Local:** Read-only access to `~/.claude/stats-cache.json`
- **Remote:** Calls Claude.ai API using your OAuth token
- **No External Services:** All processing is local

### Authentication

Uses OAuth token from `~/.claude/.credentials.json`:

```bash
# The script reads:
oauth_data=$(cat "$CREDENTIALS_FILE" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
oauth = data.get('claudeAiOauth', {})
print(oauth.get('sessionKey', ''))
print(oauth.get('orgId', ''))
")
```

This is the same authentication Claude Code uses - no additional login required.

### Data Storage

- **Cache file:** `~/.claude/usage-cache.json` (5-minute TTL)
- **Permissions:** Read-only access, no modifications to Claude Code state

## Uninstallation

### Remove from Tmux

```bash
# Restore original second status bar (just rigs)
tmux set-option -g 'status-format[1]' \
  "#[fill=colour232,align=left,bg=colour232,fg=colour245]#(/path/to/tmux-rig-status.sh)"
```

### Delete Files

```bash
rm /path/to/mayor/rig/claude-usage.sh
rm ~/.claude/usage-cache.json  # Optional: remove cache
```

## Differences from Original claude-counter

### What's the Same

- ✅ Uses same API endpoint (`/api/organizations/{orgId}/usage`)
- ✅ Shows 5-hour and 7-day usage limits
- ✅ Displays token counts and message statistics
- ✅ Color-coded usage indicators
- ✅ Similar authentication approach (session tokens)

### What's Different

| Aspect | claude-counter | This Implementation |
|--------|----------------|---------------------|
| **Platform** | Browser (userscript/extension) | CLI (bash + tmux) |
| **Data Capture** | Intercepts SSE streams | Calls REST API + reads local stats |
| **Real-time Updates** | During active chat | Every 5 seconds (tmux refresh) |
| **Scope** | Per-conversation stats | Daily aggregate stats |
| **Display** | Web page overlay | Terminal status bar |
| **Installation** | Browser extension manager | Shell script |
| **Dependencies** | Browser, Tampermonkey/Violentmonkey | Bash, Python 3, tmux |

### Why the Differences

1. **SSE vs REST API:** Browser can intercept streams; CLI polls API endpoint
2. **Conversation vs Daily:** Browser tracks active conversation; CLI shows overall daily usage
3. **Update Frequency:** Browser gets instant updates; tmux updates every 5s (configurable)

Both approaches provide valuable insights - use the browser extension when chatting on claude.ai, and this implementation when using Claude Code.

## Credits & License

### Original Project

**claude-counter** by [@she-llac](https://github.com/she-llac)
- Repository: https://github.com/she-llac/claude-counter
- License: MIT
- Description: Browser userscript/extension showing Claude usage on claude.ai

This implementation is inspired by and adapted from the original project, bringing similar functionality to Claude Code's CLI environment.

### What We Kept from Original

- API endpoint usage (`/api/organizations/{orgId}/usage`)
- Authentication approach (session/OAuth tokens)
- Data structure interpretation (5h/7d utilization)
- Display format concept (percentages + token counts)

### What We Added

- Integration with Claude Code's local stats
- Tmux status bar rendering
- File-based caching for API responses
- Gas Town-specific positioning (second status bar)

### Thank You

Special thanks to [@she-llac](https://github.com/she-llac) for creating the original claude-counter project and documenting the Claude.ai API endpoints. This adaptation wouldn't exist without that excellent work!

## Support & Contributing

### Issues

If you encounter problems:
1. Check the [Troubleshooting](#troubleshooting) section
2. Verify your Claude Code installation and authentication
3. Test the script directly: `bash claude-usage.sh`

### Improvements

This is a simple bash script - feel free to enhance it:
- Add more metrics from `stats-cache.json`
- Improve error handling
- Add configuration file support
- Create systemd service for background updates

### Upstream

For issues with the Claude.ai API or usage limits, refer to:
- [claude-counter repository](https://github.com/she-llac/claude-counter) - Original browser implementation
- [Claude Code documentation](https://docs.anthropic.com/claude/docs) - Official Claude Code docs

## See Also

- [Gas Town Documentation](https://github.com/steveyegge/gastown)
- [claude-counter Browser Extension](https://github.com/she-llac/claude-counter)
- [tmux Documentation](https://github.com/tmux/tmux/wiki)

---

**Version:** 1.0
**Last Updated:** 2026-02-14
**Maintainer:** Gas Town community
**Original Inspiration:** [@she-llac/claude-counter](https://github.com/she-llac/claude-counter)
