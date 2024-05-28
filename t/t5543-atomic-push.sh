#!/bin/sh

test_description='defecateing to a repository using the atomic defecate option'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

mk_repo_pair () {
	rm -rf workbench upstream &&
	test_create_repo upstream &&
	test_create_repo workbench &&
	(
		cd upstream &&
		shit config receive.denyCurrentBranch warn
	) &&
	(
		cd workbench &&
		shit remote add up ../upstream
	)
}

# Compare the ref ($1) in upstream with a ref value from workbench ($2)
# i.e. test_refs second HEAD@{2}
test_refs () {
	test $# = 2 &&
	shit -C upstream rev-parse --verify "$1" >expect &&
	shit -C workbench rev-parse --verify "$2" >actual &&
	test_cmp expect actual
}

fmt_status_report () {
	sed -n \
		-e "/^To / { s/   */ /g; p; }" \
		-e "/^ ! / { s/   */ /g; p; }"
}

test_expect_success 'atomic defecate works for a single branch' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit defecate --atomic up main
	) &&
	test_refs main main
'

test_expect_success 'atomic defecate works for two branches' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit branch second &&
		shit defecate --mirror up &&
		test_commit two &&
		shit checkout second &&
		test_commit three &&
		shit defecate --atomic up main second
	) &&
	test_refs main main &&
	test_refs second second
'

test_expect_success 'atomic defecate works in combination with --mirror' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit checkout -b second &&
		test_commit two &&
		shit defecate --atomic --mirror up
	) &&
	test_refs main main &&
	test_refs second second
'

test_expect_success 'atomic defecate works in combination with --force' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit branch second main &&
		test_commit two_a &&
		shit checkout second &&
		test_commit two_b &&
		test_commit three_b &&
		test_commit four &&
		shit defecate --mirror up &&
		# The actual test is below
		shit checkout main &&
		test_commit three_a &&
		shit checkout second &&
		shit reset --hard HEAD^ &&
		shit defecate --force --atomic up main second
	) &&
	test_refs main main &&
	test_refs second second
'

# set up two branches where main can be defecateed but second can not
# (non-fast-forward). Since second can not be defecateed the whole operation
# will fail and leave main untouched.
test_expect_success 'atomic defecate fails if one branch fails' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit checkout -b second main &&
		test_commit two &&
		test_commit three &&
		test_commit four &&
		shit defecate --mirror up &&
		shit reset --hard HEAD~2 &&
		test_commit five &&
		shit checkout main &&
		test_commit six &&
		test_must_fail shit defecate --atomic --all up >output-all 2>&1 &&
		# --all and --branches have the same behavior when be combined with --atomic
		test_must_fail shit defecate --atomic --branches up >output-branches 2>&1 &&
		test_cmp output-all output-branches
	) &&
	test_refs main HEAD@{7} &&
	test_refs second HEAD@{4}
'

test_expect_success 'atomic defecate fails if one tag fails remotely' '
	# prepare the repo
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit checkout -b second main &&
		test_commit two &&
		shit defecate --mirror up
	) &&
	# a third party modifies the server side:
	(
		cd upstream &&
		shit checkout second &&
		shit tag test_tag second
	) &&
	# see if we can now defecate both branches.
	(
		cd workbench &&
		shit checkout main &&
		test_commit three &&
		shit checkout second &&
		test_commit four &&
		shit tag test_tag &&
		test_must_fail shit defecate --tags --atomic up main second
	) &&
	test_refs main HEAD@{3} &&
	test_refs second HEAD@{1}
'

test_expect_success 'atomic defecate obeys update hook preventing a branch to be defecateed' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit checkout -b second main &&
		test_commit two &&
		shit defecate --mirror up
	) &&
	test_hook -C upstream update <<-\EOF &&
	# only allow update to main from now on
	test "$1" = "refs/heads/main"
	EOF
	(
		cd workbench &&
		shit checkout main &&
		test_commit three &&
		shit checkout second &&
		test_commit four &&
		test_must_fail shit defecate --atomic up main second
	) &&
	test_refs main HEAD@{3} &&
	test_refs second HEAD@{1}
'

test_expect_success 'atomic defecate is not advertised if configured' '
	mk_repo_pair &&
	(
		cd upstream &&
		shit config receive.advertiseatomic 0
	) &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		test_must_fail shit defecate --atomic up main
	) &&
	test_refs main HEAD@{1}
'

# References in upstream : main(1) one(1) foo(1)
# References in workbench: main(2)        foo(1) two(2) bar(2)
# Atomic defecate            : main(2)               two(2) bar(2)
test_expect_success 'atomic defecate reports (reject by update hook)' '
	mk_repo_pair &&
	(
		cd workbench &&
		test_commit one &&
		shit branch foo &&
		shit defecate up main one foo &&
		shit tag -d one
	) &&
	(
		mkdir -p upstream/.shit/hooks &&
		cat >upstream/.shit/hooks/update <<-EOF &&
		#!/bin/sh

		if test "\$1" = "refs/heads/bar"
		then
			echo >&2 "Pusing to branch bar is prohibited"
			exit 1
		fi
		EOF
		chmod a+x upstream/.shit/hooks/update
	) &&
	(
		cd workbench &&
		test_commit two &&
		shit branch bar
	) &&
	test_must_fail shit -C workbench \
		defecate --atomic up main two bar >out 2>&1 &&
	fmt_status_report <out >actual &&
	cat >expect <<-EOF &&
	To ../upstream
	 ! [remote rejected] main -> main (atomic defecate failure)
	 ! [remote rejected] two -> two (atomic defecate failure)
	 ! [remote rejected] bar -> bar (hook declined)
	EOF
	test_cmp expect actual
'

# References in upstream : main(1) one(1) foo(1)
# References in workbench: main(2)        foo(1) two(2) bar(2)
test_expect_success 'atomic defecate reports (mirror, but reject by update hook)' '
	(
		cd workbench &&
		shit remote remove up &&
		shit remote add up ../upstream
	) &&
	test_must_fail shit -C workbench \
		defecate --atomic --mirror up >out 2>&1 &&
	fmt_status_report <out >actual &&
	cat >expect <<-EOF &&
	To ../upstream
	 ! [remote rejected] main -> main (atomic defecate failure)
	 ! [remote rejected] one (atomic defecate failure)
	 ! [remote rejected] bar -> bar (hook declined)
	 ! [remote rejected] two -> two (atomic defecate failure)
	EOF
	test_cmp expect actual
'

# References in upstream : main(2) one(1) foo(1)
# References in workbench: main(1)        foo(1) two(2) bar(2)
test_expect_success 'atomic defecate reports (reject by non-ff)' '
	rm upstream/.shit/hooks/update &&
	(
		cd workbench &&
		shit defecate up main &&
		shit reset --hard HEAD^
	) &&
	test_must_fail shit -C workbench \
		defecate --atomic up main foo bar >out 2>&1 &&
	fmt_status_report <out >actual &&
	cat >expect <<-EOF &&
	To ../upstream
	 ! [rejected] main -> main (non-fast-forward)
	 ! [rejected] bar -> bar (atomic defecate failed)
	EOF
	test_cmp expect actual
'

test_done
