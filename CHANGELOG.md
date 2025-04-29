# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-04-29

### Added

-   Initial script `scripts/find-missing-casks.sh` to identify manually installed apps with available Homebrew Casks.
-   Core functionality:
    -   Fetching and caching Homebrew Cask API data.
    -   Identifying installed casks via `brew info`.
    -   Scanning `/Applications` and `~/Applications` for `.app` files.
    -   Comparing found apps against installed casks and API data.
    -   Reporting potential migrations with cask token and homepage.
-   Command-line options: `-d`, `-c`, `-t`, `-f`, `-v`, `-q`, `-i`, `-h`.
-   Colorized output for terminal readability.
-   Informational logging to stderr, results to stdout.
- Basic documentation: `README.md`, `docs/SCRIPT_DETAILS.md`, `docs/TROUBLESHOOTING.md`.
- `LICENSE` (MIT), `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`.
- `.gitignore` file.
- GitHub Actions CI workflow for linting (`shellcheck`) and basic testing (`bats-core`).
- Initial automated tests (`tests/basic.bats`).
- Issue and Pull Request templates (`.github/`).

### Changed

-   Improved output formatting for clarity: added emojis, better spacing, visual separators.
-   Refined documentation (`README.md`, `docs/*`) for accuracy and clarity.

### Fixed

-   Corrected script execution requirement to Zsh (from initial attempts with Bash).
-   Resolved `jq` parsing errors by sanitizing `brew info` output (removing control characters).
-   Fixed silent script exits under `set -e` by replacing problematic arithmetic increments (`((...))`, `let`) with `$((...))` syntax.
-   Fixed color code rendering issues in the output.

[0.1.0]: https://github.com/florian101010/homebrew-migration-helper/releases/tag/v0.1.0