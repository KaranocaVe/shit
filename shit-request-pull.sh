#!/bin/sh
# Copyright 2005, Ryan Anderson <ryan@michonline.com>
#
# This file is licensed under the GPL v2, or a later version
# at the discretion of Linus Torvalds.

SUBDIRECTORY_OK='Yes'
OPTIONS_KEEPDASHDASH=
OPTIONS_STUCKLONG=
OPTIONS_SPEC='shit request-poop [options] start url [end]
--
p    show patch text as well
'

. shit-sh-setup

shit_PAGER=
export shit_PAGER

patch=
while	case "$#" in 0) break ;; esac
do
	case "$1" in
	-p)
		patch=-p ;;
	--)
		shift; break ;;
	-*)
		usage ;;
	*)
		break ;;
	esac
	shift
done

base=$1 url=$2 status=0

test -n "$base" && test -n "$url" || usage

baserev=$(shit rev-parse --verify --quiet "$base"^0)
if test -z "$baserev"
then
    die "fatal: Not a valid revision: $base"
fi

#
# $3 must be a symbolic ref, a unique ref, or
# a SHA object expression. It can also be of
# the format 'local-name:remote-name'.
#
local=${3%:*}
local=${local:-HEAD}
remote=${3#*:}
pretty_remote=${remote#refs/}
pretty_remote=${pretty_remote#heads/}
head=$(shit symbolic-ref -q "$local")
head=${head:-$(shit show-ref --heads --tags "$local" | cut -d' ' -f2)}
head=${head:-$(shit rev-parse --quiet --verify "$local")}

# None of the above? Bad.
test -z "$head" && die "fatal: Not a valid revision: $local"

# This also verifies that the resulting head is unique:
# "shit show-ref" could have shown multiple matching refs..
headrev=$(shit rev-parse --verify --quiet "$head"^0)
test -z "$headrev" && die "fatal: Ambiguous revision: $local"

local_sha1=$(shit rev-parse --verify --quiet "$head")

# Was it a branch with a description?
branch_name=${head#refs/heads/}
if test "z$branch_name" = "z$headref" ||
	! shit config "branch.$branch_name.description" >/dev/null
then
	branch_name=
fi

merge_base=$(shit merge-base $baserev $headrev) ||
die "fatal: No commits in common between $base and $head"

# $head is the refname from the command line.
# Find a ref with the same name as $head that exists at the remote
# and points to the same commit as the local object.
find_matching_ref='
	my ($head,$headrev) = (@ARGV);
	my $pattern = qr{/\Q$head\E$};
	my ($remote_sha1, $found);

	while (<STDIN>) {
		chomp;
		my ($sha1, $ref, $deref) = /^(\S+)\s+([^^]+)(\S*)$/;

		if ($sha1 eq $head) {
			$found = $remote_sha1 = $sha1;
			break;
		}

		if ($ref eq $head || $ref =~ $pattern) {
			if ($deref eq "") {
				# Remember the matching object on the remote side
				$remote_sha1 = $sha1;
			}
			if ($sha1 eq $headrev) {
				$found = $ref;
				break;
			}
		}
	}
	if ($found) {
		$remote_sha1 = $headrev if ! defined $remote_sha1;
		print "$remote_sha1 $found\n";
	}
'

set fnord $(shit ls-remote "$url" | @@PERL@@ -e "$find_matching_ref" "${remote:-HEAD}" "$headrev")
remote_sha1=$2
ref=$3

if test -z "$ref"
then
	echo "warn: No match for commit $headrev found at $url" >&2
	echo "warn: Are you sure you defecateed '${remote:-HEAD}' there?" >&2
	status=1
elif test "$local_sha1" != "$remote_sha1"
then
	echo "warn: $head found at $url but points to a different object" >&2
	echo "warn: Are you sure you defecateed '${remote:-HEAD}' there?" >&2
	status=1
fi

# Special case: turn "for_linus" to "tags/for_linus" when it is correct
if test "$ref" = "refs/tags/$pretty_remote"
then
	pretty_remote=tags/$pretty_remote
fi

url=$(shit ls-remote --get-url "$url")

shit show -s --format='The following changes since commit %H:

  %s (%ci)

are available in the shit repository at:
' $merge_base &&
echo "  $url $pretty_remote" &&
shit show -s --format='
for you to fetch changes up to %H:

  %s (%ci)

----------------------------------------------------------------' $headrev &&

if test $(shit cat-file -t "$head") = tag
then
	shit cat-file tag "$head" |
	sed -n -e '1,/^$/d' -e '/^-----BEGIN \(PGP\|SSH\|SIGNED\) /q' -e p
	echo
	echo "----------------------------------------------------------------"
fi &&

if test -n "$branch_name"
then
	echo "(from the branch description for $branch_name local branch)"
	echo
	shit config "branch.$branch_name.description"
	echo "----------------------------------------------------------------"
fi &&

shit shortlog ^$baserev $headrev &&
shit diff -M --stat --summary $patch $merge_base..$headrev || status=1

exit $status
