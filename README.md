# 🍺 Homebrew Migration Helper (`scripts/find-missing-casks.sh`)

A handy script to identify manually installed macOS applications that have an official Homebrew Cask available. Simplify your app management!

## 🎯 Purpose

This script scans your standard application directories (`/Applications` and `~/Applications`) to find GUI applications (`.app`) that meet two criteria:

1.  ✅ The application is **not** currently managed by an installed Homebrew cask.
2.  📦 A **verified cask** for this application *does* exist in the official Homebrew repository.

Essentially, it helps you find apps you might have installed manually that could be managed via Homebrew for easier updates and uninstallation.

## 🚀 Getting Started

Follow these steps to use the `scripts/find-missing-casks.sh` script:

### 🛠️ Prerequisites

*   **Homebrew:** Essential for the script's core functionality. Ensure it's installed.
*   **curl & jq:** Required for fetching and processing API data. Install them via Homebrew:
    ```bash
    brew install curl jq
    ```

### ▶️ Running the Script

1.  **Clone/Download:** Get the script by cloning this repository or downloading `scripts/find-missing-casks.sh`.
    ```bash
    # Example using git clone
    git clone https://github.com/florian101010/homebrew-migration-helper.git
    cd homebrew-migration-helper
    ```
2.  **Make Executable:** Grant execution permissions:
    ```bash
    chmod +x scripts/find-missing-casks.sh
    ```
3.  **Execute:** Run the script from your terminal:
    ```bash
    ./scripts/find-missing-casks.sh
    ```

### 📊 Understanding the Output

The script scans your Applications folders and compares found apps against the Homebrew Cask database. It lists applications installed manually for which a verified cask exists.

Output format:
```
  • Application Name        (cask: the-cask-token | homepage: https://developer.example.com/)
```
*   **Application Name:** The name of the `.app` file (e.g., `Visual Studio Code.app`).
*   **cask:** The official Homebrew Cask token (e.g., `visual-studio-code`).
*   **homepage:** The official homepage URL for verification.

### ✅ Next Steps

1.  **Review:** Carefully examine the generated list.
2.  **Verify:** Use the homepage URLs to confirm the suggested cask matches your application.
3.  **Decide:** Choose if you want Homebrew to manage the app.
4.  **(Optional) Migrate:** If migrating, *first uninstall the manual version*, then install via Homebrew:
    ```bash
    brew install --cask <cask-token>
    ```
    *(Replace `<cask-token>` with the actual token from the output)*

## ⚙️ How it Works

1.  **Dependencies Check:** Verifies `curl` and `jq` are present.
2.  **API Cache:** Fetches cask data from the Homebrew API (`https://formulae.brew.sh/api/cask.json`) and caches it locally (`~/.cache/find-missing-casks/cask_api_data.json`) for 24 hours to speed up runs.
3.  **Installed Check:** Uses `brew info --json=v2 --installed` to identify currently managed casks and their app paths.
4.  **System Scan:** Looks for `.app` files in directories defined by `APP_DIRS` (defaults: `/Applications`, `~/Applications`).
5.  **Comparison:**
    *   Checks if a found `.app` is already managed by Homebrew. Skips if yes.
    *   If not managed, extracts the filename (e.g., `Folx.app`).
    *   Looks up the filename in the cached API data.
    *   If a match is found, confirms a *verified* cask exists.
6.  **Output Generation:** Lists the verified, unmanaged applications with their cask token and homepage.

## 🔧 Configuration

*   **Scan Directories:** Modify the `APP_DIRS` variable near the top of the `scripts/find-missing-casks.sh` script to include additional directories in the scan.

## 📚 Detailed Documentation

For more in-depth information, please refer to the documents in the `docs` folder:

*   **[Script Internals (`SCRIPT_DETAILS.md`)](./docs/SCRIPT_DETAILS.md):** A deep dive into how the script works, including API handling, caching, and path resolution.
*   **[Troubleshooting Guide (`TROUBLESHOOTING.md`)](./docs/TROUBLESHOOTING.md):** Solutions for common errors and issues you might encounter.