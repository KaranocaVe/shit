#!/bin/sh
# This requires shit-manpages and/or shit-htmldocs repositories

repository=${1?repository}
destdir=${2?destination}
shit_MAN_REF=${3?master}

shit_DIR=
for d in "$repository/.shit" "$repository"
do
	if shit_DIR="$d" shit rev-parse "$shit_MAN_REF" >/dev/null 2>&1
	then
		shit_DIR="$d"
		export shit_DIR
		break
	fi
done

if test -z "$shit_DIR"
then
	echo >&2 "Neither $repository nor $repository/.shit is a repository"
	exit 1
fi

shit_WORK_TREE=$(pwd)
shit_INDEX_FILE=$(pwd)/.quick-doc.$$
export shit_INDEX_FILE shit_WORK_TREE
rm -f "$shit_INDEX_FILE"
trap 'rm -f "$shit_INDEX_FILE"' 0

shit read-tree "$shit_MAN_REF"
shit checkout-index -a -f --prefix="$destdir"/

if test -n "$GZ"
then
	shit ls-tree -r --name-only "$shit_MAN_REF" |
	xargs printf "$destdir/%s\n" |
	xargs gzip -f
fi
rm -f "$shit_INDEX_FILE"
