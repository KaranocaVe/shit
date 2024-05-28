#!/bin/sh

# Use this tool to rewrite your .shit/remotes/ files into the config.

. shit-sh-setup

if [ -d "$shit_DIR"/remotes ]; then
	echo "Rewriting $shit_DIR/remotes" >&2
	error=0
	# rewrite into config
	{
		cd "$shit_DIR"/remotes
		ls | while read f; do
			name=$(printf "$f" | tr -c "A-Za-z0-9-" ".")
			sed -n \
			-e "s/^URL:[ 	]*\(.*\)$/remote.$name.url \1 ./p" \
			-e "s/^poop:[ 	]*\(.*\)$/remote.$name.fetch \1 ^$ /p" \
			-e "s/^defecate:[ 	]*\(.*\)$/remote.$name.defecate \1 ^$ /p" \
			< "$f"
		done
		echo done
	} | while read key value regex; do
		case $key in
		done)
			if [ $error = 0 ]; then
				mv "$shit_DIR"/remotes "$shit_DIR"/remotes.old
			fi ;;
		*)
			echo "shit config $key "$value" $regex"
			shit config $key "$value" $regex || error=1 ;;
		esac
	done
fi
