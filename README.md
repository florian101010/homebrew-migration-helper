# 🍺 Homebrew Migration Helper (`scripts/find-missing-casks.sh`)

A handy script to identify manually installed macOS applications that have an official Homebrew Cask available. Simplify your app management!

## 🏠 About Homebrew

This script relies heavily on [Homebrew](https://brew.sh/), "The Missing Package Manager for macOS (or Linux)". Homebrew makes it easy to install, update, and manage software on your Mac. Homebrew Cask is an extension to Homebrew that allows you to manage graphical macOS applications directly from the command line.

*   **Homebrew Website:** [https://brew.sh/](https://brew.sh/)
*   **Homebrew GitHub:** [https://github.com/Homebrew/brew](https://github.com/Homebrew/brew)
*   **Homebrew Cask:** [https://docs.brew.sh/Cask-Cookbook](https://docs.brew.sh/Cask-Cookbook)

## 🎯 Purpose

This script scans your standard application directories (`/Applications` and `~/Applications`, configurable via options) to find GUI applications (`.app`) that meet two criteria:

1.  ✅ The application is **not** currently managed by an installed Homebrew cask.
2.  📦 A **verified cask** for this application *does* exist in the official Homebrew repository.

Essentially, it helps you find apps you might have installed manually that could be managed via Homebrew for easier updates and uninstallation.

## 🚀 Getting Started

Follow these steps to use the `scripts/find-missing-casks.sh` script:

### 🛠️ Prerequisites

*   **macOS:** This script is designed for macOS.
*   **Zsh:** The script is written in Zsh and must be run with it. macOS uses Zsh as the default shell.
*   **Homebrew:** Essential for the script's core functionality. Ensure it's installed from [brew.sh](https://brew.sh/).
*   **curl & jq:** Required for fetching and processing API data. Install them via Homebrew:
    ```bash
    brew install curl jq
    ```
*   **(Optional) Perl:** Used for robust sanitization of `brew info` output. Usually pre-installed on macOS.

### ▶️ Running the Script

1.  **Clone/Download:** Get the script by cloning this repository or downloading `scripts/find-missing-casks.sh`.
    ```bash
    # Example using git clone
    git clone https://github.com/florian101010/homebrew-migration-helper.git
    cd homebrew-migration-helper
    ```
2.  **Execute:** Run the script using `zsh`:
    ```bash
    zsh scripts/find-missing-casks.sh
    ```
    *Alternatively*, make it executable first and then run it directly (it will use the `#!/usr/bin/env zsh` shebang):
    ```bash
    chmod +x scripts/find-missing-casks.sh
    ./scripts/find-missing-casks.sh
    ```

### ⚙️ Options

The script accepts several command-line options to customize its behavior:

*   `-d <dir>`: Add a directory to scan. Can be used multiple times. (Default: `/Applications` and `~/Applications`)
*   `-c <cache_dir>`: Specify a custom cache directory. (Default: `~/.cache/find-missing-casks`)
*   `-t <ttl_seconds>`: Set cache Time-To-Live in seconds. (Default: 86400 = 24 hours)
*   `-f`: Force fetch new API data, ignoring cache.
*   `-v`: Verbose mode (print more details).
*   `-q`: Quiet mode (suppress info messages, show only results/errors).
*   `-i`: Interactive mode (prompt before suggesting installation for each app).
*   `-h`: Display help message.

Example: Scan only `/Applications` and force a cache refresh:
```bash
zsh scripts/find-missing-casks.sh -f -d /Applications
```

### 📊 Understanding the Output

The script scans the specified application folders and compares found apps against the Homebrew Cask database. It lists applications installed manually for which a verified cask exists.

Output format for each found app:
```
ApplicationName
  Cask:     cask-token
  Homepage: https://developer.example.com/
  Install:  brew install --cask cask-token
```
*   **ApplicationName:** The display name of the app (e.g., `Visual Studio Code`).
*   **Cask:** The official Homebrew Cask token (e.g., `visual-studio-code`).
*   **Homepage:** The official homepage URL for verification.
*   **Install:** The command to install the cask via Homebrew.

At the end, a summary line indicates the total count found.

### ✅ Next Steps

1.  **Review:** Carefully examine the generated list.
2.  **Verify:** Use the homepage URLs to confirm the suggested cask matches your application. Pay attention to version differences (e.g., `@beta`, `@nightly`, specific version numbers).
3.  **Decide:** Choose if you want Homebrew to manage the app.
4.  **(Optional) Migrate:** If migrating, *first uninstall the manual version*, then install via Homebrew using the provided command:
    ```bash
    brew install --cask <cask-token>
    ```
    *(Replace `<cask-token>` with the actual token from the output)*

## ⚙️ How it Works (Simplified)

1.  **Parse Options:** Reads command-line flags (`-d`, `-f`, etc.).
2.  **Dependencies Check:** Verifies `curl`, `jq`, and `brew` are present.
3.  **API Cache:** Fetches cask data from the Homebrew API (`https://formulae.brew.sh/api/cask.json`) and caches it locally (default: `~/.cache/find-missing-casks/cask_api_data.json`) for 24 hours (configurable) to speed up runs. Uses `curl`.
4.  **Installed Check:** Uses `brew info --json=v2 --installed` to get details of currently managed casks. Sanitizes the JSON output (using `perl` or `tr`) before processing with `jq` to extract managed app paths and tokens.
5.  **System Scan:** Uses `find` to locate `.app` bundles in the specified directories (default: `/Applications`, `~/Applications`).
6.  **Comparison Loop:** For each `.app` found:
    *   Checks if its path matches one managed by an *installed* cask. Skips if yes.
    *   Checks if an app with the same *basename* (e.g., `Visual Studio Code.app`) has already been processed. Skips if yes (avoids duplicates if the same app exists in multiple scanned locations).
    *   Looks up the app's basename in the cached API data.
    *   If a match is found, extracts the cask token and homepage.
    *   Adds the app details to the report list.
7.  **Output Generation:** Sorts the report list alphabetically and prints it, followed by the summary count.
8.  **Interactive Install (Optional):** If `-i` was used, prompts the user to install each found cask.

## 📚 Detailed Documentation

For more in-depth information, please refer to the documents in the `docs` folder:

*   **[Script Details (`SCRIPT_DETAILS.md`)](./docs/SCRIPT_DETAILS.md):** A deep dive into how the script works, including API handling, caching, path resolution, and variable explanations.
*   **[Troubleshooting Guide (`TROUBLESHOOTING.md`)](./docs/TROUBLESHOOTING.md):** Solutions for common errors and issues you might encounter.

## 📜 Version History

See the [CHANGELOG.md](./CHANGELOG.md) for a detailed history of changes.
Release notes for specific versions can be found in [RELEASE_NOTES.md](./RELEASE_NOTES.md) or on the [GitHub Releases](https://github.com/florian101010/homebrew-migration-helper/releases) page.

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.