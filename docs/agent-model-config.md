# Agent Model Configuration

Gas Town roles can be configured to use different Claude models to optimize cost.
Not every role needs the most capable (and expensive) model.

## Default Setup

By default, all roles use the town's default agent (`claude` = Opus 4.6).

## Recommended Configuration

| Role | Agent | Model | Rationale |
|------|-------|-------|-----------|
| **Mayor** | `claude` (default) | Opus 4.6 | Coordination, strategic decisions |
| **Polecat** | `claude` (default) | Opus 4.6 | Writes code, needs full capability |
| **Witness** | `claude-sonnet` | Sonnet 4.5 | Routine monitoring, lifecycle checks |
| **Refinery** | `claude-sonnet` | Sonnet 4.5 | Mechanical merge queue processing |
| **Deacon** | `deacon` (custom) | Sonnet 4.5 | Heartbeat patrols, simple restart tasks |

## How to Configure

### 1. Create a custom agent alias

```bash
gts config agent set claude-sonnet "claude --dangerously-skip-permissions --model sonnet"
```

### 2. Assign to rig roles (witness + refinery)

Per-rig settings use `role_agents.<role>`:

```bash
# Apply to a single rig
gts rig settings set <rig> role_agents.witness claude-sonnet
gts rig settings set <rig> role_agents.refinery claude-sonnet

# Apply to all rigs
for rig in $(gts rig list --names-only 2>/dev/null || gts rig list | awk '/^  [a-z]/{print $1}'); do
  gts rig settings set "$rig" role_agents.witness claude-sonnet
  gts rig settings set "$rig" role_agents.refinery claude-sonnet
done
```

### 3. Assign to deacon (town-level)

The deacon is not a rig role — it's configured via a custom agent name that
matches the `"agent"` field in `mayor/daemon.json`:

```bash
gts config agent set deacon "claude --dangerously-skip-permissions --model sonnet"
```

This works because `daemon.json` already has `"agent": "deacon"` for the deacon
patrol. Creating a custom agent with that name overrides the default resolution.

## Verification

```bash
# List all agents (built-in + custom)
gts config agent list

# Check a rig's settings
gts rig settings show <rig>

# Check town default
gts config default-agent
```

## Notes

- Polecats inherit the default agent unless overridden per-rig with `role_agents.polecat`
- The mayor always runs interactively and uses whatever model the session was started with
- Changes take effect on next agent restart (existing sessions keep their model)
