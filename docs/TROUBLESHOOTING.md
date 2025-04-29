# Troubleshooting `scripts/find-missing-casks.sh`

This guide helps resolve common issues you might encounter when using the script.

## ❗ Error: `jq is required but not installed` / `curl is required but not installed`

*   **Problem:** The script requires the `jq` (JSON processor) and `curl` (data transfer tool) commands, but they were not found in your system's PATH.
*   **Solution:** Install them using Homebrew:
    ```bash
    brew install jq curl
    ```
    Then, try running the script again.

## 🚫 Error: `Permission denied` when running `./scripts/find-missing-casks.sh`

*   **Problem:** The script file does not have execute permissions.
*   **Solution:** Grant execute permissions using the `chmod` command:
    ```bash
    chmod +x scripts/find-missing-casks.sh
    ```
    Then, run the script using `./scripts/find-missing-casks.sh`.

## 🌐 Error: `Failed to download API data from ...` / `Downloaded API data is not valid JSON`

*   **Problem:** The script could not download or validate the cask data from the Homebrew API. This could be due to:
    *   Temporary network connectivity issues.
    *   Changes in the Homebrew API URL or format (less likely).
    *   A firewall or proxy blocking the connection.
    *   An incomplete download resulting in invalid JSON.
*   **Solutions:**
    1.  **Check Network:** Ensure you have a stable internet connection.
    2.  **Retry:** Wait a few minutes and try running the script again.
    3.  **Clear Cache:** If the problem persists and you suspect a corrupted cache, manually delete the cache file and let the script fetch fresh data:
        ```bash
        # Determine cache directory (usually ~/.cache/find-missing-casks)
        CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/find-missing-casks"
        rm -f "$CACHE_DIR/cask_api_data.json"
        ```
        Then run the script again.
    4.  **Check URL:** Verify the `API_URL` variable within the script is still correct by visiting it in a browser: `https://formulae.brew.sh/api/cask.json`.
    5.  **Firewall/Proxy:** Check if any local firewall or network proxy might be interfering with `curl`'s connection to the API URL.

## 🤔 Script Doesn't Find an App I Expect it To

*   **Problem:** An application you manually installed isn't listed in the output.
*   **Possible Causes & Solutions:**
    1.  **App Location:** Is the `.app` file located directly within one of the directories listed in the `APP_DIRS` variable (default: `/Applications`, `~/Applications`)? The script *does not* search subdirectories by default.
        *   **Solution:** Add the specific directory containing the app to the `APP_DIRS` array near the top of the script, or move the app to one of the default locations.
    2.  **Already Managed:** Is the app actually managed by an installed Homebrew cask already? The script intentionally skips these. Run `brew list --cask` to check.
    3.  **No Verified Cask:** Does a *verified* cask actually exist for this specific application in the official Homebrew repository? Some apps don't have official casks, or the cask might be in a third-party tap and not included in the main API data.
        *   **Solution:** Search for the app on the Homebrew website (`https://formulae.brew.sh/cask/`) to confirm if an official cask exists.
    4.  **Filename Mismatch:** Does the `.app` filename on your system exactly match the filename expected by the Homebrew cask? Sometimes developers rename app bundles. The script relies on matching the `YourApp.app` filename found on disk to the filename listed in the cask definition via the API.

## ❓ Script Suggests an Incorrect Cask for My App

*   **Problem:** The script lists your app, but the suggested `cask-token` and `homepage` seem to belong to a different application.
*   **Possible Cause:** Multiple applications might share the same `.app` filename (e.g., `Manager.app`). The script finds the first match in the API data based on the filename.
*   **Solution:** **Always verify using the `homepage` URL** provided in the output before deciding to install the suggested cask. The homepage is the best indicator of whether the cask matches your specific application. If it doesn't match, do not install the suggested cask for that app.

## ⏳ Script Runs Slowly

*   **Problem:** The script takes a long time to complete.
*   **Possible Causes:**
    1.  **Initial API Fetch:** The very first run (or runs after the cache expires daily) needs to download the entire Homebrew Cask API data (~10-20MB), which can take time depending on your network speed. Subsequent runs using the cache should be much faster.
    2.  **Large Number of Apps:** Scanning many `.app` files or having a very large number of installed casks might slightly increase processing time.
*   **Solution:** Patience on the first run is usually required. If subsequent runs (within 24 hours) are consistently slow, check system performance or network latency.

If you encounter issues not listed here, please consider opening an issue on the project's GitHub repository.