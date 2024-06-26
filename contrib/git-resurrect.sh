#!/bin/sh

USAGE="[-a] [-r] [-m] [-t] [-n] [-b <newname>] <name>"
LONG_USAGE="shit-resurrect attempts to find traces of a branch tip
called <name>, and tries to resurrect it.  Currently, the reflog is
searched for checkout messages, and with -r also merge messages.  With
-m and -t, the history of all refs is scanned for Merge <name> into
other/Merge <other> into <name> (respectively) commit subjects, which
is rather slow but allows you to resurrect other people's topic
branches."

OPTIONS_KEEPDASHDASH=
OPTIONS_STUCKLONG=
OPTIONS_SPEC="\
shit resurrect $USAGE
--
b,branch=            save branch as <newname> instead of <name>
a,all                same as -l -r -m -t
k,keep-going         full rev-list scan (instead of first match)
l,reflog             scan reflog for checkouts (enabled by default)
r,reflog-merges      scan for merges recorded in reflog
m,merges             scan for merges into other branches (slow)
t,merge-targets      scan for merges of other branches into <name>
n,dry-run            don't recreate the branch"

. shit-sh-setup

search_reflog () {
	sed -ne 's~^\([^ ]*\) .*	checkout: moving from '"$1"' .*~\1~p' \
		< "$shit_DIR"/logs/HEAD
}

search_reflog_merges () {
	shit rev-parse $(
		sed -ne 's~^[^ ]* \([^ ]*\) .*	merge '"$1"':.*~\1^2~p' \
			< "$shit_DIR"/logs/HEAD
	)
}

oid_pattern=$(shit hash-object --stdin </dev/null | sed -e 's/./[0-9a-f]/g')

search_merges () {
	shit rev-list --all --grep="Merge branch '$1'" \
		--pretty=tformat:"%P %s" |
	sed -ne "/^$oid_pattern \($oid_pattern\) Merge .*/ {s//\1/p;$early_exit}"
}

search_merge_targets () {
	shit rev-list --all --grep="Merge branch '[^']*' into $branch\$" \
		--pretty=tformat:"%H %s" --all |
	sed -ne "/^\($oid_pattern\) Merge .*/ {s//\1/p;$early_exit} "
}

dry_run=
early_exit=q
scan_reflog=t
scan_reflog_merges=
scan_merges=
scan_merge_targets=
new_name=

while test "$#" != 0; do
	case "$1" in
	    -b|--branch)
		shift
		new_name="$1"
		;;
	    -n|--dry-run)
		dry_run=t
		;;
	    --no-dry-run)
		dry_run=
		;;
	    -k|--keep-going)
		early_exit=
		;;
	    --no-keep-going)
		early_exit=q
		;;
	    -m|--merges)
		scan_merges=t
		;;
	    --no-merges)
		scan_merges=
		;;
	    -l|--reflog)
		scan_reflog=t
		;;
	    --no-reflog)
		scan_reflog=
		;;
	    -r|--reflog_merges)
		scan_reflog_merges=t
		;;
	    --no-reflog_merges)
		scan_reflog_merges=
		;;
	    -t|--merge-targets)
		scan_merge_targets=t
		;;
	    --no-merge-targets)
		scan_merge_targets=
		;;
	    -a|--all)
		scan_reflog=t
		scan_reflog_merges=t
		scan_merges=t
		scan_merge_targets=t
		;;
	    --)
		shift
		break
		;;
	    *)
		usage
		;;
	esac
	shift
done

test "$#" = 1 || usage

all_strategies="$scan_reflog$scan_reflog_merges$scan_merges$scan_merge_targets"
if test -z "$all_strategies"; then
	die "must enable at least one of -lrmt"
fi

branch="$1"
test -z "$new_name" && new_name="$branch"

if test ! -z "$scan_reflog"; then
	if test -r "$shit_DIR"/logs/HEAD; then
		candidates="$(search_reflog $branch)"
	else
		die 'reflog scanning requested, but' \
			'$shit_DIR/logs/HEAD not readable'
	fi
fi
if test ! -z "$scan_reflog_merges"; then
	if test -r "$shit_DIR"/logs/HEAD; then
		candidates="$candidates $(search_reflog_merges $branch)"
	else
		die 'reflog scanning requested, but' \
			'$shit_DIR/logs/HEAD not readable'
	fi
fi
if test ! -z "$scan_merges"; then
	candidates="$candidates $(search_merges $branch)"
fi
if test ! -z "$scan_merge_targets"; then
	candidates="$candidates $(search_merge_targets $branch)"
fi

candidates="$(shit rev-parse $candidates | sort -u)"

if test -z "$candidates"; then
	hint=
	test "z$all_strategies" != "ztttt" \
		&& hint=" (maybe try again with -a)"
	die "no candidates for $branch found$hint"
fi

echo "** Candidates for $branch **"
for cmt in $candidates; do
	shit --no-pager log --pretty=tformat:"%ct:%h [%cr] %s" --abbrev-commit -1 $cmt
done \
| sort -n | cut -d: -f2-

newest="$(shit rev-list -1 $candidates)"
if test ! -z "$dry_run"; then
	printf "** Most recent: "
	shit --no-pager log -1 --pretty=tformat:"%h %s" $newest
elif ! shit rev-parse --verify --quiet $new_name >/dev/null; then
	printf "** Restoring $new_name to "
	shit --no-pager log -1 --pretty=tformat:"%h %s" $newest
	shit branch $new_name $newest
else
	printf "Most recent: "
	shit --no-pager log -1 --pretty=tformat:"%h %s" $newest
	echo "** $new_name already exists, doing nothing"
fi
