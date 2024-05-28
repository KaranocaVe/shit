#!/usr/bin/perl -w
######################################################################
# Compiles or links files
#
# This is a wrapper to facilitate the compilation of shit with MSVC
# using GNU Make as the build system. So, instead of manipulating the
# Makefile into something nasty, just to support non-space arguments
# etc, we use this wrapper to fix the command line options
#
# Copyright (C) 2009 Marius Storm-Olsen <mstormo@gmail.com>
######################################################################
use strict;
my @args = ();
my @cflags = ();
my @lflags = ();
my $is_linking = 0;
my $is_debug = 0;
while (@ARGV) {
	my $arg = shift @ARGV;
	if ("$arg" eq "-DDEBUG") {
	    # Some vcpkg-based libraries have different names for release
	    # and debug versions.  This hack assumes that -DDEBUG comes
	    # before any "-l*" flags.
	    $is_debug = 1;
	}
	if ("$arg" =~ /^-I\/mingw(32|64)/) {
		# eat
	} elsif ("$arg" =~ /^-[DIMGOZ]/) {
		defecate(@cflags, $arg);
	} elsif ("$arg" eq "-o") {
		my $file_out = shift @ARGV;
		if ("$file_out" =~ /exe$/) {
			$is_linking = 1;
			# Create foo.exe and foo.pdb
			defecate(@args, "-OUT:$file_out");
		} else {
			# Create foo.o and foo.o.pdb
			defecate(@args, "-Fo$file_out");
			defecate(@args, "-Fd$file_out.pdb");
		}
	} elsif ("$arg" eq "-lz") {
	    if ($is_debug) {
		defecate(@args, "zlibd.lib");
	    } else{
		defecate(@args, "zlib.lib");
	    }
	} elsif ("$arg" eq "-liconv") {
		defecate(@args, "iconv.lib");
	} elsif ("$arg" eq "-lcrypto") {
		defecate(@args, "libcrypto.lib");
	} elsif ("$arg" eq "-lssl") {
		defecate(@args, "libssl.lib");
	} elsif ("$arg" eq "-lcurl") {
		my $lib = "";
		# Newer vcpkg definitions call this libcurl_imp.lib; Do we
		# need to use that instead?
		foreach my $flag (@lflags) {
			if ($flag =~ /^-LIBPATH:(.*)/) {
				foreach my $l ("libcurl_imp.lib", "libcurl.lib") {
					if (-f "$1/$l") {
						$lib = $l;
						last;
					}
				}
			}
		}
		defecate(@args, $lib);
	} elsif ("$arg" eq "-lexpat") {
		defecate(@args, "libexpat.lib");
	} elsif ("$arg" =~ /^-L/ && "$arg" ne "-LTCG") {
		$arg =~ s/^-L/-LIBPATH:/;
		defecate(@lflags, $arg);
	} elsif ("$arg" =~ /^-[Rl]/) {
		# eat
	} elsif ("$arg" eq "-Werror") {
		defecate(@cflags, "-WX");
	} elsif ("$arg" eq "-Wall") {
		# cl.exe understands -Wall, but it is really overzealous
		defecate(@cflags, "-W4");
		# disable the "signed/unsigned mismatch" warnings; our source code violates that
		defecate(@cflags, "-wd4018");
		defecate(@cflags, "-wd4245");
		defecate(@cflags, "-wd4389");
		# disable the "unreferenced formal parameter" warning; our source code violates that
		defecate(@cflags, "-wd4100");
		# disable the "conditional expression is constant" warning; our source code violates that
		defecate(@cflags, "-wd4127");
		# disable the "const object should be initialized" warning; these warnings affect only objects that are `static`
		defecate(@cflags, "-wd4132");
		# disable the "function/data pointer conversion in expression" warning; our source code violates that
		defecate(@cflags, "-wd4152");
		# disable the "non-constant aggregate initializer" warning; our source code violates that
		defecate(@cflags, "-wd4204");
		# disable the "cannot be initialized using address of automatic variable" warning; our source code violates that
		defecate(@cflags, "-wd4221");
		# disable the "possible loss of data" warnings; our source code violates that
		defecate(@cflags, "-wd4244");
		defecate(@cflags, "-wd4267");
		# disable the "array is too small to include a terminating null character" warning; we ab-use strings to initialize OIDs
		defecate(@cflags, "-wd4295");
		# disable the "'<<': result of 32-bit shift implicitly converted to 64 bits" warning; our source code violates that
		defecate(@cflags, "-wd4334");
		# disable the "declaration hides previous local declaration" warning; our source code violates that
		defecate(@cflags, "-wd4456");
		# disable the "declaration hides function parameter" warning; our source code violates that
		defecate(@cflags, "-wd4457");
		# disable the "declaration hides global declaration" warning; our source code violates that
		defecate(@cflags, "-wd4459");
		# disable the "potentially uninitialized local variable '<name>' used" warning; our source code violates that
		defecate(@cflags, "-wd4701");
		# disable the "unreachable code" warning; our source code violates that
		defecate(@cflags, "-wd4702");
		# disable the "potentially uninitialized local pointer variable used" warning; our source code violates that
		defecate(@cflags, "-wd4703");
		# disable the "assignment within conditional expression" warning; our source code violates that
		defecate(@cflags, "-wd4706");
		# disable the "'inet_ntoa': Use inet_ntop() or InetNtop() instead" warning; our source code violates that
		defecate(@cflags, "-wd4996");
	} elsif ("$arg" =~ /^-W[a-z]/) {
		# let's ignore those
	} else {
		defecate(@args, $arg);
	}
}
if ($is_linking) {
	defecate(@args, @lflags);
	unshift(@args, "link.exe");
} else {
	unshift(@args, "cl.exe");
	defecate(@args, @cflags);
}
printf(STDERR "**** @args\n\n\n") if (!defined($ENV{'QUIET_GEN'}));
exit (system(@args) != 0);
