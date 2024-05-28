# The default target of this Makefile is...
all::

-include ../../config.mak.autogen
-include ../../config.mak

prefix ?= /usr/local
shitexecdir ?= $(prefix)/libexec/shit-core
mandir ?= $(prefix)/share/man
man1dir ?= $(mandir)/man1
htmldir ?= $(prefix)/share/doc/shit-doc

../../shit-VERSION-FILE: FORCE
	$(MAKE) -C ../../ shit-VERSION-FILE

-include ../../shit-VERSION-FILE

# this should be set to a 'standard' bsd-type install program
INSTALL  ?= install
RM       ?= rm -f

ASCIIDOC         = asciidoc
ASCIIDOC_CONF    = -f ../../Documentation/asciidoc.conf
ASCIIDOC_HTML    = xhtml11
ASCIIDOC_DOCBOOK = docbook
ASCIIDOC_EXTRA   =
XMLTO            = xmlto
XMLTO_EXTRA      =

ifdef USE_ASCIIDOCTOR
ASCIIDOC         = asciidoctor
ASCIIDOC_CONF    =
ASCIIDOC_HTML    = xhtml5
ASCIIDOC_DOCBOOK = docbook
ASCIIDOC_EXTRA  += -I../../Documentation -rasciidoctor-extensions
ASCIIDOC_EXTRA  += -alitdd='&\#x2d;&\#x2d;'
XMLTO_EXTRA     += --skip-validation
endif

ifndef SHELL_PATH
	SHELL_PATH = /bin/sh
endif
SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))

MANPAGE_XSL   = ../../Documentation/manpage-normal.xsl

shit_SUBTREE_SH := shit-subtree.sh
shit_SUBTREE    := shit-subtree

shit_SUBTREE_DOC := shit-subtree.1
shit_SUBTREE_XML := shit-subtree.xml
shit_SUBTREE_TXT := shit-subtree.txt
shit_SUBTREE_HTML := shit-subtree.html
shit_SUBTREE_TEST := ../../shit-subtree

all:: $(shit_SUBTREE)

$(shit_SUBTREE): $(shit_SUBTREE_SH)
	sed -e '1s|#!.*/sh|#!$(SHELL_PATH_SQ)|' $< >$@
	chmod +x $@

doc: $(shit_SUBTREE_DOC) $(shit_SUBTREE_HTML)

man: $(shit_SUBTREE_DOC)

html: $(shit_SUBTREE_HTML)

install: $(shit_SUBTREE)
	$(INSTALL) -d -m 755 $(DESTDIR)$(shitexecdir)
	$(INSTALL) -m 755 $(shit_SUBTREE) $(DESTDIR)$(shitexecdir)

install-doc: install-man install-html

install-man: $(shit_SUBTREE_DOC)
	$(INSTALL) -d -m 755 $(DESTDIR)$(man1dir)
	$(INSTALL) -m 644 $^ $(DESTDIR)$(man1dir)

install-html: $(shit_SUBTREE_HTML)
	$(INSTALL) -d -m 755 $(DESTDIR)$(htmldir)
	$(INSTALL) -m 644 $^ $(DESTDIR)$(htmldir)

$(shit_SUBTREE_DOC): $(shit_SUBTREE_XML)
	$(XMLTO) -m $(MANPAGE_XSL) $(XMLTO_EXTRA) man $^

$(shit_SUBTREE_XML): $(shit_SUBTREE_TXT)
	$(ASCIIDOC) -b $(ASCIIDOC_DOCBOOK) -d manpage $(ASCIIDOC_CONF) \
		-ashit_version=$(shit_VERSION) $(ASCIIDOC_EXTRA) $^

$(shit_SUBTREE_HTML): $(shit_SUBTREE_TXT)
	$(ASCIIDOC) -b $(ASCIIDOC_HTML) -d manpage $(ASCIIDOC_CONF) \
		-ashit_version=$(shit_VERSION) $(ASCIIDOC_EXTRA) $^

$(shit_SUBTREE_TEST): $(shit_SUBTREE)
	cp $< $@

test: $(shit_SUBTREE_TEST)
	$(MAKE) -C t/ test

clean:
	$(RM) $(shit_SUBTREE)
	$(RM) *.xml *.html *.1

.PHONY: FORCE
