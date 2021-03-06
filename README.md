# 1Password helpers for direnv

This repository includes a [direnv](https://direnv.net) library/extension for fetching secrets using [1Password CLI](https://support.1password.com/command-line/).

It is easy enough to use the 1Password CLI (`op`) directly, but versions 1 and 2 are not compatible. This library includes helpers which work with both versions.

_**NOTE:** 1Password CLI v2 is still in **Early Access** phase. Likewise this library is still finding the best way to work with it._
_The configuration syntax might still change, and compatibility can't be promised._

---

## Usage

Example `.envrc`:

```bash
# Download the latest version. See below for other installation methods.
source_url "https://github.com/tmatilai/direnv-1password/raw/v0.1.0/1password.sh" \
    "sha256-EBpKlq0fYtsxTUCun/ppQIt10RUyhifGt+740l2CJlg="

# Fetch one secret and export it into the specified environment variable
from_op MY_SECRET=op://vault/item/field

# Multiple secrets can be fetched by passing the items to the command's STDIN
from_op <<OP
    FIRST_SECRET=op://vault/item/field
    OTHER_SECRET=op://...
OP
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

The `.envrc` evaluation can then be forced with e.g. `direnv reload`.

Other option is to add the `op signin` command into the `.envrc`, but that will block the evaluation.
This might go against the best practices with direnv, as `.envrc` evaluations should in general be fast and non-blocking. But you decide.

Future versions of the library hopefully offer helpers for the login, too.

---

## Requirements

- [direnv](https://direnv.net). Might/should work with any somehow recent v2 version. Developed initially with v2.30.
- [1Password CLI](https://support.1password.com/command-line/) (`op`). Developed with v1.2 and 2.0.0-beta.8.
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
