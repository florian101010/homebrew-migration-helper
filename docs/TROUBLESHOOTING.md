# Troubleshooting `scripts/find-missing-casks.sh`

This guide helps resolve common issues you might encounter when using the script.

## ❗ Error: `jq is required but not installed` / `curl is required but not installed` / `brew command not found`

*   **Problem:** The script requires the `jq` (JSON processor), `curl` (data transfer tool), or `brew` (Homebrew) commands, but they were not found in your system's PATH.
*   **Solution:**
    *   Install `jq` and `curl` using Homebrew: `brew install jq curl`
    *   Ensure Homebrew itself is installed correctly by following the instructions at [https://brew.sh/](https://brew.sh/).
    *   Then, try running the script again.

## 🚫 Error: `Permission denied` when running `./scripts/find-missing-casks.sh`

*   **Problem:** The script file does not have execute permissions.
*   **Solution:** Grant execute permissions using the `chmod` command:
    ```bash
    chmod +x scripts/find-missing-casks.sh
    ```
    Then, run the script using `./scripts/find-missing-casks.sh`. Alternatively, run it directly with `zsh scripts/find-missing-casks.sh`.

## ❌ Error: `line ...: typeset: -U: invalid option` when running with `bash`

*   **Problem:** You are running the script using `bash scripts/find-missing-casks.sh`. The script is written for Zsh (`#!/usr/bin/env zsh`) and uses Zsh-specific features like `typeset -U` which Bash does not understand.
*   **Solution:** Run the script using the `zsh` interpreter explicitly:
    ```bash
    zsh scripts/find-missing-casks.sh
    ```
    Or make it executable (`chmod +x ...`) and run it directly (`./scripts/...`).

## 📉 Error: `jq: parse error: Invalid string: control characters ...`

*   **Problem:** The JSON output from `brew info --json=v2 --installed` contains unexpected control characters that `jq` cannot parse. This can happen with certain application metadata.
*   **Solution:** The script includes a sanitization step using `perl` (or `tr` in older versions) to remove these characters before piping the data to `jq`. If you encounter this error with the latest script version, it might indicate a new type of invalid character. Please open an issue on GitHub. You could also try forcing a cache refresh (`-f` flag) in case the `brew info` output was temporarily corrupted.

## 🤫 Script Exits Silently with Exit Code 1

*   **Problem:** The script stops execution and exits with status code 1 without printing any specific error message (especially within the main comparison loop). This often happens when `set -e` is active and a command fails in an unexpected way.
*   **Cause:** We observed this happening with certain arithmetic operations (`((...))` or `let ...++`) in specific Zsh environments when processing certain apps.
*   **Solution:** The script has been updated to use the `$((variable + 1))` syntax for increments, which proved more robust in these cases. Ensure you are using the latest version of the script. If the problem persists, try adding debug `echo` statements within the loop in `scripts/find-missing-casks.sh` to pinpoint the exact command causing the exit.

## 🌐 Error: `Failed to download API data from ...` / `Downloaded API data is not valid JSON`

*   **Problem:** The script could not download or validate the cask data from the Homebrew API. This could be due to:
    *   Temporary network connectivity issues.
    *   Changes in the Homebrew API URL or format (less likely).
    *   A firewall or proxy blocking the connection.
    *   An incomplete download resulting in invalid JSON.
*   **Solutions:**
    1.  **Check Network:** Ensure you have a stable internet connection.
    2.  **Retry:** Wait a few minutes and try running the script again. Use the `-f` flag to force a fresh download attempt.
    3.  **Clear Cache Manually:** If the problem persists and you suspect a corrupted cache, manually delete the cache file and let the script fetch fresh data:
        ```bash
        # Determine cache directory (use -c option value if specified, else default)
        DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/find-missing-casks"
        CACHE_DIR=${your_custom_cache_dir:-$DEFAULT_CACHE_DIR} # Replace if using -c
        rm -f "$CACHE_DIR/cask_api_data.json"
        ```
        Then run the script again (preferably with `-f`).
    4.  **Check URL:** Verify the `API_URL` variable within the script is still correct by visiting it in a browser: `https://formulae.brew.sh/api/cask.json`.
    5.  **Firewall/Proxy:** Check if any local firewall or network proxy might be interfering with `curl`'s connection to the API URL.

## 🤔 Script Doesn't Find an App I Expect it To

*   **Problem:** An application you manually installed isn't listed in the output.
*   **Possible Causes & Solutions:**
    1.  **App Location:** Is the `.app` file located directly within one of the scanned directories? The script *does not* search subdirectories. Use the `-d <dir>` option to add specific parent directories if your app is elsewhere.
    2.  **Already Managed:** Is the app actually managed by an installed Homebrew cask already? The script intentionally skips these. Run `brew list --cask` to check.
    3.  **No Verified Cask:** Does a *verified* cask actually exist for this specific application in the official Homebrew repository? Some apps don't have official casks, or the cask might be in a third-party tap and not included in the main API data.
        *   **Solution:** Search for the app on the Homebrew website (`https://formulae.brew.sh/cask/`) to confirm if an official cask exists.
    4.  **Filename Mismatch:** Does the `.app` filename on your system exactly match the filename expected by the Homebrew cask? Sometimes developers rename app bundles. The script relies on matching the `YourApp.app` filename found on disk to the filename listed in the cask definition via the API. Use `-v` (verbose) mode to see skipped apps.

## ❓ Script Suggests an Incorrect Cask for My App

*   **Problem:** The script lists your app, but the suggested `cask-token` and `homepage` seem to belong to a different application.
*   **Possible Cause:** Multiple applications might share the same `.app` filename (e.g., `Manager.app`). The script finds the first match in the API data based on the filename.
*   **Solution:** **Always verify using the `homepage` URL** provided in the output before deciding to install the suggested cask. The homepage is the best indicator of whether the cask matches your specific application. If it doesn't match, do not install the suggested cask for that app.

## ⏳ Script Runs Slowly

*   **Problem:** The script takes a long time to complete.
*   **Possible Causes:**
    1.  **Initial API Fetch:** The very first run (or runs after the cache expires or with `-f`) needs to download the entire Homebrew Cask API data (~10-20MB), which can take time depending on your network speed. Subsequent runs using the cache should be much faster.
    2.  **Large Number of Apps:** Scanning many `.app` files or having a very large number of installed casks might slightly increase processing time.
*   **Solution:** Patience on the first run (or with `-f`) is usually required. If subsequent runs (within the cache TTL) are consistently slow, check system performance or network latency.

If you encounter issues not listed here, please consider opening an issue on the project's GitHub repository.