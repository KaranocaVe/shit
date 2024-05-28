#!/bin/sh

test_description='Test reflog display routines'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo content >file &&
	shit add file &&
	test_tick &&
	shit commit -m one
'

commit=$(shit rev-parse --short HEAD)
cat >expect <<'EOF'
Reflog: HEAD@{0} (C O Mitter <committer@example.com>)
Reflog message: commit (initial): one
EOF
test_expect_success 'log -g shows reflog headers' '
	shit log -g -1 >tmp &&
	grep ^Reflog <tmp >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
$commit HEAD@{0}: commit (initial): one
EOF
test_expect_success 'oneline reflog format' '
	shit log -g -1 --oneline >actual &&
	test_cmp expect actual
'

test_expect_success 'reflog default format' '
	shit reflog -1 >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
commit $commit
Reflog: HEAD@{0} (C O Mitter <committer@example.com>)
Reflog message: commit (initial): one
Author: A U Thor <author@example.com>

    one
EOF
test_expect_success 'override reflog default format' '
	shit reflog --format=short -1 >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
Reflog: HEAD@{Thu Apr 7 15:13:13 2005 -0700} (C O Mitter <committer@example.com>)
Reflog message: commit (initial): one
EOF
test_expect_success 'using @{now} syntax shows reflog date (multiline)' '
	shit log -g -1 HEAD@{now} >tmp &&
	grep ^Reflog <tmp >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
$commit HEAD@{Thu Apr 7 15:13:13 2005 -0700}: commit (initial): one
EOF
test_expect_success 'using @{now} syntax shows reflog date (oneline)' '
	shit log -g -1 --oneline HEAD@{now} >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
HEAD@{Thu Apr 7 15:13:13 2005 -0700}
EOF
test_expect_success 'using @{now} syntax shows reflog date (format=%gd)' '
	shit log -g -1 --format=%gd HEAD@{now} >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
Reflog: HEAD@{Thu Apr 7 15:13:13 2005 -0700} (C O Mitter <committer@example.com>)
Reflog message: commit (initial): one
EOF
test_expect_success 'using --date= shows reflog date (multiline)' '
	shit log -g -1 --date=default >tmp &&
	grep ^Reflog <tmp >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
$commit HEAD@{Thu Apr 7 15:13:13 2005 -0700}: commit (initial): one
EOF
test_expect_success 'using --date= shows reflog date (oneline)' '
	shit log -g -1 --oneline --date=default >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
HEAD@{1112911993 -0700}
EOF
test_expect_success 'using --date= shows reflog date (format=%gd)' '
	shit log -g -1 --format=%gd --date=raw >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
Reflog: HEAD@{0} (C O Mitter <committer@example.com>)
Reflog message: commit (initial): one
EOF
test_expect_success 'log.date does not invoke "--date" magic (multiline)' '
	test_config log.date raw &&
	shit log -g -1 >tmp &&
	grep ^Reflog <tmp >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
$commit HEAD@{0}: commit (initial): one
EOF
test_expect_success 'log.date does not invoke "--date" magic (oneline)' '
	test_config log.date raw &&
	shit log -g -1 --oneline >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
HEAD@{0}
EOF
test_expect_success 'log.date does not invoke "--date" magic (format=%gd)' '
	test_config log.date raw &&
	shit log -g -1 --format=%gd >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
HEAD@{0}
EOF
test_expect_success '--date magic does not override explicit @{0} syntax' '
	shit log -g -1 --format=%gd --date=raw HEAD@{0} >actual &&
	test_cmp expect actual
'

test_expect_success 'empty reflog file' '
	shit branch empty &&
	shit reflog expire --expire=all refs/heads/empty &&

	shit log -g empty >actual &&
	test_must_be_empty actual
'

# This guards against the alternative of showing the diffs vs. the
# reflog ancestor.  The reflog used is designed to list the commits
# more than once, so as to exercise the corresponding logic.
test_expect_success 'shit log -g -p shows diffs vs. parents' '
	test_commit two &&
	shit branch flipflop &&
	shit update-ref refs/heads/flipflop -m flip1 HEAD^ &&
	shit update-ref refs/heads/flipflop -m flop1 HEAD &&
	shit update-ref refs/heads/flipflop -m flip2 HEAD^ &&
	shit log -g -p flipflop >reflog &&
	grep -v ^Reflog reflog >actual &&
	shit log -1 -p HEAD^ >log.one &&
	shit log -1 -p HEAD >log.two &&
	(
		cat log.one && echo &&
		cat log.two && echo &&
		cat log.one && echo &&
		cat log.two
	) >expect &&
	test_cmp expect actual
'

test_done
