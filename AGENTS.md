# Agentic Coding Guidelines for Tools Repository

This repository is a collection of security tools, custom scripts, and utilities managed via a central Bash wrapper. It is designed to provide a unified interface for various specialized tools while maintaining custom automation for WordPress and database management.

## 🛠 Project Structure

- `tools`: Central entry point for all commands. It handles path resolution, color definitions, and command routing.
- `scripts/`: Custom Bash scripts organized by category.
    - `WordPress/`: Automations for WP installation, deletion, and plugin scaffolding.
    - `utilities/`: General purpose scripts like nmap, image resizing, etc.
- `submodules/`: External security tools maintained as git submodules.
    - `domain_analyzer/`: Python-based domain analysis tool.
    - `PHP-Antimalware-Scanner/`: PHP-based scanner for identifying malicious code.
    - `WhatWeb/`: Ruby-based web technology identifier.
- `phpstan/`: PHP Static Analysis tool.

## 🚀 Commands & Workflow

### Management
- **Update everything:** `tools update`
  - This command updates the main repository, all submodules, and triggers language-specific package managers (`pip`, `composer`, `bundle`) to update dependencies.
- **Interactive Menu:** Simply run `tools` to launch the menu-driven interface.

### Development Environment
- **Path Resolution:** The `tools` script uses a robust pattern to resolve its own location, even when called via symlinks. Always use `TOOLS_DIR` or equivalent logic in new scripts.
- **Binary Detection:** Use the `find_binary()` function in `common.sh` to locate executables like `mysql` or `php` in common locations (e.g., Homebrew paths).

## 💻 Code Style & Standards

### Bash (Core Scripting)
- **Strict Mode:** Start every script with `set -euo pipefail` to ensure errors are caught early and pipes don't hide failures.
- **Imports:** Source shared functionality using `SCRIPTPATH=$(dirname "$0")` followed by `source $SCRIPTPATH/common.sh`.
- **Variables:**
  - `UPPER_CASE`: For global configuration, environment variables, and constants (e.g., `DBUSER`, `GREEN`).
  - `lower_case`: For local variables within functions. Use `local` keyword.
- **Function Names:** Use `snake_case` (e.g., `check_mysql_connection`).
- **Formatting:**
  - Use 2 or 4 spaces for indentation (be consistent with the file).
  - Use `${VAR}` syntax for clarity, especially when concatenated with other strings.
- **Error Handling:**
  - Always check the return code of critical operations (e.g., `mysql`, `curl`, `git`).
  - Provide user-friendly error messages in `RED`.
  - Use `exit 1` for fatal errors.

### Python (domain_analyzer)
- Follow **PEP 8** style guidelines.
- Keep `requirements.txt` up to date.
- Use Python 3.x features (type hinting is encouraged for new code).

### PHP (PHP-Antimalware-Scanner)
- Follow **PSR-12** coding standards.
- Use `composer.json` for all dependency management.
- Static analysis is performed via the local `phpstan` installation.

### Ruby (WhatWeb)
- Use **Bundler** for dependency management.
- Follow standard Ruby naming conventions (snake_case for methods/variables).

## 🧪 Testing & Verification

### Manual Verification
As there is no global automated test suite, manual verification is mandatory for all changes to `scripts/`:
1. Execute the modified script via the `tools` wrapper.
2. Verify all exit codes and side effects (e.g., database creation, file permissions).
3. Test edge cases like missing arguments or failed network connections.

### Submodule Tests
Each submodule has its own testing framework:
- **WhatWeb:** Run `rake test` or check the `test/` directory.
- **PHP-Antimalware-Scanner:** Check `test-files/` and run `php test.php` if available.
- **PHPStan:** Use the internal e2e tests located in `phpstan/e2e/`.

## 📝 Rules & Conventions

### Submodules
- **DO NOT** commit changes directly to submodule directories unless explicitly instructed to fix a local integration issue.
- Prefer updating submodules using `tools update`.

### WordPress Specifics
- **Configuration:** `scripts/WordPress/config.file` (if it exists) or `common.sh` contains default credentials.
- **Integration:** Use `get_db_credentials_from_config()` to automatically parse `wp-config.php` when running scripts inside a WordPress root.
- **Permissions:** Always apply standard WP permissions after modifications: `755` for directories and `644` for files.

### Security
- **Secrets:** Never hardcode passwords or API keys. Use `common.sh` for defaults and allow overrides via environment variables.
- **Input Validation:** Sanitize project names and paths to prevent command injection in Bash scripts.

### Documentation
- Every new command added to `tools` must be documented in the `show_help` function and the root `README.md`.
- Use internal comments sparingly to explain "why" complex logic (like `sed/perl` regex) is used.
