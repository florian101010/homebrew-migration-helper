# Contributing to Homebrew Migration Helper

Thank you for considering contributing to the Homebrew Migration Helper!

## How to Contribute

1.  **Find/Create an Issue:** Look for an existing issue or open a new one to discuss the change you want to make. This helps coordinate efforts. Use the provided **Issue Templates** (Bug Report, Feature Request) when creating a new issue.
2.  **Fork the repository:** Create your own copy of the repository on GitHub.
3.  **Create a branch:** Make your changes in a new git branch based on the `main` branch:
    ```bash
    git checkout main
    git pull origin main # Ensure you have the latest changes
    git checkout -b my-feature-or-fix-branch
    ```
4.  **Make your changes:** Implement your fix or feature.
5.  **Test your changes:**
    *   Run `shellcheck scripts/find-missing-casks.sh` to check for script errors.
    *   Run the automated tests: `bats tests` (You might need to install bats-core: `brew install bats-core`).
    *   Add new tests for your changes if applicable.
6.  **Commit your changes:** Commit your changes using a descriptive commit message. Follow conventional commit message formats if possible (e.g., `feat: Add -o option for output file`).
    ```bash
    git commit -m "feat: Describe your feature or fix"
    ```
7.  **Push to the branch:** Push your changes to your fork:
    ```bash
    git push origin my-feature-or-fix-branch
    ```
8.  **Submit a pull request:** Open a pull request from your fork's branch to the main repository's `main` branch. Fill out the **Pull Request Template** provided. Your PR will be automatically checked by the GitHub Actions CI workflow (linting and tests).

## Reporting Bugs / Suggesting Enhancements

Please use the **Issue Templates** provided on GitHub when reporting bugs or suggesting enhancements. This helps ensure all necessary information is included.

Thank you for your contributions!