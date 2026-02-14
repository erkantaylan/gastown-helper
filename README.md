# Gas Town Helper

Helper scripts and tools for [Gas Town](https://github.com/steveyegge/gastown).

## Features

### Claude Usage Tracking

**Inspired by [claude-counter](https://github.com/she-llac/claude-counter) by [@she-llac](https://github.com/she-llac)**

Display Claude usage metrics in your Gas Town tmux status bar.

```
🟢abp 🔨listen          🤖 5h:45% 7d:12% | 6333msg 21k↑60k↓
└─ rigs (left)          └─ claude usage (right)
```

#### Quick Start

```bash
bash install-claude-usage.sh
```

#### Documentation

See [CLAUDE_USAGE_TRACKING.md](CLAUDE_USAGE_TRACKING.md) for:
- Complete installation guide
- How it works (architecture comparison with original)
- Configuration options
- Troubleshooting
- Full credits to original project

#### Credits

Original project: [claude-counter](https://github.com/she-llac/claude-counter) by [@she-llac](https://github.com/she-llac)

This implementation adapts the browser userscript's functionality for Claude Code CLI + Gas Town tmux.

## Installation

Each feature has its own installer. See individual documentation for details.

## License

Individual components may have different licenses. See documentation for each feature.

Claude usage tracking is inspired by claude-counter (MIT License).
