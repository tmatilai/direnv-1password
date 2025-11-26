SHELL = bash

XDG_CONFIG_HOME ?= $(HOME)/.config

SH_FILE = 1password.sh

.PHONY: all
all:

.PHONY: install
install:
	install -d $(XDG_CONFIG_HOME)/direnv/lib
	install -m 0644 $(SH_FILE) $(XDG_CONFIG_HOME)/direnv/lib

.PHONY: test
test:
	shellcheck $(SH_FILE)
	shfmt -d -i 4 -s -ci -bn $(SH_FILE)

.PHONY: fmt
fmt:
	shfmt -w -i 4 -s -ci -bn $(SH_FILE)

# Print out the hash to be used in direnv configuration.
.PHONY: hash
hash:
	@printf "sha256-"; openssl dgst -sha256 -binary $(SH_FILE) | openssl base64 -A
