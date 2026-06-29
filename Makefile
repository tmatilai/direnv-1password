SHELL = bash

XDG_CONFIG_HOME ?= $(HOME)/.config

SH_FILE = 1password.sh
TEST_FILES = tests/*.bash tests/*.bats
BATS ?= bats

.PHONY: all
all:

.PHONY: install
install:
	install -d $(XDG_CONFIG_HOME)/direnv/lib
	install -m 0644 $(SH_FILE) $(XDG_CONFIG_HOME)/direnv/lib

.PHONY: test
test:
	shellcheck $(SH_FILE) $(TEST_FILES)
	shfmt -d -i 4 -s -ci -bn $(SH_FILE) $(TEST_FILES)
	$(BATS) tests

.PHONY: fmt
fmt:
	shfmt -w -i 4 -s -ci -bn $(SH_FILE) $(TEST_FILES)

# Print out the hash to be used in direnv configuration.
.PHONY: hash
hash:
	@printf "sha256-"; openssl dgst -sha256 -binary $(SH_FILE) | openssl base64 -A
