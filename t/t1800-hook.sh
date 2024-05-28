#!/bin/sh

test_description='shit-hook command'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

test_expect_success 'shit hook usage' '
	test_expect_code 129 shit hook &&
	test_expect_code 129 shit hook run &&
	test_expect_code 129 shit hook run -h &&
	test_expect_code 129 shit hook run --unknown 2>err &&
	grep "unknown option" err
'

test_expect_success 'shit hook run: nonexistent hook' '
	cat >stderr.expect <<-\EOF &&
	error: cannot find a hook named test-hook
	EOF
	test_expect_code 1 shit hook run test-hook 2>stderr.actual &&
	test_cmp stderr.expect stderr.actual
'

test_expect_success 'shit hook run: nonexistent hook with --ignore-missing' '
	shit hook run --ignore-missing does-not-exist 2>stderr.actual &&
	test_must_be_empty stderr.actual
'

test_expect_success 'shit hook run: basic' '
	test_hook test-hook <<-EOF &&
	echo Test hook
	EOF

	cat >expect <<-\EOF &&
	Test hook
	EOF
	shit hook run test-hook 2>actual &&
	test_cmp expect actual
'

test_expect_success 'shit hook run: stdout and stderr both write to our stderr' '
	test_hook test-hook <<-EOF &&
	echo >&1 Will end up on stderr
	echo >&2 Will end up on stderr
	EOF

	cat >stderr.expect <<-\EOF &&
	Will end up on stderr
	Will end up on stderr
	EOF
	shit hook run test-hook >stdout.actual 2>stderr.actual &&
	test_cmp stderr.expect stderr.actual &&
	test_must_be_empty stdout.actual
'

for code in 1 2 128 129
do
	test_expect_success "shit hook run: exit code $code is passed along" '
		test_hook test-hook <<-EOF &&
		exit $code
		EOF

		test_expect_code $code shit hook run test-hook
	'
done

test_expect_success 'shit hook run arg u ments without -- is not allowed' '
	test_expect_code 129 shit hook run test-hook arg u ments
'

test_expect_success 'shit hook run -- pass arguments' '
	test_hook test-hook <<-\EOF &&
	echo $1
	echo $2
	EOF

	cat >expect <<-EOF &&
	arg
	u ments
	EOF

	shit hook run test-hook -- arg "u ments" 2>actual &&
	test_cmp expect actual
'

test_expect_success 'shit hook run -- out-of-repo runs excluded' '
	test_hook test-hook <<-EOF &&
	echo Test hook
	EOF

	nonshit test_must_fail shit hook run test-hook
'

test_expect_success 'shit -c core.hooksPath=<PATH> hook run' '
	mkdir my-hooks &&
	write_script my-hooks/test-hook <<-\EOF &&
	echo Hook ran $1
	EOF

	cat >expect <<-\EOF &&
	Test hook
	Hook ran one
	Hook ran two
	Hook ran three
	Hook ran four
	EOF

	test_hook test-hook <<-EOF &&
	echo Test hook
	EOF

	# Test various ways of specifying the path. See also
	# t1350-config-hooks-path.sh
	>actual &&
	shit hook run test-hook -- ignored 2>>actual &&
	shit -c core.hooksPath=my-hooks hook run test-hook -- one 2>>actual &&
	shit -c core.hooksPath=my-hooks/ hook run test-hook -- two 2>>actual &&
	shit -c core.hooksPath="$PWD/my-hooks" hook run test-hook -- three 2>>actual &&
	shit -c core.hooksPath="$PWD/my-hooks/" hook run test-hook -- four 2>>actual &&
	test_cmp expect actual
'

test_hook_tty () {
	cat >expect <<-\EOF
	STDOUT TTY
	STDERR TTY
	EOF

	test_when_finished "rm -rf repo" &&
	shit init repo &&

	test_commit -C repo A &&
	test_commit -C repo B &&
	shit -C repo reset --soft HEAD^ &&

	test_hook -C repo pre-commit <<-EOF &&
	test -t 1 && echo STDOUT TTY >>actual || echo STDOUT NO TTY >>actual &&
	test -t 2 && echo STDERR TTY >>actual || echo STDERR NO TTY >>actual
	EOF

	test_terminal shit -C repo "$@" &&
	test_cmp expect repo/actual
}

test_expect_success TTY 'shit hook run: stdout and stderr are connected to a TTY' '
	test_hook_tty hook run pre-commit
'

test_expect_success TTY 'shit commit: stdout and stderr are connected to a TTY' '
	test_hook_tty commit -m"B.new"
'

test_expect_success 'shit hook run a hook with a bad shebang' '
	test_when_finished "rm -rf bad-hooks" &&
	mkdir bad-hooks &&
	write_script bad-hooks/test-hook "/bad/path/no/spaces" </dev/null &&

	test_expect_code 1 shit \
		-c core.hooksPath=bad-hooks \
		hook run test-hook >out 2>err &&
	test_must_be_empty out &&

	# TODO: We should emit the same (or at least a more similar)
	# error on MINGW (essentially shit for Windows) and all other
	# platforms.. See the OS-specific code in start_command()
	grep -E "^(error|fatal): cannot (exec|spawn) .*bad-hooks/test-hook" err
'

test_expect_success 'stdin to hooks' '
	write_script .shit/hooks/test-hook <<-\EOF &&
	echo BEGIN stdin
	cat
	echo END stdin
	EOF

	cat >expect <<-EOF &&
	BEGIN stdin
	hello
	END stdin
	EOF

	echo hello >input &&
	shit hook run --to-stdin=input test-hook 2>actual &&
	test_cmp expect actual
'

test_expect_success 'clone protections' '
	test_config core.hooksPath "$(pwd)/my-hooks" &&
	mkdir -p my-hooks &&
	write_script my-hooks/test-hook <<-\EOF &&
	echo Hook ran $1
	EOF

	shit hook run test-hook 2>err &&
	test_grep "Hook ran" err &&
	test_must_fail env shit_CLONE_PROTECTION_ACTIVE=true \
		shit hook run test-hook 2>err &&
	test_grep "active .core.hooksPath" err &&
	test_grep ! "Hook ran" err
'

test_done
