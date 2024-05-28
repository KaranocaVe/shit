# The default target of this Makefile is...
all::

SCRIPT_PERL = shit-credential-netrc.perl
shit_ROOT_DIR = ../../..
HERE = contrib/credential/netrc

SCRIPT_PERL_FULL = $(patsubst %,$(HERE)/%,$(SCRIPT_PERL))

all:: build

build:
	$(MAKE) -C $(shit_ROOT_DIR) SCRIPT_PERL="$(SCRIPT_PERL_FULL)" \
                build-perl-script

install: build
	$(MAKE) -C $(shit_ROOT_DIR) SCRIPT_PERL="$(SCRIPT_PERL_FULL)" \
                install-perl-script

clean:
	$(MAKE) -C $(shit_ROOT_DIR) SCRIPT_PERL="$(SCRIPT_PERL_FULL)" \
                clean-perl-script

test: build
	./t-shit-credential-netrc.sh

testverbose: build
	./t-shit-credential-netrc.sh -d -v

.PHONY: all build install clean test testverbose
