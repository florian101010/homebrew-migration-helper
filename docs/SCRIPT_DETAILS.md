# Script Internals: `scripts/find-missing-casks.sh`

This document provides a deeper dive into the internal workings of the `scripts/find-missing-casks.sh` script.

## ⚙️ Configuration Variables

The script starts by defining key configuration variables:

*   `APP_DIRS`: An array of directories to scan for `.app` files. Defaults to `/Applications` and `$HOME/Applications`.
*   `API_URL`: The URL for the official Homebrew Cask API endpoint, providing data on all available casks.
*   `CACHE_DIR`: The directory to store cached API data. Defaults to `$XDG_CACHE_HOME/find-missing-casks` or `$HOME/.cache/find-missing-casks` if `XDG_CACHE_HOME` is not set.
*   `CACHE_FILE`: The full path to the cached API data JSON file within `CACHE_DIR`.
*   `CACHE_TTL_SECONDS`: The Time-To-Live for the cache in seconds. Defaults to 24 hours (86400 seconds).

## ✅ Dependency Checks

Before proceeding, the script verifies that the necessary command-line tools, `curl` and `jq`, are installed and available in the system's PATH. If either is missing, it prints an error message to stderr and exits.

## ☁️ API Data Fetching & Caching (`get_api_data` function)

This function handles retrieving and caching the comprehensive list of casks from the Homebrew API.

1.  **Cache Directory:** Ensures the `CACHE_DIR` exists, creating it if necessary.
2.  **Cache Check:**
    *   Checks if the `CACHE_FILE` exists.
    *   If it exists, it checks the file's modification time using `find ... -mtime +0`. If the file is older than the `CACHE_TTL_SECONDS` (effectively > 1 day due to how `find -mtime` works with `+0`), it flags that a fresh fetch is needed.
    *   If the file doesn't exist or is older than the TTL, `needs_fetch` is set to `true`.
3.  **Fetching (if `needs_fetch` is true):**
    *   A temporary file is created using `mktemp`.
    *   `curl` is used to download the data from `API_URL` into the temporary file. `--fail` ensures curl exits with an error if the HTTP request fails, `--silent` suppresses progress meters, and `--location` handles redirects.
    *   **Error Handling:** If `curl` fails, an error is printed, the temporary file is removed, and the script exits (unless a potentially stale cache file exists, in which case it just warns and continues, relying on the potentially stale cache).
    *   **Validation:** If the download succeeds, `jq empty` is used to validate that the downloaded content is valid JSON.
    *   **Cache Update:** If the JSON is valid, the temporary file is moved to replace the `CACHE_FILE`. If invalid, the temporary file is discarded, an error is printed, and the script exits if no valid cache existed previously.
4.  **Final Check:** Ensures a valid `CACHE_FILE` exists before the main script logic proceeds.

## 📦 Identifying Installed Casks

This section determines which applications are already managed by Homebrew.

1.  **Command:** Runs `brew info --json=v2 --installed` to get detailed JSON output about all installed casks.
2.  **Parsing (`jq`):** Pipes the JSON output to `jq` to extract relevant information:
    *   Iterates through each cask (`.casks[]`).
    *   Extracts the cask token (`.token as $token`).
    *   Iterates through the artifacts associated with the cask (`.artifacts[]`).
    *   Identifies artifact entries that represent an application bundle (either a simple string ending in `.app` within an array, or within an object under the `.app` key).
    *   Selects only valid app paths (`select($app_path)`).
    *   Outputs the `$token` and the `$app_path`, separated by a tab (`\t`).
3.  **Path Resolution & Mapping:**
    *   Reads the tab-separated output line by line (`while IFS=$'\t' read ...`).
    *   For each `app_path_raw`, it attempts to determine the absolute, canonical path using `readlink -f`. It checks common locations (`/Applications`, `~/Applications`, the Caskroom itself) if the path isn't absolute initially. `|| true` prevents the script from exiting if `readlink` fails (e.g., broken link).
    *   Trims leading/trailing whitespace and removes potential surrounding quotes from the resolved path.
    *   Stores the cleaned, absolute path as a key and the corresponding `cask_token` as the value in the `installed_app_paths` associative array (a hash map in Zsh).

## 🗺️ Building the API Lookup Map

This creates an efficient lookup map from the cached API data.

1.  **Parsing (`jq`):** Reads the `CACHE_FILE` and processes it with `jq`:
    *   Iterates through each cask object in the main JSON array (`.[]`).
    *   Extracts the token (`.token as $token`) and homepage (`.homepage as $hp`).
    *   Iterates through the cask's artifacts (`.artifacts[]? as $artifact`). The `?` suppresses errors if `artifacts` is missing.
    *   Uses `//` (fallback operator) within `jq` to attempt extracting an app path string ending in `.app` from different possible artifact structures (array or object).
    *   Selects only results that are valid strings ending in `.app`.
    *   Extracts the basename (the filename) of the app path (`split("/") | .[-1]`).
    *   Ensures the basename is not empty.
    *   Outputs the `$token`, the app `$app_filename`, and the `$hp`, separated by tabs.
2.  **Mapping:**
    *   Reads the tab-separated output line by line.
    *   Trims whitespace and quotes from the `app_name`.
    *   Stores the cleaned `app_name` (e.g., `Visual Studio Code.app`) as the key in the `api_app_details_map` associative array.
    *   The value stored is a tab-separated string containing the `token` and the `homepage`.

## 🖥️ Scanning System Applications

This section finds all `.app` files in the specified `APP_DIRS`.

1.  **Iteration:** Loops through each directory listed in the `APP_DIRS` array.
2.  **`find` Command:** For each directory, uses `find "$dir" -maxdepth 1 -name '*.app' -print0`:
    *   `-maxdepth 1`: Searches only the immediate directory, not subdirectories.
    *   `-name '*.app'`: Finds items ending with `.app`.
    *   `-print0`: Prints the found paths separated by a null character, which handles filenames with spaces or special characters safely.
3.  **Path Processing:** Reads the null-separated output (`while IFS= read -r -d $'\0' ...`):
    *   Resolves the path to its absolute, canonical form using `readlink -f || true`.
    *   Trims whitespace and quotes.
    *   Adds the cleaned, absolute path to the `found_app_paths` array.

## 🔍 Comparison and Reporting

This is the core logic where found apps are compared against installed casks and the API data.

1.  **Initialization:** An empty array `processed_apps` is created to track app basenames (lowercase) that have already been reported, preventing duplicate entries if the same app exists in multiple `APP_DIRS`.
2.  **Iteration:** Loops through each `app_path` in the `found_app_paths` array.
3.  **Check if Managed:** Iterates through the keys (absolute paths) of the `installed_app_paths` map. If the current `app_path` exactly matches a key, the `is_managed` flag is set to `true`, and the loop for this app path continues to the next found app (`continue`).
4.  **Check for Duplicates:** If the app is not managed:
    *   Extracts the `app_filename` (basename).
    *   Converts the filename to lowercase (`lc_app_filename`).
    *   Checks if this lowercase filename is already in the `processed_apps` array. If yes, skips to the next found app (`continue`).
    *   If not a duplicate, adds the lowercase filename to `processed_apps`.
5.  **API Lookup:** Iterates through the keys (app filenames) of the `api_app_details_map`.
    *   Compares the `app_filename` from the system scan with the (cleaned) key from the API map.
    *   If a match is found:
        *   Retrieves the corresponding value (the tab-separated "token\thomepage" string).
        *   Uses Zsh parameter expansion (`"${(@s:\t:)details_string}"`) to split the string by the tab character into an array (`details_array`).
        *   Extracts the `actual_cask_token` and `homepage` from the array elements.
        *   Breaks the inner loop (API map iteration) as a match is found.
6.  **Reporting:** If an `actual_cask_token` was found during the API lookup (meaning the unmanaged app has a corresponding verified cask):
    *   Uses `printf` to format the output neatly, displaying the app name (without `.app`), the cask token, and the homepage URL.

## 🏁 Final Output

The script prints header/footer lines around the list of found applications and includes a note reminding the user to verify matches using the homepage URLs.