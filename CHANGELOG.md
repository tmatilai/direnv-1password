# Changelog

## 1.2.0 / 2026-09-15

### Features

- Mask secret values in GitHub Actions logs by default (when `$GITHUB_ACTIONS=true`). Add option `--no-gha-masking` to disable it.
- Export secret values verbatim, including multi-line values and leading or trailing whitespace.
- Read STDIN only when no variable or file arguments are given, or with an explicit `-` argument.
- Ignore blank lines and comments in all input modes.

### Fixes

- Fix secret values containing `$` getting corrupted (regression in 1.1.0).
- Fix Bash 3.2 compatibility (macOS `/bin/bash`).
- Fix `--no-overwrite` skipping all variables (regression in 1.1.0).
- Fix indented variable definitions being skipped (regression in 1.1.0).
- Fail on invalid variable definitions instead of skipping them.
- Never log `op inject` output, as it contains the secret values.
- Allow exporting variables that have the same names as `from_op`'s internal variables, like `VERBOSE`.

## 1.1.0 / 2025-11-26

- Add `--account` option to specify which 1Password account to use.
- Skip empty keys in parsing.
- Fix `--no-overwrite` to respect variables set to empty values.
- Improve error reporting and file input handling.

## 1.0.1 / 2025-03-16

- Allow special characters in passwords, like `$`, `"` or `\`.

## 1.0.0 / 2024-09-21

- Drop support for 1password CLI v1.x.
- Use `op inject` instead of `op run` to make Ctrl+C work.
- Add option `--no-overwrite` to avoid overwriting already set environment variables.
- Add option `--verbose` for more output while loading direnv.

## 0.1.0 / 2022-01-18

- First release!
