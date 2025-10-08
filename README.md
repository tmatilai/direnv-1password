# 1Password helpers for direnv

This repository includes a [direnv](https://direnv.net) library/extension for fetching secrets using [1Password CLI](https://support.1password.com/command-line/).

---

## Usage

Example `.envrc`:

```bash
# Download the latest version. See below for other installation methods.
source_url "https://github.com/tmatilai/direnv-1password/raw/v1.0.1/1password.sh" \
    "sha256-4dmKkmlPBNXimznxeehplDfiV+CvJiIzg7H1Pik4oqY="

# Fetch one secret and export it into the specified environment variable
from_op MY_SECRET=op://vault/item/field

# Multiple secrets can be fetched by passing the items to the command's STDIN
from_op <<OP
    FIRST_SECRET=op://vault/item/field
    OTHER_SECRET=op://...
OP

# You can also use 'op item get' commands directly (without specifying a vault)
from_op --verbose <<OP
    MY_SECRET=op item get <item id> --format json --fields <field name> | jq -r .value
OP

# Multiple secrets can be fetched from a file as well.
# direnv will reload when the file changes.
from_op .1password

# Only load a secret from OP if it wasn't already set in `.env`.
dotenv_if_exists
from_op --no-overwrite MY_SECRET=op://vault/item/field

# Show the status of 1password while loading direnv.
from_op --verbose MY_SECRET=op://vault/item/field
```

### Secrets reference

The reference format is [described here](https://developer.1password.com/docs/cli/secrets-reference-syntax/). Vault, item and field can be referred either by name or ID.

You can also use `op` commands directly (e.g., `op item get <item-id> --fields username`). This is useful for item IDs without specifying a vault, or for piping through tools like `jq`.

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

The `.envrc` evaluation can then be forced with e.g. `direnv reload`.

Other option is to add the `op signin` command into the `.envrc`, but that will block the evaluation.
This might go against the best practices with direnv, as `.envrc` evaluations should in general be fast and non-blocking. But you decide.

Future versions of the library hopefully offer helpers for the login, too.

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
