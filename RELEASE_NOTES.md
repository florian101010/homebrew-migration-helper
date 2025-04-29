# Release Notes - v0.1.0 (Initial Release) - 2025-04-29

We are excited to announce the initial release of the **Homebrew Migration Helper**!

This tool provides a command-line script (`scripts/find-missing-casks.sh`) designed to help macOS users identify applications they've installed manually that could potentially be managed using [Homebrew Cask](https://docs.brew.sh/Cask-Cookbook). Managing apps with Homebrew Cask simplifies updates and uninstallation.

## ✨ Key Features

*   **Identifies Potential Migrations:** Scans standard application directories (`/Applications`, `~/Applications`) for `.app` files.
*   **Homebrew Integration:** Compares found applications against the official Homebrew Cask API and your currently installed casks (`brew info --installed`).
*   **Clear Output:** Lists unmanaged applications that have a corresponding verified Homebrew Cask, providing:
    *   Application Name
    *   📦 Cask Token (e.g., `visual-studio-code`)
    *   🔗 Homepage URL (for verification)
    *   ▶️ Install Command (e.g., `brew install --cask visual-studio-code`)
*   **Customization:** Offers command-line options to:
    *   Scan additional directories (`-d`).
    *   Control API data caching (`-c`, `-t`, `-f`).
    *   Adjust output verbosity (`-v`, `-q`).
    *   Enable interactive installation prompts (`-i`).
*   **User-Friendly CLI:** Features colorized output, clear headers/footers, and helpful summary information.

## 🛠️ Usage

1.  Ensure prerequisites are met (Zsh, Homebrew, curl, jq).
2.  Run the script using `zsh scripts/find-missing-casks.sh` or make it executable (`chmod +x ...`) and run `./scripts/find-missing-casks.sh`.
3.  Review the output, verify casks using the homepage links, and decide if you want to migrate any applications to Homebrew management.

Refer to the `README.md` for detailed instructions and the `docs/` folder for more technical information and troubleshooting.

## 🙏 Acknowledgements

This tool relies heavily on the fantastic work of the Homebrew team and the comprehensive data available through their public API.

We hope this tool proves useful for managing your macOS applications!