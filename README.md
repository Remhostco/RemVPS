# REMVPS — Virtual Private Server Manager

A modular, terminal-based Docker VPS manager written in Bash.

## Features

- **Create** Ubuntu 24.04, Debian 12, or Alpine Linux containers in seconds
- **Full terminal UI** with ANSI colors, Unicode borders, spinners, and progress bars
- **Automatic configuration** — hostname, root password, SSH, MOTD, Bash prompt, and aliases
- **Resource limits** — optional CPU and RAM caps per container
- **Backup & Restore** — timestamped archives with Git remote push support
- **Auto-backup daemon** — runs in the background at a configurable interval
- **Settings persistence** — stored in `~/.config/remvps/remvps.conf`
- **Structured logging** — at `~/.local/share/remvps/logs/remvps.log`

## Requirements

| Dependency | Purpose |
|---|---|
| Bash 4+ | Shell runtime |
| Docker 20+ | Container engine |
| Internet access | Pulling base images (first run only) |
| git (optional) | Remote Git backup push |

## Installation

```bash
git clone https://github.com/remhostco/remvps.git
cd remvps
bash install.sh
```

After installation, run:

```bash
remvps
```


## Supported Operating Systems (container)

| OS | Package Manager |
|---|---|
| Ubuntu 24.04 | apt |
| Debian 12 | apt |
| Alpine Linux | apk |

## Data Directories

| Path | Purpose |
|---|---|
| `~/.config/remvps/` | Application configuration |
| `~/.local/share/remvps/logs/` | Log files |
| `~/.local/share/remvps/backups/` | Backup archives |
| `~/.cache/remvps/` | Runtime cache (backup queue, PIDs) |
| `/tmp/remvps/` | Temporary Docker build context |

## Backup & Restore

Backups compress the REMVPS config, logs, and per-container Docker metadata into a timestamped `.tar.gz` archive. Each archive is integrity-verified before being considered complete.

To enable automatic backups, go to **Settings → Backup Settings** and set the interval. If a Git repository URL is configured, completed backups are pushed automatically. Failed pushes are queued and retried on the next cycle or manually via **Backup & Restore → Push Queued Backups**.

## Security Notes

- Container root passwords are set inside the container at first open via an injected init script; they are **never** stored in plaintext outside `/tmp/remvps/init_<name>.sh` (which is mounted read-only into the container).
- REMVPS never deletes Docker containers that do not carry the `remvps=true` label.
- All user inputs (container names, hostnames, passwords, resource limits) are validated before any Docker command is executed.

## License

MIT
