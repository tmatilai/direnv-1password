SHELL = bash

XDG_CONFIG_HOME ?= $(HOME)/.config

SH_FILES = 1password.sh

.PHONY: all
all:

.PHONY: install
install:
	install -d $(XDG_CONFIG_HOME)/direnv/lib
	install -m 0644 $(SH_FILES) $(XDG_CONFIG_HOME)/direnv/lib

.PHONY: test
test:
	shellcheck $(SH_FILES)
	shfmt -d -i 4 -s -ci -bn $(SH_FILES)

.PHONY: fmt
fmt:
	shfmt -w -i 4 -s -ci -bn $(SH_FILES)
