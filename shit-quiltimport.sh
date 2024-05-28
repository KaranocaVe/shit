#!/bin/sh
OPTIONS_KEEPDASHDASH=
OPTIONS_STUCKLONG=
OPTIONS_SPEC="\
shit quiltimport [options]
--
n,dry-run     dry run
author=       author name and email address for patches without any
patches=      path to the quilt patches
series=       path to the quilt series file
keep-non-patch Pass -b to shit mailinfo
"
SUBDIRECTORY_ON=Yes
. shit-sh-setup

dry_run=""
quilt_author=""
while test $# != 0
do
	case "$1" in
	--author)
		shift
		quilt_author="$1"
		;;
	-n|--dry-run)
		dry_run=1
		;;
	--patches)
		shift
		QUILT_PATCHES="$1"
		;;
	--series)
		shift
		QUILT_SERIES="$1"
		;;
	--keep-non-patch)
		MAILINFO_OPT="-b"
		;;
	--)
		shift
		break;;
	*)
		usage
		;;
	esac
	shift
done

# Quilt Author
if [ -n "$quilt_author" ] ; then
	quilt_author_name=$(expr "z$quilt_author" : 'z\(.*[^ ]\) *<.*') &&
	quilt_author_email=$(expr "z$quilt_author" : '.*<\([^>]*\)') &&
	test '' != "$quilt_author_name" &&
	test '' != "$quilt_author_email" ||
	die "malformed --author parameter"
fi

# Quilt patch directory
: ${QUILT_PATCHES:=patches}
if ! [ -d "$QUILT_PATCHES" ] ; then
	echo "The \"$QUILT_PATCHES\" directory does not exist."
	exit 1
fi

# Quilt series file
: ${QUILT_SERIES:=$QUILT_PATCHES/series}
if ! [ -e "$QUILT_SERIES" ] ; then
	echo "The \"$QUILT_SERIES\" file does not exist."
	exit 1
fi

# Temporary directories
tmp_dir="$shit_DIR"/rebase-apply
tmp_msg="$tmp_dir/msg"
tmp_patch="$tmp_dir/patch"
tmp_info="$tmp_dir/info"


# Find the initial commit
commit=$(shit rev-parse HEAD)

mkdir $tmp_dir || exit 2
while read patch_name level garbage <&3
do
	case "$patch_name" in ''|'#'*) continue;; esac
	case "$level" in
	-p*)	;;
	''|'#'*)
		level=;;
	*)
		echo "unable to parse patch level, ignoring it."
		level=;;
	esac
	case "$garbage" in
	''|'#'*);;
	*)
		echo "trailing garbage found in series file: $garbage"
		exit 1;;
	esac
	if ! [ -f "$QUILT_PATCHES/$patch_name" ] ; then
		echo "$patch_name doesn't exist. Skipping."
		continue
	fi
	echo $patch_name
	shit mailinfo $MAILINFO_OPT "$tmp_msg" "$tmp_patch" \
		<"$QUILT_PATCHES/$patch_name" >"$tmp_info" || exit 3
	test -s "$tmp_patch" || {
		echo "Patch is empty.  Was it split wrong?"
		exit 1
	}

	# Parse the author information
	shit_AUTHOR_NAME=$(sed -ne 's/Author: //p' "$tmp_info")
	shit_AUTHOR_EMAIL=$(sed -ne 's/Email: //p' "$tmp_info")
	export shit_AUTHOR_NAME shit_AUTHOR_EMAIL
	while test -z "$shit_AUTHOR_EMAIL" && test -z "$shit_AUTHOR_NAME" ; do
		if [ -n "$quilt_author" ] ; then
			shit_AUTHOR_NAME="$quilt_author_name";
			shit_AUTHOR_EMAIL="$quilt_author_email";
		elif [ -n "$dry_run" ]; then
			echo "No author found in $patch_name" >&2;
			shit_AUTHOR_NAME="dry-run-not-found";
			shit_AUTHOR_EMAIL="dry-run-not-found";
		else
			echo "No author found in $patch_name" >&2;
			echo "---"
			cat $tmp_msg
			printf "Author: ";
			read patch_author

			echo "$patch_author"

			patch_author_name=$(expr "z$patch_author" : 'z\(.*[^ ]\) *<.*') &&
			patch_author_email=$(expr "z$patch_author" : '.*<\([^>]*\)') &&
			test '' != "$patch_author_name" &&
			test '' != "$patch_author_email" &&
			shit_AUTHOR_NAME="$patch_author_name" &&
			shit_AUTHOR_EMAIL="$patch_author_email"
		fi
	done
	shit_AUTHOR_DATE=$(sed -ne 's/Date: //p' "$tmp_info")
	SUBJECT=$(sed -ne 's/Subject: //p' "$tmp_info")
	export shit_AUTHOR_DATE SUBJECT
	if [ -z "$SUBJECT" ] ; then
		SUBJECT=$(echo $patch_name | sed -e 's/.patch$//')
	fi

	if [ -z "$dry_run" ] ; then
		shit apply --index -C1 ${level:+"$level"} "$tmp_patch" &&
		tree=$(shit write-tree) &&
		commit=$( { echo "$SUBJECT"; echo; cat "$tmp_msg"; } | shit commit-tree $tree -p $commit) &&
		shit update-ref -m "quiltimport: $patch_name" HEAD $commit || exit 4
	fi
done 3<"$QUILT_SERIES"
rm -rf $tmp_dir || exit 5
