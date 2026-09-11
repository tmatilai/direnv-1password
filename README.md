# 1Password helpers for direnv

This repository includes a [direnv](https://direnv.net) library/extension for fetching secrets using [1Password CLI](https://support.1password.com/command-line/).

---

## Usage

Example `.envrc`:

```bash
# Download the latest version. See below for other installation methods.
source_url "https://github.com/tmatilai/direnv-1password/raw/v1.1.0/1password.sh" \
    "sha256-JLh6cts1LNpmo7JeVgJ3NgmeHI3G7h2deYwkcpTweDI="

# Fetch one secret and export it into the specified environment variable
from_op MY_SECRET=op://vault/item/field

# Multiple secrets can be fetched by passing the items to the command's STDIN
from_op <<OP
    FIRST_SECRET=op://vault/item/field
    OTHER_SECRET=op://...
OP

# Multiple secrets can be fetched from a file as well.
# direnv will reload when the file changes.
from_op .1password

# Only load a secret from OP if it wasn't already set in `.env`.
dotenv_if_exists
from_op --no-overwrite MY_SECRET=op://vault/item/field

# Use a specific 1Password account.
# Also show the status of 1Password while loading direnv.
from_op --account my.1password.com --verbose MY_SECRET=op://vault/item/field

# Make sure that a 1Password session exists before fetching the secrets.
# If no account is configured, this checks/signs in to my.1password.com.
# Without `--signin` the session is never checked. See "1Password login" below.
from_op --signin MY_SECRET=op://vault/item/field

# Check the session separately, without ever prompting.
from_op_signin --no-interactive || return

# When running in GitHub Actions (`GITHUB_ACTIONS=true`) secret values are
# masked in the logs by default. Disable it with `--no-gha-masking`.
from_op --no-gha-masking MY_SECRET=op://vault/item/field
```

### Secrets reference

The reference format is [described here](https://developer.1password.com/docs/cli/secrets-reference-syntax/). Vault, item and field can be referred either by name or ID.

With 1Password CLI v1 the section (referred in the docs) can not be used, so in some cases the item ID has to be used.

### 1Password login

For the `from_op` command (or actually the underlying `op` command) to work, a valid 1Password session has to exist.

One option is to [sign in](https://support.1password.com/command-line-reference/#signin) manually before `.envrc` evaluation. For example:

```bash
# Bash, ZSH, etc.
eval $(op signin ACCOUNT)
```

```fish
# Fish
eval (op signin ACCOUNT)
```

The `.envrc` evaluation can then be forced with e.g. `direnv reload`. This is still the recommended flow.

#### Session helpers

The session is never checked unless you ask for it. Plain `from_op` runs no extra commands, and behaves exactly like it does without any of the options below.

Adding `--signin` verifies that a usable session exists before any secret is fetched, and tries to establish one if it does not. You then get an actionable error instead of a generic injection failure:

```bash
from_op --signin MY_SECRET=op://vault/item/field
```

If you do not pass `--account` and `OP_ACCOUNT` is not set, the helper checks and signs in with `--account my.1password.com`. This avoids the interactive 1Password account picker that `op signin` can show when multiple accounts are available. Use `--account ACCOUNT` or set `OP_ACCOUNT` when you want a different account:

```bash
from_op --signin --account team.1password.com MY_SECRET=op://vault/item/field
```

The same check is available on its own as the `from_op_signin` command. For example, to check the session without ever prompting, and to stop the evaluation if there is none:

```bash
from_op_signin --no-interactive || return
```

It accepts the following options:

- `--account ACCOUNT` - use a specific 1Password account.
- `--no-interactive` - only check for a session, never try to establish one.
- `--timeout SECONDS` - how long 1Password is waited for. Defaults to 10.
- `--quiet` / `--verbose` - suppress or expand the output. By default the command is silent unless it fails.

And returns:

- `0` when the session is usable,
- `1` when there is none and it could not be established,
- `2` when the 1Password CLI is not installed.

The command is not hostile to `set -e`, so `from_op_signin || true` works if you want to ignore the result.

#### Blocking behaviour

Signing in can block, as it waits for the request to be approved in the 1Password app, and that is exactly why it is opt-in: `.envrc` evaluations should in general be fast and non-blocking.

Note that direnv evaluates `.envrc` without a terminal. `op` is therefore always run without one, and can not ask for a password or an account selection: only the 1Password app integration, including the biometric unlock, can answer without terminal input. Signing in with a password stays a manual step, as described above. Use `from_op_signin --no-interactive` when you want a check that never tries to sign in at all. Either way the wait is bounded by `--timeout`.

When `OP_SERVICE_ACCOUNT_TOKEN`, or both `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`, are set, `op` authenticates on every invocation and there is no session to check. The check is then skipped altogether, which keeps CI environments fast.

---

## Requirements

- [direnv](https://direnv.net). Might/should work with any somehow recent v2 version. Developed initially with v2.30.
- [1Password CLI 2.x](https://support.1password.com/command-line/) (`op`).
- A shell supported by direnv. Bash v3+ should work.

---

## Installation

There are a couple of options to use/install the library. Upgrades must be done manually. Watch [the repository](https://github.com/tmatilai/direnv-1password) for new versions.

### Use `source_url` stdlib command

One option is to use the [`source_url`](https://direnv.net/man/direnv-stdlib.1.html#codesourceurl-lturlgt-ltintegrity-hashgtcode) command in the direnv stdlib in your `.envrc` file.

The latest version can be fetched with the command in [the usage example](#usage).

Hash for another version can be fetched with the [`direnv fetchurl`](https://direnv.net/man/direnv-fetchurl.1.html) command in shell:

```bash
direnv fetchurl "https://github.com/tmatilai/direnv-1password/raw/<VERSION>/1password.sh"
```

Note that as stated in the direnv documentation, the downloaded file is cached, and thus the URL should return always the same version. This means that `main` and other branches can not be used.

### Manual download to `lib/`

Download/copy/symlink the [1password.sh](./1password.sh) into `~/.config/direnv/lib/1password.sh` (or `$XDG_CONFIG_HOME/direnv/lib/1password.sh` if that's different).

You can also install with:

```bash
make install
```
