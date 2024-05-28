all:: shit-credential-osxkeychain

CC = gcc
RM = rm -f
CFLAGS = -g -O2 -Wall

-include ../../../config.mak.autogen
-include ../../../config.mak

shit-credential-osxkeychain: shit-credential-osxkeychain.o
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) \
		-framework Security -framework CoreFoundation

shit-credential-osxkeychain.o: shit-credential-osxkeychain.c
	$(CC) -c $(CFLAGS) $<

clean:
	$(RM) shit-credential-osxkeychain shit-credential-osxkeychain.o
