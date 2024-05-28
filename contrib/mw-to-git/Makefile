#
# Copyright (C) 2013
#     Matthieu Moy <Matthieu.Moy@imag.fr>
#
# To build and test:
#
#   make
#   bin-wrapper/shit mw preview Some_page.mw
#   bin-wrapper/shit clone mediawiki::http://example.com/wiki/
#
# To install, run shit's toplevel 'make install' then run:
#
#   make install

shit_MEDIAWIKI_PM=shit/Mediawiki.pm
SCRIPT_PERL=shit-remote-mediawiki.perl
SCRIPT_PERL+=shit-mw.perl
shit_ROOT_DIR=../..
HERE=contrib/mw-to-shit/

INSTALL = install

SCRIPT_PERL_FULL=$(patsubst %,$(HERE)/%,$(SCRIPT_PERL))
INSTLIBDIR=$(shell $(MAKE) -C $(shit_ROOT_DIR)/ \
                -s --no-print-directory prefix=$(prefix) \
                perllibdir=$(perllibdir) perllibdir)
DESTDIR_SQ = $(subst ','\'',$(DESTDIR))
INSTLIBDIR_SQ = $(subst ','\'',$(INSTLIBDIR))

all: build

test: all
	$(MAKE) -C t

check: perlcritic test

install_pm:
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(INSTLIBDIR_SQ)/shit'
	$(INSTALL) -m 644 $(shit_MEDIAWIKI_PM) \
		'$(DESTDIR_SQ)$(INSTLIBDIR_SQ)/$(shit_MEDIAWIKI_PM)'

build:
	$(MAKE) -C $(shit_ROOT_DIR) SCRIPT_PERL="$(SCRIPT_PERL_FULL)" \
                build-perl-script

install: install_pm
	$(MAKE) -C $(shit_ROOT_DIR) SCRIPT_PERL="$(SCRIPT_PERL_FULL)" \
                install-perl-script

clean:
	$(MAKE) -C $(shit_ROOT_DIR) SCRIPT_PERL="$(SCRIPT_PERL_FULL)" \
                clean-perl-script

perlcritic:
	perlcritic -5 $(SCRIPT_PERL)
	-perlcritic -2 $(SCRIPT_PERL)

.PHONY: all test check install_pm install clean perlcritic
