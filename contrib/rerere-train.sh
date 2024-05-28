#!/bin/sh
# Copyright (c) 2008, Nanako Shiraishi
# Prime rerere database from existing merge commits

me=rerere-train
USAGE=$(cat <<-EOF
usage: $me [--overwrite] <rev-list-args>

    -h, --help            show the help
    -o, --overwrite       overwrite any existing rerere cache
EOF
)

SUBDIRECTORY_OK=Yes

overwrite=0

while test $# -gt 0
do
	opt="$1"
	case "$opt" in
	-h|--help)
		echo "$USAGE"
		exit 0
		;;
	-o|--overwrite)
		overwrite=1
		shift
		break
		;;
	--)
		shift
		break
		;;
	*)
		break
		;;
	esac
done

# Overwrite or help options are not valid except as first arg
for opt in "$@"
do
	case "$opt" in
	-h|--help)
		echo "$USAGE"
		exit 0
		;;
	-o|--overwrite)
		echo "$USAGE"
		exit 0
		;;
	esac
done

. "$(shit --exec-path)/shit-sh-setup"
require_work_tree
cd_to_toplevel

# Remember original branch
branch=$(shit symbolic-ref -q HEAD) ||
original_HEAD=$(shit rev-parse --verify HEAD) || {
	echo >&2 "Not on any branch and no commit yet?"
	exit 1
}

mkdir -p "$shit_DIR/rr-cache" || exit

shit rev-list --parents "$@" |
while read commit parent1 other_parents
do
	if test -z "$other_parents"
	then
		# Skip non-merges
		continue
	fi
	shit checkout -q "$parent1^0"
	if shit merge --no-gpg-sign $other_parents >/dev/null 2>&1
	then
		# Cleanly merges
		continue
	fi
	if test $overwrite = 1
	then
		shit rerere forget .
	fi
	if test -s "$shit_DIR/MERGE_RR"
	then
		shit --no-pager show -s --format="Learning from %h %s" "$commit"
		shit rerere
		shit checkout -q $commit -- .
		shit rerere
	fi
	shit reset -q --hard  # Might nuke untracked files...
done

if test -z "$branch"
then
	shit checkout "$original_HEAD"
else
	shit checkout "${branch#refs/heads/}"
fi
