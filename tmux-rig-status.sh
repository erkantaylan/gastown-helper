#!/bin/bash
# tmux-rig-status.sh — Second tmux status line showing rig overview
# Used as: tmux status-format[1] '#(path/to/tmux-rig-status.sh)'

GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo /usr/local/bin/gt)}"
export NO_COLOR=1

json=$("$GT_BIN" status --json 2>/dev/null)
if [ -z "$json" ]; then
    echo "gt: offline"
    exit 0
fi

# Parse rigs from JSON using python3 (available everywhere)
python3 -c "
import json, sys

data = json.loads(sys.stdin.read())
rigs = data.get('rigs', [])

if not rigs:
    print(' No rigs')
    sys.exit(0)

# Sort by name for stable order
rigs.sort(key=lambda r: r['name'])

parts = []
for rig in rigs:
    name = rig['name']
    polecats = rig.get('polecat_count', 0)
    crew = rig.get('crew_count', 0)

    # Check agent states
    agents = rig.get('agents', [])
    witness_up = False
    refinery_up = False
    for a in agents:
        if a.get('role') == 'witness' and a.get('running'):
            witness_up = True
        if a.get('role') == 'refinery' and a.get('running'):
            refinery_up = True

    # Rig status icon
    if polecats > 0:
        icon = '🔨'  # working
    elif witness_up and refinery_up:
        icon = '🟢'  # operational
    elif witness_up or refinery_up:
        icon = '🟡'  # partial
    else:
        icon = '⚫'  # stopped

    parts.append(f'{icon} {name}')

print(' ' + '  '.join(parts))
" <<< "$json"
