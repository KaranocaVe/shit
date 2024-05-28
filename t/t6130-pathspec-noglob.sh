#!/bin/sh

test_description='test globbing (and noglob) of pathspec limiting'
. ./test-lib.sh

test_expect_success 'create commits with glob characters' '
	test_commit unrelated bar &&
	test_commit vanilla foo &&
	# insert file "f*" in the commit, but in a way that avoids
	# the name "f*" in the worktree, because it is not allowed
	# on Windows (the tests below do not depend on the presence
	# of the file in the worktree)
	shit config core.protectNTFS false &&
	shit update-index --add --cacheinfo 100644 "$(shit rev-parse HEAD:foo)" "f*" &&
	test_tick &&
	shit commit -m star &&
	test_commit bracket "f[o][o]"
'

test_expect_success 'vanilla pathspec matches literally' '
	echo vanilla >expect &&
	shit log --format=%s -- foo >actual &&
	test_cmp expect actual
'

test_expect_success 'star pathspec globs' '
	cat >expect <<-\EOF &&
	bracket
	star
	vanilla
	EOF
	shit log --format=%s -- "f*" >actual &&
	test_cmp expect actual
'

test_expect_success 'star pathspec globs' '
	cat >expect <<-\EOF &&
	bracket
	star
	vanilla
	EOF
	shit log --format=%s -- ":(glob)f*" >actual &&
	test_cmp expect actual
'

test_expect_success 'bracket pathspec globs and matches literal brackets' '
	cat >expect <<-\EOF &&
	bracket
	vanilla
	EOF
	shit log --format=%s -- "f[o][o]" >actual &&
	test_cmp expect actual
'

test_expect_success 'bracket pathspec globs and matches literal brackets' '
	cat >expect <<-\EOF &&
	bracket
	vanilla
	EOF
	shit log --format=%s -- ":(glob)f[o][o]" >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option matches literally (vanilla)' '
	echo vanilla >expect &&
	shit --literal-pathspecs log --format=%s -- foo >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option matches literally (vanilla)' '
	echo vanilla >expect &&
	shit log --format=%s -- ":(literal)foo" >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option matches literally (star)' '
	echo star >expect &&
	shit --literal-pathspecs log --format=%s -- "f*" >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option matches literally (star)' '
	echo star >expect &&
	shit log --format=%s -- ":(literal)f*" >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option matches literally (bracket)' '
	echo bracket >expect &&
	shit --literal-pathspecs log --format=%s -- "f[o][o]" >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option matches literally (bracket)' '
	echo bracket >expect &&
	shit log --format=%s -- ":(literal)f[o][o]" >actual &&
	test_cmp expect actual
'

test_expect_success 'no-glob option disables :(literal)' '
	shit --literal-pathspecs log --format=%s -- ":(literal)foo" >actual &&
	test_must_be_empty actual
'

test_expect_success 'no-glob environment variable works' '
	echo star >expect &&
	shit_LITERAL_PATHSPECS=1 shit log --format=%s -- "f*" >actual &&
	test_cmp expect actual
'

test_expect_success 'blame takes global pathspec flags' '
	shit --literal-pathspecs blame -- foo &&
	shit --icase-pathspecs   blame -- foo &&
	shit --glob-pathspecs    blame -- foo &&
	shit --noglob-pathspecs  blame -- foo
'

test_expect_success 'setup xxx/bar' '
	mkdir xxx &&
	test_commit xxx xxx/bar
'

test_expect_success '**/ works with :(glob)' '
	cat >expect <<-\EOF &&
	xxx
	unrelated
	EOF
	shit log --format=%s -- ":(glob)**/bar" >actual &&
	test_cmp expect actual
'

test_expect_success '**/ does not work with --noglob-pathspecs' '
	shit --noglob-pathspecs log --format=%s -- "**/bar" >actual &&
	test_must_be_empty actual
'

test_expect_success '**/ works with :(glob) and --noglob-pathspecs' '
	cat >expect <<-\EOF &&
	xxx
	unrelated
	EOF
	shit --noglob-pathspecs log --format=%s -- ":(glob)**/bar" >actual &&
	test_cmp expect actual
'

test_expect_success '**/ works with --glob-pathspecs' '
	cat >expect <<-\EOF &&
	xxx
	unrelated
	EOF
	shit --glob-pathspecs log --format=%s -- "**/bar" >actual &&
	test_cmp expect actual
'

test_expect_success '**/ does not work with :(literal) and --glob-pathspecs' '
	shit --glob-pathspecs log --format=%s -- ":(literal)**/bar" >actual &&
	test_must_be_empty actual
'

test_done
