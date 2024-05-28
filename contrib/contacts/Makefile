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

ASCIIDOC = asciidoc
XMLTO    = xmlto

ifndef SHELL_PATH
	SHELL_PATH = /bin/sh
endif
SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))

ASCIIDOC_CONF = ../../Documentation/asciidoc.conf
MANPAGE_XSL   = ../../Documentation/manpage-normal.xsl

shit_CONTACTS := shit-contacts

shit_CONTACTS_DOC := shit-contacts.1
shit_CONTACTS_XML := shit-contacts.xml
shit_CONTACTS_TXT := shit-contacts.txt
shit_CONTACTS_HTML := shit-contacts.html

doc: $(shit_CONTACTS_DOC) $(shit_CONTACTS_HTML)

install: $(shit_CONTACTS)
	$(INSTALL) -d -m 755 $(DESTDIR)$(shitexecdir)
	$(INSTALL) -m 755 $(shit_CONTACTS) $(DESTDIR)$(shitexecdir)

install-doc: install-man install-html

install-man: $(shit_CONTACTS_DOC)
	$(INSTALL) -d -m 755 $(DESTDIR)$(man1dir)
	$(INSTALL) -m 644 $^ $(DESTDIR)$(man1dir)

install-html: $(shit_CONTACTS_HTML)
	$(INSTALL) -d -m 755 $(DESTDIR)$(htmldir)
	$(INSTALL) -m 644 $^ $(DESTDIR)$(htmldir)

$(shit_CONTACTS_DOC): $(shit_CONTACTS_XML)
	$(XMLTO) -m $(MANPAGE_XSL) man $^

$(shit_CONTACTS_XML): $(shit_CONTACTS_TXT)
	$(ASCIIDOC) -b docbook -d manpage -f $(ASCIIDOC_CONF) \
		-ashit_version=$(shit_VERSION) $^

$(shit_CONTACTS_HTML): $(shit_CONTACTS_TXT)
	$(ASCIIDOC) -b xhtml11 -d manpage -f $(ASCIIDOC_CONF) \
		-ashit_version=$(shit_VERSION) $^

clean:
	$(RM) $(shit_CONTACTS)
	$(RM) *.xml *.html *.1

.PHONY: FORCE
