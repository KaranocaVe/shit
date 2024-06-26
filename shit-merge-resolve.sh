#!/bin/sh
#
# Copyright (c) 2005 Linus Torvalds
# Copyright (c) 2005 Junio C Hamano
#
# Resolve two trees, using enhanced multi-base read-tree.

. shit-sh-setup

# Abort if index does not match HEAD
if ! shit diff-index --quiet --cached HEAD --
then
    gettextln "Error: Your local changes to the following files would be overwritten by merge"
    shit diff-index --cached --name-only HEAD -- | sed -e 's/^/    /'
    exit 2
fi

# The first parameters up to -- are merge bases; the rest are heads.
bases= head= remotes= sep_seen=
for arg
do
	case ",$sep_seen,$head,$arg," in
	*,--,)
		sep_seen=yes
		;;
	,yes,,*)
		head=$arg
		;;
	,yes,*)
		remotes="$remotes$arg "
		;;
	*)
		bases="$bases$arg "
		;;
	esac
done

# Give up if we are given two or more remotes -- not handling octopus.
case "$remotes" in
?*' '?*)
	exit 2 ;;
esac

# Give up if this is a baseless merge.
if test '' = "$bases"
then
	exit 2
fi

shit update-index -q --refresh
shit read-tree -u -m --aggressive $bases $head $remotes || exit 2
echo "Trying simple merge."
if result_tree=$(shit write-tree 2>/dev/null)
then
	exit 0
else
	echo "Simple merge failed, trying Automatic merge."
	if shit merge-index -o shit-merge-one-file -a
	then
		exit 0
	else
		exit 1
	fi
fi
