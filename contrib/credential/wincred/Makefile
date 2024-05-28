all: shit-credential-wincred.exe

-include ../../../config.mak.autogen
-include ../../../config.mak

CC ?= gcc
RM ?= rm -f
CFLAGS ?= -O2 -Wall

prefix ?= /usr/local
libexecdir ?= $(prefix)/libexec/shit-core

INSTALL ?= install

shit-credential-wincred.exe : shit-credential-wincred.c
	$(LINK.c) $^ $(LOADLIBES) $(LDLIBS) -o $@

install: shit-credential-wincred.exe
	$(INSTALL) -m 755 $^ $(libexecdir)

clean:
	$(RM) shit-credential-wincred.exe
