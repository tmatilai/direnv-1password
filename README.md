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

# Multiple secrets can be fetched by passing the items to the command's STDIN.
# STDIN is read only when no variable or file arguments are given, or with `-`.
# Blank lines and comments are ignored.
from_op <<OP
    # Values are exported verbatim, including whitespace and newlines.
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

# When running in GitHub Actions (`GITHUB_ACTIONS=true`) secret values are
# masked in the logs by default. Disable it with `--no-gha-masking`.
from_op --no-gha-masking MY_SECRET=op://vault/item/field
```

### Secrets reference

The reference format is [described here](https://developer.1password.com/docs/cli/secrets-reference-syntax/). Vault, item and field can be referred either by name or ID.

### 1Password login

`from_op` runs `op inject`, which needs an authenticated `op`. direnv evaluates `.envrc` without a terminal, so `op` cannot ask for a password there. There are three ways to authenticate:

- **Desktop app integration.** With the [app integration](https://developer.1password.com/docs/cli/app-integration/) enabled, `op` asks the 1Password app for authorization. The `.envrc` evaluation waits until the prompt is answered.
- **Manual sign-in.** [Sign in](https://support.1password.com/command-line-reference/#signin) in the shell before the `.envrc` evaluation, then run `direnv reload`:

  ```bash
  # Bash, ZSH, etc.
  eval $(op signin ACCOUNT)
  ```

  ```fish
  # Fish
  eval (op signin ACCOUNT)
  ```

- **Service account or 1Password Connect.** Set `OP_SERVICE_ACCOUNT_TOKEN`, or `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`. Every `op` call then authenticates on its own. This is the option for CI.

Running `op signin` inside `.envrc` does not work, as there is no terminal to type the password into.

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
