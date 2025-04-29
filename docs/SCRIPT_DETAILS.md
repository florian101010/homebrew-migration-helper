# Script Internals: `scripts/find-missing-casks.sh`

This document provides a deeper dive into the internal workings of the `scripts/find-missing-casks.sh` script.

## 📜 Script Header & Setup

*   **Shebang:** `#!/usr/bin/env zsh` specifies that the script must be executed with the Zsh interpreter.
*   **Options:** `set -euo pipefail` sets strict error handling:
    *   `-e`: Exit immediately if a command exits with a non-zero status.
    *   `-u`: Treat unset variables as an error.
    *   `-o pipefail`: The return value of a pipeline is the status of the last command to exit with a non-zero status, or zero if no command exited with a non-zero status.
*   **Dependencies Comment:** Notes the script requires `curl` and `jq`.

## ⚙️ Configuration & Variables

The script defines several variables, some with defaults that can be overridden by command-line options:

*   **Defaults:**
    *   `DEFAULT_APP_DIRS`: Array of directories to scan (Default: `/Applications`, `$HOME/Applications`).
    *   `API_URL`: URL for the Homebrew Cask API.
    *   `DEFAULT_CACHE_DIR`: Default cache location (`$XDG_CACHE_HOME/find-missing-casks` or `$HOME/.cache/find-missing-casks`).
    *   `DEFAULT_CACHE_TTL_SECONDS`: Default cache validity (Default: 86400 seconds = 24 hours).
*   **Script Variables (Initialized empty or with defaults, potentially updated by options):**
    *   `APP_DIRS`: Array, populated by `-d` options or `DEFAULT_APP_DIRS`.
    *   `CACHE_DIR`: String, set by `-c` or `DEFAULT_CACHE_DIR`.
    *   `CACHE_FILE`: String, constructed from `CACHE_DIR`.
    *   `CACHE_TTL_SECONDS`: Integer, set by `-t` or `DEFAULT_CACHE_TTL_SECONDS`.
    *   `FORCE_FETCH`: Boolean (`true`/`false`), set by `-f`.
    *   `VERBOSE`: Boolean, set by `-v`.
    *   `QUIET`: Boolean, set by `-q`.
    *   `INTERACTIVE`: Boolean, set by `-i`.
*   **Colors:** Defines ANSI color codes for terminal output, disabled if stdout is not a terminal.
*   **Logging Function (`log_info`):** Prints messages to stderr unless `QUIET` is true.

## 🛠️ Argument Parsing (`getopts`)

*   Uses the Zsh built-in `getopts` to parse command-line options (`-h`, `-d`, `-c`, `-t`, `-f`, `-v`, `-q`, `-i`).
*   Handles options requiring arguments (e.g., `-d <dir>`) and simple flags (e.g., `-f`).
*   Includes error handling for invalid options or missing arguments.
*   Populates the corresponding script variables based on the provided options.
*   Resolves directories provided via `-d` to absolute paths using `cd "$OPTARG"; pwd`.
*   Ensures `CACHE_TTL_SECONDS` is a non-negative integer.

## 🔧 Applying Defaults & Final Setup

*   If no `-d` options were given, `APP_DIRS` is populated with `DEFAULT_APP_DIRS`.
*   `typeset -U APP_DIRS`: Ensures the `APP_DIRS` array contains only unique directory paths (Zsh specific).
*   Sets `CACHE_DIR` and `CACHE_TTL_SECONDS` to defaults if not provided via options.
*   Constructs the final `CACHE_FILE` path.
*   Adjusts `INTERACTIVE` and `VERBOSE` flags if `QUIET` is true (quiet overrides verbose, interactive implies not quiet).

## ✅ Dependency Checks

*   Verifies that `jq`, `curl`, and `brew` commands are available in the system's PATH. Exits with an error if any are missing.

## ☁️ API Data Fetching & Caching (`get_api_data` function)

This function handles retrieving and caching the comprehensive list of casks from the Homebrew API.

1.  **Cache Directory:** Ensures the `CACHE_DIR` exists (`mkdir -p`).
2.  **Cache Check:**
    *   Determines if a fetch is needed based on `FORCE_FETCH`, cache file existence, and cache file age (`stat -f %m` on macOS to get modification time).
    *   Compares `current_time - file_mod_time` against `CACHE_TTL_SECONDS`.
3.  **Fetching (if needed):**
    *   Creates a temporary file (`mktemp`).
    *   Uses `curl --fail --silent --location "$API_URL" -o "$temp_file"` to download data.
    *   **Error Handling:** If `curl` fails, prints an error, removes the temp file, and exits (unless a valid cache file already exists).
    *   **Validation:** Uses `jq empty "$temp_file"` to check if the downloaded content is valid JSON.
    *   **Cache Update:** If valid JSON, moves (`mv`) the temp file to `CACHE_FILE`. If invalid, removes temp file, warns, and potentially exits if no prior cache exists.
4.  **Final Check:** Exits if no valid `CACHE_FILE` exists after the fetch/check process.

## 📦 Identifying Installed Casks

Determines which applications are already managed by Homebrew.

1.  **Command:** Runs `brew info --json=v2 --installed` and stores the output in `brew_info_output`. Checks the exit code.
2.  **Sanitization:** Pipes the `brew_info_output` through `perl -pe 's/[\x00-\x08\x0B\x0C\x0E-\x1F]//g'` to remove problematic control characters that can cause `jq` to fail.
3.  **Parsing (`jq`):** Pipes the sanitized JSON to `jq` to extract relevant information:
    *   Iterates safely through casks (`.casks[]?`) and artifacts (`.artifacts[]?`).
    *   Extracts token (`$token`) and app path (`$app_path`) using robust checks for different artifact structures and ensuring values are not null.
    *   Outputs `$token\t$app_path`.
4.  **Path Resolution & Mapping:**
    *   Reads the tab-separated output line by line (`while IFS=$'\t' read ...`).
    *   Resolves `app_path_raw` to an absolute, canonical path (`abs_app_path`) using `readlink -f || true`, checking common locations if needed.
    *   Cleans the path (trims whitespace, removes quotes).
    *   Stores the cleaned path as a key and the `cask_token` as the value in the `installed_app_paths` associative array.

## 🗺️ Building the API Lookup Map

Creates an efficient lookup map from the cached API data.

1.  **Parsing (`jq`):** Reads `CACHE_FILE` and processes with `jq`:
    *   Iterates through casks (`.[]`).
    *   Extracts token (`$token`) and homepage (`$hp`).
    *   Iterates through artifacts (`artifacts[]?`).
    *   Extracts app path string ending in `.app` from various structures.
    *   Extracts the basename (`$app_filename`).
    *   Outputs `$token\t$app_filename\t$hp`.
2.  **Mapping:**
    *   Reads the tab-separated output.
    *   Cleans `app_name`.
    *   Stores the cleaned `app_name` (e.g., `Visual Studio Code.app`) as the key in `api_app_details_map`.
    *   The value is a tab-separated string: `token\thomepage`.

## 🖥️ Scanning System Applications

Finds all `.app` files in the specified `APP_DIRS`.

1.  **Iteration:** Loops through `APP_DIRS`.
2.  **`find` Command:** Uses `find "$dir" -maxdepth 1 -name '*.app' -print0` for each directory.
3.  **Path Processing:** Reads null-separated output (`while IFS= read -r -d $'\0' ...`).
    *   Resolves path using `readlink -f || true`.
    *   Cleans path.
    *   Adds the cleaned, absolute path to the `found_app_paths` array.

## 🔍 Comparison and Reporting

Core logic comparing found apps against installed casks and API data.

1.  **Initialization:**
    *   `report_lines`: Array to store formatted lines for final output.
    *   `processed_apps`: Array to track processed app basenames (lowercase) to avoid duplicates.
    *   Counters (`skipped_managed_count`, `skipped_processed_count`, `skipped_no_cask_count`).
    *   `apps_to_install_interactively`: Array to store details if `-i` is used.
2.  **Iteration:** Loops through each `app_path` in `found_app_paths`.
3.  **Check if Managed:** Iterates through keys of `installed_app_paths`. If `app_path` matches, increments `skipped_managed_count` and `continue`s to the next app.
4.  **Check for Duplicates:** If not managed:
    *   Gets `app_filename` (basename).
    *   Gets lowercase version (`lc_app_filename`).
    *   Checks if `lc_app_filename` is in `processed_apps`. If yes, increments `skipped_processed_count` using `$((...))` and `continue`s.
    *   Adds `lc_app_filename` to `processed_apps`.
5.  **API Lookup:** Iterates through keys (`key`) of `api_app_details_map`.
    *   Compares `app_filename` with the cleaned `key`.
    *   If matched:
        *   Retrieves the value (`details_string`).
        *   Splits by tab into `details_array` (`"${(@s:\t:)details_string}"`).
        *   Safely extracts `actual_cask_token=${details_array[1]:-}` and `homepage=${details_array[2]:-}` (using `:-` default for safety with `set -u`).
        *   If `actual_cask_token` is non-empty, `break`s the inner loop.
6.  **Reporting:** If `actual_cask_token` was found:
    *   Formats the output lines (app name, cask, homepage, install command) with colors.
    *   Appends the formatted block to `report_lines`.
    *   If `INTERACTIVE` is true, adds `app_name_display\tactual_cask_token` to `apps_to_install_interactively`.
7.  **No Cask Found:** If no `actual_cask_token` was found, increments `skipped_no_cask_count` using `$((...))`.

## 📊 Final Output & Summary

1.  **Sorting:** Sorts `report_lines` alphabetically (case-insensitive) using Zsh's `(on)` glob qualifier: `sorted_report_lines=("${(on)report_lines}")`.
2.  **Printing:**
    *   Prints a header (unless `QUIET`).
    *   Iterates through `sorted_report_lines` and prints each block using `print -- "$line"` to interpret escape codes (colors).
    *   Prints a footer (unless `QUIET`).
3.  **Summary:** Prints the total count from `${#report_lines[@]}` and detailed skipped counts if `VERBOSE` is true.

## 💬 Interactive Installation

*   Checks if `INTERACTIVE` is true and `apps_to_install_interactively` is not empty.
*   Loops through the stored app details.
*   Uses `vared -c reply` to prompt the user (`[y/N]`) for each cask.
*   If the reply is 'y' or 'Y', executes `brew install --cask "$cask_token"` and reports success or failure.

## 🏁 Exit

*   Exits with status code 0 (`exit 0`) upon successful completion.