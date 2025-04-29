# Roadmap & Potential Future Ideas

This document outlines potential future enhancements and ideas for the `homebrew-migration-helper` script.

## Streamlining the Migration Process

The current workflow requires users to manually uninstall an application before installing the corresponding Homebrew Cask version. The following ideas aim to simplify this:

1.  **Automated "Move to Trash" Option:**
    *   **Concept:** Add a flag (e.g., `--move-to-trash` or integrate with `-i`) that, if confirmed, moves the identified `.app` bundle to the Trash before attempting `brew install --cask`.
    *   **Pros:** Addresses the manual uninstall step for simple apps. Relatively safe (Trash allows recovery).
    *   **Cons:** Doesn't handle complex uninstallers or scattered support files. Requires careful path targeting.
    *   **Note:** Could include a `--dry-run` flag to preview actions without execution.

2.  **Enhanced Interactive Mode (`-i`) Options:**
    *   **Concept:** Expand the interactive prompt beyond just `[y/N]`.
    *   **Potential Options:**
        *   `[m]ove & install`: Move the existing `.app` to Trash, then install the cask.
        *   `[i]nstall only`: Install the cask without touching the existing app.
        *   `[N]o`: Skip this app.
        *   `[s]kip all`: Stop prompting for remaining apps.
        *   `[o]pen homepage`: Open the cask's homepage for verification.
        *   `[d]etails`: Show more info (`brew info cask-token`).
        *   `[a]dd to ignore`: Add the current app to a persistent ignore list.
        *   `[q]uit`: Exit the interactive session.
    *   **Pros:** More user control and information within the workflow.
    *   **Cons:** Increases prompt complexity. Requires additional logic.

3.  **Pre-Install Check for Running App:**
    *   **Concept:** Before suggesting installation or moving to Trash, check if the application process is running (`pgrep -f "$app_path"`).
    *   **Pros:** Prevents potential errors when modifying active apps.
    *   **Cons:** `pgrep` matching isn't always perfect. Adds a check step.

4.  **Generate a Migration Script:**
    *   **Concept:** Add an option (e.g., `--generate-script <filename>`) to output a shell script containing the necessary `mv` and `brew install` commands for review and manual execution.
    *   **Pros:** Full transparency and user control. Avoids complexity in the main script.
    *   **Cons:** Requires running a separate script. Less integrated feel.

5.  **Exclusion List:**
    *   **Concept:** Allow users to specify apps to ignore via a config file or flags (`--exclude 'App Name.app'`).
    *   **Pros:** Reduces noise for apps intentionally managed manually.
    *   **Cons:** Adds configuration complexity.

## Other Potential Ideas

*   **Support for Third-Party Taps:** Option to include casks from user-tapped repositories.
*   **Semantic Version Comparison:** Implement proper semantic version comparison (e.g., using external tools or libraries if necessary) to more accurately determine if the cask version is newer, older, or the same, highlighting major vs. minor differences.
*   **Pre-flight Disk Space Check:** Before attempting installation, check if there is sufficient disk space available for the cask.
*   **More Sophisticated Uninstall:** Integrate with tools like `trash` CLI or explore app-specific uninstall scripts (though this is significantly more complex).
*   **Output Formatting Options:** Allow different output formats (e.g., JSON, CSV).