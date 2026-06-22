# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Collection of security tools and WordPress automation scripts, unified under a single `tools` CLI wrapper. Most external tools are git submodules.

## Entry Points

```bash
tools                    # Interactive menu
tools help               # Full command list
tools update             # Pull main repo + all submodules + pip/bundle/composer/go build
```

Install: `ln -s $(pwd)/tools ~/bin/tools && chmod +x $(pwd)/tools`

## Adding a New Command to `tools`

1. Add script to `scripts/` (or appropriate subdir)
2. Add case entry in the `tools` main script
3. Source `scripts/WordPress/common.sh` for WP scripts

## Bash Script Conventions (`scripts/`)

- `set -euo pipefail` at top
- Symlink-safe path resolution — use this pattern exactly, not `$(dirname "$0")` alone:
  ```bash
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  done
  TOOLS_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  ```
- Source shared code via `common.sh`
- `UPPER_CASE` globals, `local lower_case`, `snake_case` functions
- Red `${RED}` for errors, `exit 1` for fatal

## WordPress Scripts (`scripts/WordPress/`)

- `common.sh` is source of truth for defaults (DB creds: `root/root`, binary detection via `find_binary()`)
- DB naming: `wp_$projectname` → directory `wp$projectname`
- `get_db_credentials_from_config()` parses `wp-config.php` and overrides defaults
- MySQL binary found via Homebrew fallback: `/opt/homebrew/opt/mysql@8.4/bin/`
- **Hardcoded path**: `wp-create.sh:147` copies themes from `/Users/josepgarcia/Webs/apache/__WP_THEMES/_INSTALAR/` — will fail for other users
- WP permissions: dirs `755`, files `644`
- `wp-create.sh` sets random 4-char table prefix via `perl -pi -e` + `/dev/urandom` + `md5sum` (not standard `wp_`)
- `scripts/WordPress/config.file` is deprecated — `common.sh` is the source of truth

## Submodules

| Dir | Tool | Language |
|-----|------|----------|
| `WhatWeb/` | Web tech fingerprinting | Ruby |
| `domain_analyzer/` | Domain analysis | Python 3 |
| `PHP-Antimalware-Scanner/` | PHP malware scan | PHP |
| `wpprobe/` | WP plugin/vuln scanner | Go |
| `AiGPT-WordPress-Exploitation-Framework/` | WP exploitation | Python |

**Never commit directly inside submodule dirs.** Use `tools update` to pull + build all.

`wpprobe` is a Go binary — `tools update` runs `go build -o wpprobe .` inside it.

## No Automated Tests

Manual verification required for all script changes:
1. Run via `tools <command>`
2. Verify exit codes and side effects (DB created, file perms, etc.)
3. Test missing args, network failures, non-existent paths
