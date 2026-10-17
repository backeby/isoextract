# isoextract (development version)
# https://github.com/richardgv/isoextract/

# Copied from compton <https://github.com/chjj/compton>

# Use tab to indent recipe lines, spaces to indent other lines, otherwise
# GNU make may get unhappy.

CC ?= gcc
PKG_CONFIG ?= pkg-config

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1

PACKAGES = glib-2.0 libmirage libisofs-1
LIBS =
INCS =

OBJS = isoextract.o utils.o

# === Configuration flags ===
CFG = -std=c11 -D_FILE_OFFSET_BITS=64

# ==== PCRE ====
ifeq "$(NO_REGEX_PCRE)" ""
  CFG += -DCONFIG_REGEX_PCRE
  PACKAGES += libpcre2-8
  ifeq "$(NO_REGEX_PCRE_JIT)" ""
    CFG += -DCONFIG_REGEX_PCRE_JIT
  endif
endif

# === Version string ===
ISOEXTRACT_VERSION ?= $(shell git describe --always --dirty 2>/dev/null || echo unknown)
CFG += -DISOEXTRACT_VERSION="\"$(ISOEXTRACT_VERSION)\""

LDFLAGS ?= -Wl,-O1 -Wl,--as-needed
CFLAGS ?= -DNDEBUG -O2 -D_FORTIFY_SOURCE=2

LIBS += $(shell $(PKG_CONFIG) --libs $(PACKAGES))
INCS += $(shell $(PKG_CONFIG) --cflags $(PACKAGES))
# Replace -I with -isystem to silence warnings in those header files
INCS := $(patsubst -I%, -isystem%, $(INCS))

CFLAGS += -Wall -Wextra -Wformat=2
ifneq "$(DEV)" ""
  CC = clang
  CFLAGS += -Weverything -Wno-disabled-macro-expansion -Wno-padded -Wno-gnu -ggdb
endif

BINS = isoextract
MANPAGES_RAW = isoextract.1
MANPAGES = $(addprefix man/, $(MANPAGES_RAW))
MANPAGES_HTML = $(addsuffix .html,$(MANPAGES))
EXTRADOCS = README.asciidoc

# === Recipes ===
.DEFAULT_GOAL := isoextract

src/.clang_complete: Makefile
	@(for i in $(filter-out -O% -DNDEBUG, $(CFG) $(CFLAGS) $(INCS)); do echo "$$i"; done) > $@

%.o: src/%.c
	$(CC) $(CPPFLAGS) $(CFG) $(CFLAGS) $(INCS) -MMD -MP -c $< -o $@

-include $(OBJS:.o=.d)

isoextract: $(OBJS)
	$(CC) $(CFG) $(LDFLAGS) $(CFLAGS) -o $@ $(OBJS) $(LIBS)

man/%.1: man/%.1.asciidoc
	a2x --format manpage $<

man/%.1.html: man/%.1.asciidoc
	asciidoc $<

docs: $(MANPAGES) $(MANPAGES_HTML)

install: $(BINS) $(MANPAGES)
	@install -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(MANDIR)"
	@install -m755 $(BINS) "$(DESTDIR)$(BINDIR)"/ 
	@install -m644 $(MANPAGES) "$(DESTDIR)$(MANDIR)"/
ifneq "$(DOCDIR)" ""
	@install -d "$(DESTDIR)$(DOCDIR)"
	@install -m644 $(EXTRADOCS) "$(DESTDIR)$(DOCDIR)"/
endif

uninstall:
	@rm -f $(addprefix "$(DESTDIR)$(BINDIR)/", $(notdir $(BINS)))
	@rm -f $(addprefix "$(DESTDIR)$(MANDIR)"/, $(MANPAGES_RAW))
ifneq "$(DOCDIR)" ""
	@rm -f $(addprefix "$(DESTDIR)$(DOCDIR)"/, $(notdir $(EXTRADOCS)))
endif

clean:
	@rm -f $(OBJS) $(OBJS:.o=.d) isoextract $(MANPAGES) $(MANPAGES_HTML) src/.clang_complete

check: isoextract
	sh tests/integration.sh

version:
	@echo "$(ISOEXTRACT_VERSION)"

.PHONY: install uninstall clean docs version check
