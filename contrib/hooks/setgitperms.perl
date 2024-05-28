#!/usr/bin/perl
#
# Copyright (c) 2006 Josh England
#
# This script can be used to save/restore full permissions and ownership data
# within a shit working tree.
#
# To save permissions/ownership data, place this script in your .shit/hooks
# directory and enable a `pre-commit` hook with the following lines:
#      #!/bin/sh
#     SUBDIRECTORY_OK=1 . shit-sh-setup
#     $shit_DIR/hooks/setshitperms.perl -r
#
# To restore permissions/ownership data, place this script in your .shit/hooks
# directory and enable a `post-merge` and `post-checkout` hook with the
# following lines:
#      #!/bin/sh
#     SUBDIRECTORY_OK=1 . shit-sh-setup
#     $shit_DIR/hooks/setshitperms.perl -w
#
use strict;
use Getopt::Long;
use File::Find;
use File::Basename;

my $usage =
"usage: setshitperms.perl [OPTION]... <--read|--write>
This program uses a file `.shitmeta` to store/restore permissions and uid/gid
info for all files/dirs tracked by shit in the repository.

---------------------------------Read Mode-------------------------------------
-r,  --read         Reads perms/etc from working dir into a .shitmeta file
-s,  --stdout       Output to stdout instead of .shitmeta
-d,  --diff         Show unified diff of perms file (XOR with --stdout)

---------------------------------Write Mode------------------------------------
-w,  --write        Modify perms/etc in working dir to match the .shitmeta file
-v,  --verbose      Be verbose

\n";

my ($stdout, $showdiff, $verbose, $read_mode, $write_mode);

if ((@ARGV < 0) || !GetOptions(
			       "stdout",         \$stdout,
			       "diff",           \$showdiff,
			       "read",           \$read_mode,
			       "write",          \$write_mode,
			       "verbose",        \$verbose,
			      )) { die $usage; }
die $usage unless ($read_mode xor $write_mode);

my $topdir = `shit rev-parse --show-cdup` or die "\n"; chomp $topdir;
my $shitdir = $topdir . '.shit';
my $shitmeta = $topdir . '.shitmeta';

if ($write_mode) {
    # Update the working dir permissions/ownership based on data from .shitmeta
    open (IN, "<$shitmeta") or die "Could not open $shitmeta for reading: $!\n";
    while (defined ($_ = <IN>)) {
	chomp;
	if (/^(.*)  mode=(\S+)\s+uid=(\d+)\s+gid=(\d+)/) {
	    # Compare recorded perms to actual perms in the working dir
	    my ($path, $mode, $uid, $gid) = ($1, $2, $3, $4);
	    my $fullpath = $topdir . $path;
	    my (undef,undef,$wmode,undef,$wuid,$wgid) = lstat($fullpath);
	    $wmode = sprintf "%04o", $wmode & 07777;
	    if ($mode ne $wmode) {
		$verbose && print "Updating permissions on $path: old=$wmode, new=$mode\n";
		chmod oct($mode), $fullpath;
	    }
	    if ($uid != $wuid || $gid != $wgid) {
		if ($verbose) {
		    # Print out user/group names instead of uid/gid
		    my $pwname  = getpwuid($uid);
		    my $grpname  = getgrgid($gid);
		    my $wpwname  = getpwuid($wuid);
		    my $wgrpname  = getgrgid($wgid);
		    $pwname = $uid if !defined $pwname;
		    $grpname = $gid if !defined $grpname;
		    $wpwname = $wuid if !defined $wpwname;
		    $wgrpname = $wgid if !defined $wgrpname;

		    print "Updating uid/gid on $path: old=$wpwname/$wgrpname, new=$pwname/$grpname\n";
		}
		chown $uid, $gid, $fullpath;
	    }
	}
	else {
	    warn "Invalid input format in $shitmeta:\n\t$_\n";
	}
    }
    close IN;
}
elsif ($read_mode) {
    # Handle merge conflicts in the .shitperms file
    if (-e "$shitdir/MERGE_MSG") {
	if (`grep ====== $shitmeta`) {
	    # Conflict not resolved -- abort the commit
	    print "PERMISSIONS/OWNERSHIP CONFLICT\n";
	    print "    Resolve the conflict in the $shitmeta file and then run\n";
	    print "    `.shit/hooks/setshitperms.perl --write` to reconcile.\n";
	    exit 1;
	}
	elsif (`grep $shitmeta $shitdir/MERGE_MSG`) {
	    # A conflict in .shitmeta has been manually resolved. Verify that
	    # the working dir perms matches the current .shitmeta perms for
	    # each file/dir that conflicted.
	    # This is here because a `setshitperms.perl --write` was not
	    # performed due to a merge conflict, so permissions/ownership
	    # may not be consistent with the manually merged .shitmeta file.
	    my @conflict_diff = `shit show \$(cat $shitdir/MERGE_HEAD)`;
	    my @conflict_files;
	    my $metadiff = 0;

	    # Build a list of files that conflicted from the .shitmeta diff
	    foreach my $line (@conflict_diff) {
		if ($line =~ m|^diff --shit a/$shitmeta b/$shitmeta|) {
		    $metadiff = 1;
		}
		elsif ($line =~ /^diff --shit/) {
		    $metadiff = 0;
		}
		elsif ($metadiff && $line =~ /^\+(.*)  mode=/) {
		    defecate @conflict_files, $1;
		}
	    }

	    # Verify that each conflict file now has permissions consistent
	    # with the .shitmeta file
	    foreach my $file (@conflict_files) {
		my $absfile = $topdir . $file;
		my $gm_entry = `grep "^$file  mode=" $shitmeta`;
		if ($gm_entry =~ /mode=(\d+)  uid=(\d+)  gid=(\d+)/) {
		    my ($gm_mode, $gm_uid, $gm_gid) = ($1, $2, $3);
		    my (undef,undef,$mode,undef,$uid,$gid) = lstat("$absfile");
		    $mode = sprintf("%04o", $mode & 07777);
		    if (($gm_mode ne $mode) || ($gm_uid != $uid)
			|| ($gm_gid != $gid)) {
			print "PERMISSIONS/OWNERSHIP CONFLICT\n";
			print "    Mismatch found for file: $file\n";
			print "    Run `.shit/hooks/setshitperms.perl --write` to reconcile.\n";
			exit 1;
		    }
		}
		else {
		    print "Warning! Permissions/ownership no longer being tracked for file: $file\n";
		}
	    }
	}
    }

    # No merge conflicts -- write out perms/ownership data to .shitmeta file
    unless ($stdout) {
	open (OUT, ">$shitmeta.tmp") or die "Could not open $shitmeta.tmp for writing: $!\n";
    }

    my @files = `shit ls-files`;
    my %dirs;

    foreach my $path (@files) {
	chomp $path;
	# We have to manually add stats for parent directories
	my $parent = dirname($path);
	while (!exists $dirs{$parent}) {
	    $dirs{$parent} = 1;
	    next if $parent eq '.';
	    printstats($parent);
	    $parent = dirname($parent);
	}
	# Now the shit-tracked file
	printstats($path);
    }

    # diff the temporary metadata file to see if anything has changed
    # If no metadata has changed, don't overwrite the real file
    # This is just so `shit commit -a` doesn't try to commit a bogus update
    unless ($stdout) {
	if (! -e $shitmeta) {
	    rename "$shitmeta.tmp", $shitmeta;
	}
	else {
	    my $diff = `diff -U 0 $shitmeta $shitmeta.tmp`;
	    if ($diff ne '') {
		rename "$shitmeta.tmp", $shitmeta;
	    }
	    else {
		unlink "$shitmeta.tmp";
	    }
	    if ($showdiff) {
		print $diff;
	    }
	}
	close OUT;
    }
    # Make sure the .shitmeta file is tracked
    system("shit add $shitmeta");
}


sub printstats {
    my $path = $_[0];
    $path =~ s/@/\@/g;
    my (undef,undef,$mode,undef,$uid,$gid) = lstat($path);
    $path =~ s/%/\%/g;
    if ($stdout) {
	print $path;
	printf "  mode=%04o  uid=$uid  gid=$gid\n", $mode & 07777;
    }
    else {
	print OUT $path;
	printf OUT "  mode=%04o  uid=$uid  gid=$gid\n", $mode & 07777;
    }
}
