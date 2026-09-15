# Unreleased

- Export secret values verbatim: support multi-line values, and preserve leading and trailing whitespace.
- Never log `op inject` output. Fail on invalid variable definitions instead of skipping them.
- Ignore blank lines and comments in all input modes.
- Read STDIN only when no variable or file arguments are given, or with an explicit `-` argument.
- Drop the 1Password CLI v1 version check.
- Fix Bash 3.2 compatibility (macOS `/bin/bash`). Test with Bash 3.2, 4.4 and 5 in CI.
- URL-encode masked values in GitHub Actions so masking works for values with `%` or newlines.
- Mask secret values in GitHub Actions logs by default (when `$GITHUB_ACTIONS=true`). Add option `--no-gha-masking` to disable it.

# 1.1.0 / 2025-11-26

- Add `--account` option to specify which 1Password account to use.
- Skip empty keys in parsing.
- Fix `--no-overwrite` to respect variables set to empty values.
- Improve error reporting and file input handling.

# 1.0.1 / 2025-03-16

- Allow special characters in passwords, like `$`, `"` or `\`.

# 1.0.0 / 2024-09-21

- Drop support for 1password CLI v1.x.
- Use `op inject` instead of `op run` to make Ctrl+C work.
- Add option `--no-overwrite` to avoid overwriting already set environment variables.
- Add option `--verbose` for more output while loading direnv.

# 0.1.0 / 2022-01-18

- First release!
