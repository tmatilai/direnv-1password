SHELL = bash

XDG_CONFIG_HOME ?= $(HOME)/.config

SH_FILE = 1password.sh
TEST_FILES = tests/*.bash tests/*.bats
ZIZMOR_INPUTS = .github
BATS ?= bats

.PHONY: all
all:

.PHONY: install
install:
	install -d $(XDG_CONFIG_HOME)/direnv/lib
	install -m 0644 $(SH_FILE) $(XDG_CONFIG_HOME)/direnv/lib

.PHONY: check
check: lint test

.PHONY: test
test:
	$(BATS) tests

.PHONY: lint
lint: lint-shell lint-actions

.PHONY: lint-shell
lint-shell:
	shellcheck $(SH_FILE) $(TEST_FILES)
	shfmt -d -i 4 -s -ci -bn $(SH_FILE) $(TEST_FILES)

.PHONY: lint-actions
lint-actions:
	zizmor $(ZIZMOR_INPUTS)

.PHONY: fmt
fmt:
	shfmt -w -i 4 -s -ci -bn $(SH_FILE) $(TEST_FILES)

# Print out the hash to be used in direnv configuration.
.PHONY: hash
hash:
	@printf "sha256-"; openssl dgst -sha256 -binary $(SH_FILE) | openssl base64 -A
