PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
DATADIR ?= /var/lib/openxchg
DESTDIR ?=

# Directory of this Makefile (trailing slash). Anchors source paths so
# 'make install' works regardless of invoking CWD.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: all install uninstall check test help

all: help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(srcdir)openxchg $(DESTDIR)$(BINDIR)/openxchg
	install -d $(DESTDIR)$(DATADIR)
	@if [ -z "$(DESTDIR)" ]; then $(MAKE) --no-print-directory check; fi

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/openxchg
	@# $(DATADIR) is deliberately left in place: it holds the rate database

check:
	@command -v openxchg >/dev/null 2>&1 || { echo 'openxchg: NOT FOUND (check PATH)'; exit 1; }
	@echo 'openxchg: OK'

test:
	$(srcdir)scripts/run_tests.sh

help:
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@echo '  install     Install openxchg to $(PREFIX) and create $(DATADIR)'
	@echo '  uninstall   Remove installed binary (keeps $(DATADIR) database)'
	@echo '  check       Verify openxchg is callable from PATH'
	@echo '  test        Run BATS test suite (offline)'
	@echo '  help        Show this message'
	@echo ''
	@echo 'Variables: PREFIX=$(PREFIX)  BINDIR=$(BINDIR)  DATADIR=$(DATADIR)  DESTDIR=$(DESTDIR)'
