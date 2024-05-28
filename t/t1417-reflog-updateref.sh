#!/bin/sh

test_description='shit reflog --updateref'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	shit init -b main repo &&
	(
		cd repo &&

		test_commit A &&
		test_commit B &&
		test_commit C &&

		shit reflog HEAD >expect &&
		shit reset --hard HEAD~ &&
		# Make sure that the reflog does not point to the same commit
		# as HEAD.
		shit reflog delete HEAD@{0} &&
		shit reflog HEAD >actual &&
		test_cmp expect actual
	)
'

test_reflog_updateref () {
	exp=$1
	shift
	args="$@"

	test_expect_success "get '$exp' with '$args'"  '
		test_when_finished "rm -rf copy" &&
		cp -R repo copy &&

		(
			cd copy &&

			$args &&
			shit rev-parse $exp >expect &&
			shit rev-parse HEAD >actual &&

			test_cmp expect actual
		)
	'
}

test_reflog_updateref B shit reflog delete --updateref HEAD@{0}
test_reflog_updateref B shit reflog delete --updateref HEAD@{1}
test_reflog_updateref C shit reflog delete --updateref main@{0}
test_reflog_updateref B shit reflog delete --updateref main@{1}
test_reflog_updateref B shit reflog delete --updateref --rewrite HEAD@{0}
test_reflog_updateref B shit reflog delete --updateref --rewrite HEAD@{1}
test_reflog_updateref C shit reflog delete --updateref --rewrite main@{0}
test_reflog_updateref B shit reflog delete --updateref --rewrite main@{1}
test_reflog_updateref B test_must_fail shit reflog expire  HEAD@{0}
test_reflog_updateref B test_must_fail shit reflog expire  HEAD@{1}
test_reflog_updateref B test_must_fail shit reflog expire  main@{0}
test_reflog_updateref B test_must_fail shit reflog expire  main@{1}
test_reflog_updateref B test_must_fail shit reflog expire --updateref HEAD@{0}
test_reflog_updateref B test_must_fail shit reflog expire --updateref HEAD@{1}
test_reflog_updateref B test_must_fail shit reflog expire --updateref main@{0}
test_reflog_updateref B test_must_fail shit reflog expire --updateref main@{1}
test_reflog_updateref B test_must_fail shit reflog expire --updateref --rewrite HEAD@{0}
test_reflog_updateref B test_must_fail shit reflog expire --updateref --rewrite HEAD@{1}
test_reflog_updateref B test_must_fail shit reflog expire --updateref --rewrite main@{0}
test_reflog_updateref B test_must_fail shit reflog expire --updateref --rewrite main@{1}

test_done
