# Find Missing Casks Script (`find-missing-casks.sh`)

## Purpose

This script scans your standard application directories (`/Applications` and `~/Applications`) to identify GUI applications (`.app` files) that meet the following criteria:

1.  The application is **not** currently managed by an installed Homebrew cask (i.e., it wasn't installed using `brew install --cask <cask_token>`).
2.  A **verified cask** for this application *does* exist in the official Homebrew repository.

The script helps you find applications you might have installed manually that could potentially be managed via Homebrew for easier updates and uninstallation.

## How it Works

1.  **Dependencies:** Requires `curl` (for fetching API data) and `jq` (for parsing JSON data). The script checks for these and exits if they are not found.
2.  **API Data Caching:** Fetches the complete list of available casks and their associated application filenames/homepages from the official Homebrew API (`https://formulae.brew.sh/api/cask.json`). This data is cached locally for 24 hours (`~/.cache/find-missing-casks/cask_api_data.json` by default) to speed up subsequent runs and reduce API calls.
3.  **Installed Cask Check:** Runs `brew info --json=v2 --installed` to get a list of casks currently installed via Homebrew and the application paths they manage. It resolves symlinks and cleans paths to build an internal map of managed application paths.
4.  **System Scan:** Scans the directories specified in the `APP_DIRS` variable (defaulting to `/Applications` and `~/Applications`) for `.app` files, resolving symlinks and cleaning paths.
5.  **Comparison & Verification:**
    *   For each `.app` found during the system scan, it first checks if its resolved path is already managed by an installed cask (using the map from step 3). If it is, the app is skipped.
    *   If the app is not managed, the script extracts its filename (e.g., `Folx.app`).
    *   It looks up this filename in the map created from the cached API data (step 2).
    *   If a match is found in the API data, the script confirms that a verified cask exists for this application filename.
6.  **Output:** Lists the applications found in step 5, displaying the application name, the verified cask token, and the official homepage URL associated with that cask. The homepage URL is crucial for verifying that the identified cask corresponds to the correct application, especially when multiple apps share similar names.

## Usage

1.  Ensure `curl` and `jq` are installed (`brew install curl jq`).
2.  Navigate to the directory containing the script.
3.  Make the script executable: `chmod +x find-missing-casks.sh`
4.  Run the script: `./find-missing-casks.sh`

The output will list applications like:

```
  • App Name                            (cask: cask-token | homepage: https://example.com/)
```

Review the list and check the homepages to confirm matches before deciding whether to reinstall any applications using `brew install --cask <cask-token>`.

## Configuration

The `APP_DIRS` variable near the top of the script can be modified to include additional directories to scan for `.app` files.