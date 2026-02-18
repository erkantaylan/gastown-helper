#!/bin/bash
# claude-statusline.sh — Claude Code status line for Gas Town Mayor
# Shows: mayor name, agent counts, hooked work, mail (NO rig LEDs)

MAYOR_NAME=$(cat ~/.gt-mayor-name 2>/dev/null || echo "Mayor")
GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo gt)}"

# Get raw status line
line=$("$GT_BIN" status-line --session=hq-mayor 2>/dev/null)

# Filter out rig LEDs using python3
filtered=$(echo "$line" | python3 -c "
import sys
line = sys.stdin.read().strip()

# Split on ' | '
parts = [p.strip() for p in line.split(' | ') if p.strip()]

# Icons that indicate rig status (filter these out)
rig_icons = {'🟢','🟡','⚫','🔨','🅿️','🛑'}

filtered = []
for p in parts:
    tokens = p.split()
    if tokens and tokens[0] in rig_icons:
        continue  # Skip rig LED entries
    filtered.append(p)

result = ' | '.join(filtered)
# Clean up trailing pipe
result = result.rstrip(' |').rstrip()
print(result)
" 2>/dev/null)

# Output: mayor hat + name + filtered status
if [ -n "$filtered" ]; then
    echo "🎩 $MAYOR_NAME $filtered"
else
    echo "🎩 $MAYOR_NAME"
fi
