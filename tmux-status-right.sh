#!/bin/bash
# tmux-status-right.sh — Filtered status-right for first tmux line
# Strips rig LEDs from gt status-line (rigs shown on second line instead)

SESSION="${1:-hq-mayor}"
GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo /usr/local/bin/gt)}"

line=$("$GT_BIN" status-line --session="$SESSION" 2>/dev/null)

# Remove rig section: " | 🟢 listen 🟢 livemd | ⚫ gthelper |" etc.
# Pattern: everything after the first " | " that contains rig status icons up to the trailing " |"
# Keep: "2/2 🦉 2/2 🏭" and any hooked work / mail after rigs
echo "$line" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
# Split on ' | '
parts = [p.strip() for p in line.split(' | ') if p.strip()]
# Keep parts that don't look like rig LEDs (contain 🟢🟡⚫🔨🅿️ followed by rig name)
rig_icons = {'🟢','🟡','⚫','🔨','🅿️','🛑'}
filtered = []
for p in parts:
    tokens = p.split()
    if tokens and tokens[0] in rig_icons:
        continue  # skip rig LED entries
    filtered.append(p)
print(' | '.join(filtered) + (' |' if filtered else ''))
"
