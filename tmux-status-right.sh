#!/bin/bash
# tmux-status-right.sh — Filtered status-right for first tmux line
# Strips rig LEDs from gt status-line (rigs shown on second line instead)
# Replaces "Mayor" with configured mayor name from ~/.gt-mayor-name

SESSION="${1:-hq-mayor}"
GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo /usr/local/bin/gt)}"
MAYOR_NAME=$(cat ~/.gt-mayor-name 2>/dev/null || echo "Mayor")

line=$("$GT_BIN" status-line --session="$SESSION" 2>/dev/null)

# Remove rig LEDs and replace "Mayor" with configured name
echo "$line" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
mayor_name = '$MAYOR_NAME'
# Replace 'Mayor' with configured name (keep the hat emoji)
line = line.replace('🎩 Mayor', '🎩 ' + mayor_name)
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
