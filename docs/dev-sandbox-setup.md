# Gas Town Dev Sandbox Setup

Build and run gastown from source in complete isolation from the production install.

## Goal

- Run a second gastown instance from latest source
- Dedicated Linux user so nothing touches the main `gt` at `~/gt/`
- Use `GT_COMMAND` to avoid CLI name conflicts

## Steps

### 1. Create dedicated user

```bash
sudo useradd -m -s /bin/bash gtdev
sudo passwd gtdev
```

### 2. Install prerequisites (as gtdev)

```bash
sudo su - gtdev

# Go (if not system-wide)
# Check with: go version
# If missing, install from https://go.dev/dl/

# Ensure git, make, tmux are available
sudo apt install -y git make tmux
```

### 3. Clone and build gastown from source

```bash
sudo su - gtdev
cd ~
git clone https://github.com/steveyegge/gastown.git
cd gastown
make build
# Binary will be in ./gt or ./bin/gt — check Makefile for output path
make install   # This auto-configures gastown-src in config
```

### 4. Configure isolation

Add to `~gtdev/.bashrc`:

```bash
export GT_COMMAND=gts        # "gts" = gastown-source, avoids conflict with production "gt"
export GT_HOME=~/gt-sandbox  # Separate home directory from any existing install
```

Then:

```bash
source ~/.bashrc
```

### 5. Initialize a fresh town

```bash
gts install ~/gt-sandbox
cd ~/gt-sandbox
gts init
```

### 6. Verify

```bash
gts --version    # Should show latest from source
gts doctor       # Run health checks
gts status       # Should show clean empty town
```

## Notes

- The production `gt` v0.5.0 under user `kamyon` is completely untouched
- The `gtdev` user has its own `$HOME`, SSH keys, git config — fully isolated
- To update: `cd ~/gastown && git pull && make build && make install`
- If `gt stabilize` is available in the version you build, use `gts stabilize` after updates
- The `GT_COMMAND=gts` env var makes all internal templates use `gts` instead of `gt`
- You may need to set up SSH keys for `gtdev` if you want to clone private repos into this sandbox
- Dashboard can run on a different port: `gts dashboard --port 3001`
