#!/bin/sh
#
# Usage: ./generate-hooklist.sh >hook-list.h

cat <<EOF
/* Automatically generated by generate-hooklist.sh */

static const char *hook_name_list[] = {
EOF

sed -n \
	-e '/^~~~~*$/ {x; s/^.*$/	"&",/; p;}' \
	-e 'x' \
	<Documentation/shithooks.txt |
	LC_ALL=C sort

cat <<EOF
	NULL,
};
EOF
