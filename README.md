# agentguard

Guard your VPS from multi-agent resource contention.

When you run multiple AI coding agents (Claude Code, Codex, etc.) in parallel on a VPS, they spawn concurrent `tsc` processes that each eat 2-4GB of RAM. This causes OOM crashes that kill sshd, Tailscale, and everything else — locking you out completely.

**agentguard** is a single-command setup that hardens a VPS against these failure modes:

| Module | What it does |
|--------|-------------|
| `swap` | Creates swap file (default 8GB) with fstab persistence |
| `sysctl` | Tunes vm.swappiness, protects sshd/dbus from OOM killer |
| `tmux` | Installs TPM + resurrect + continuum (sessions survive reboots) |
| `tsc-guard` | Semaphore limiting concurrent `tsc` to N slots (default 3) |
| `health` | Installs `agentguard-health` CLI for quick status checks |

## Quick Start

```bash
# From your local machine:
git clone https://github.com/donmasakayan/agentguard.git
cd agentguard
./setup.sh user@your-vps
```

That's it. One command, idempotent, safe to re-run.

## Usage

```bash
# Full setup (all modules)
./setup.sh user@your-vps

# Only specific modules
./setup.sh user@your-vps --module swap,tsc_guard

# Dry run (show what would happen)
./setup.sh user@your-vps --dry-run

# Custom config
./setup.sh user@your-vps --config ./myconfig.conf
```

After setup, SSH in and verify:

```bash
agentguard-health
```

## How tsc-guard Works

The problem: Turbo, npm scripts, and build tools resolve `node_modules/.bin/tsc` directly, bypassing PATH. You can't just put a wrapper on PATH.

The solution: **tsc-guard** uses a shim approach:

1. `tsc-guard` is installed to `/usr/local/bin/tsc-guard` — a bash script with flock-based semaphore logic
2. `tsc-guard-install <project-dir>` renames `node_modules/.bin/tsc` to `tsc-real` and symlinks `tsc-guard` in its place
3. When any tool invokes `tsc`, it actually runs `tsc-guard`, which:
   - Acquires a slot (flock on `/tmp/tsc-semaphore/slot-N.lock`)
   - Waits if all slots are busy
   - Finds the real `tsc-real` binary (sibling lookup)
   - `exec`s the real tsc — lock fd stays open, auto-released when tsc exits

The lock is held via an open file descriptor. If the process crashes, the OS closes the fd and the lock is automatically released. No stale locks, no cleanup needed.

### Per-Project Setup

After `bun install` or `npm install` (which recreates `node_modules/.bin/tsc`):

```bash
tsc-guard-install ~/myproject
```

You can guard multiple projects:

```bash
tsc-guard-install ~/project1 ~/project2 ~/project3
```

Or configure auto-install in your config:

```bash
TSC_GUARD_PROJECT_DIRS="/home/ubuntu/myproject /home/ubuntu/other"
```

## Configuration

Copy `agentguard.example.conf` and customize:

```bash
# Swap size
SWAP_SIZE_GB=4

# Max concurrent tsc processes
TSC_GUARD_MAX_SLOTS=2

# Disable a module
MODULE_TMUX=false

# Auto-guard these project dirs
TSC_GUARD_PROJECT_DIRS="/home/ubuntu/myproject"
```

Pass it to setup:

```bash
./setup.sh user@your-vps --config ./myconfig.conf
```

## What It Does NOT Do

- Install languages, editors, or AI agents
- Configure cloud services, API keys, or secrets
- Set up Tailscale, VPNs, or firewalls
- Overwrite existing dotfiles (appends to .tmux.conf only)

## Requirements

- Local: bash, ssh, tar
- Remote: Ubuntu/Debian (tested on Ubuntu 22.04/24.04), sudo access

## License

MIT
