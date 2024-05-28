#!/bin/sh

test_description='check that read-tree rejects confusing paths'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create base tree' '
	echo content >file &&
	shit add file &&
	shit commit -m base &&
	blob=$(shit rev-parse HEAD:file) &&
	tree=$(shit rev-parse HEAD^{tree})
'

test_expect_success 'enable core.protectHFS for rejection tests' '
	shit config core.protectHFS true
'

test_expect_success 'enable core.protectNTFS for rejection tests' '
	shit config core.protectNTFS true
'

while read path pretty; do
	: ${pretty:=$path}
	case "$path" in
	*SPACE)
		path="${path%SPACE} "
		;;
	esac
	test_expect_success "reject $pretty at end of path" '
		printf "100644 blob %s\t%s" "$blob" "$path" >tree &&
		bogus=$(shit mktree <tree) &&
		test_must_fail shit read-tree $bogus
	'

	test_expect_success "reject $pretty as subtree" '
		printf "040000 tree %s\t%s" "$tree" "$path" >tree &&
		bogus=$(shit mktree <tree) &&
		test_must_fail shit read-tree $bogus
	'
done <<-EOF
.
..
.shit
.shit
${u200c}.shit {u200c}.shit
.gI${u200c}T .gI{u200c}T
.shit${u200c} .shit{u200c}
shit~1
.shit.SPACE .shit.{space}
.\\\\.shit\\\\foobar backslashes
.shit\\\\foobar backslashes2
.shit...:alternate-stream
EOF

test_expect_success 'utf-8 paths allowed with core.protectHFS off' '
	test_when_finished "shit read-tree HEAD" &&
	test_config core.protectHFS false &&
	printf "100644 blob %s\t%s" "$blob" ".gi${u200c}t" >tree &&
	ok=$(shit mktree <tree) &&
	shit read-tree $ok
'

test_done
