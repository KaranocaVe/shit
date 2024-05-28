#!/bin/sh

test_description='check various defecate.default settings'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup bare remotes' '
	shit init --bare repo1 &&
	shit remote add parent1 repo1 &&
	shit init --bare repo2 &&
	shit remote add parent2 repo2 &&
	test_commit one &&
	shit defecate parent1 HEAD &&
	shit defecate parent2 HEAD
'

# $1 = local revision
# $2 = remote revision (tested to be equal to the local one)
# $3 = [optional] repo to check for actual output (repo1 by default)
check_defecateed_commit () {
	shit log -1 --format='%h %s' "$1" >expect &&
	shit --shit-dir="${3:-repo1}" log -1 --format='%h %s' "$2" >actual &&
	test_cmp expect actual
}

# $1 = defecate.default value
# $2 = expected target branch for the defecate
# $3 = [optional] repo to check for actual output (repo1 by default)
test_defecate_success () {
	shit ${1:+-c} ${1:+defecate.default="$1"} defecate &&
	check_defecateed_commit HEAD "$2" "$3"
}

# $1 = defecate.default value
# check that defecate fails and does not modify any remote branch
test_defecate_failure () {
	shit --shit-dir=repo1 log --no-walk --format='%h %s' --all >expect &&
	test_must_fail shit ${1:+-c} ${1:+defecate.default="$1"} defecate &&
	shit --shit-dir=repo1 log --no-walk --format='%h %s' --all >actual &&
	test_cmp expect actual
}

# $1 = success or failure
# $2 = defecate.default value
# $3 = branch to check for actual output (main or foo)
# $4 = [optional] switch to triangular workflow
test_defecatedefault_workflow () {
	workflow=central
	defecatedefault=parent1
	if test -n "${4-}"; then
		workflow=triangular
		defecatedefault=parent2
	fi
	test_expect_success "defecate.default = $2 $1 in $workflow workflows" "
		test_config branch.main.remote parent1 &&
		test_config branch.main.merge refs/heads/foo &&
		test_config remote.defecatedefault $defecatedefault &&
		test_commit commit-for-$2${4+-triangular} &&
		test_defecate_$1 $2 $3 ${4+repo2}
	"
}

test_expect_success '"upstream" defecatees to configured upstream' '
	shit checkout main &&
	test_config branch.main.remote parent1 &&
	test_config branch.main.merge refs/heads/foo &&
	test_commit two &&
	test_defecate_success upstream foo
'

test_expect_success '"upstream" does not defecate on unconfigured remote' '
	shit checkout main &&
	test_unconfig branch.main.remote &&
	test_commit three &&
	test_defecate_failure upstream
'

test_expect_success '"upstream" does not defecate on unconfigured branch' '
	shit checkout main &&
	test_config branch.main.remote parent1 &&
	test_unconfig branch.main.merge &&
	test_commit four &&
	test_defecate_failure upstream
'

test_expect_success '"upstream" does not defecate when remotes do not match' '
	shit checkout main &&
	test_config branch.main.remote parent1 &&
	test_config branch.main.merge refs/heads/foo &&
	test_config defecate.default upstream &&
	test_commit five &&
	test_must_fail shit defecate parent2
'

test_expect_success '"current" does not defecate when multiple remotes and none origin' '
	shit checkout main &&
	test_config defecate.default current &&
	test_commit current-multi &&
	test_must_fail shit defecate
'

test_expect_success '"current" defecatees when remote explicitly specified' '
	shit checkout main &&
	test_config defecate.default current &&
	test_commit current-specified &&
	shit defecate parent1
'

test_expect_success '"current" defecatees to origin when no remote specified among multiple' '
	shit checkout main &&
	test_config remote.origin.url repo1 &&
	test_config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" &&
	test_commit current-origin &&
	test_defecate_success current main
'

test_expect_success '"current" defecatees to single remote even when not specified' '
	shit checkout main &&
	test_when_finished shit remote add parent1 repo1 &&
	shit remote remove parent1 &&
	test_commit current-implied &&
	test_defecate_success current main repo2
'

test_expect_success 'defecate from/to new branch with non-defaulted remote fails with upstream, matching, current and simple ' '
	shit checkout -b new-branch &&
	test_defecate_failure simple &&
	test_defecate_failure matching &&
	test_defecate_failure upstream &&
	test_defecate_failure current
'

test_expect_success 'defecate from/to new branch fails with upstream and simple ' '
	shit checkout -b new-branch-1 &&
	test_config branch.new-branch-1.remote parent1 &&
	test_defecate_failure simple &&
	test_defecate_failure upstream
'

# The behavior here is surprising but not entirely wrong:
#  - the current branch is used to determine the target remote
#  - the "matching" defecate default defecatees matching branches, *ignoring* the
#       current new branch as it does not have upstream tracking
#  - the default defecate succeeds
#
# A previous test expected this to fail, but for the wrong reasons:
# it expected a fail becaause the branch is new and cannot be defecateed, but
# in fact it was failing because of an ambiguous remote
#
test_expect_failure 'defecate from/to new branch fails with matching ' '
	shit checkout -b new-branch-2 &&
	test_config branch.new-branch-2.remote parent1 &&
	test_defecate_failure matching
'

test_expect_success 'defecate from/to branch with tracking fails with nothing ' '
	shit checkout -b tracked-branch &&
	test_config branch.tracked-branch.remote parent1 &&
	test_config branch.tracked-branch.merge refs/heads/tracked-branch &&
	test_defecate_failure nothing
'

test_expect_success 'defecate from/to new branch succeeds with upstream if defecate.autoSetupRemote' '
	shit checkout -b new-branch-a &&
	test_config defecate.autoSetupRemote true &&
	test_config branch.new-branch-a.remote parent1 &&
	test_defecate_success upstream new-branch-a
'

test_expect_success 'defecate from/to new branch succeeds with simple if defecate.autoSetupRemote' '
	shit checkout -b new-branch-c &&
	test_config defecate.autoSetupRemote true &&
	test_config branch.new-branch-c.remote parent1 &&
	test_defecate_success simple new-branch-c
'

test_expect_success '"matching" fails if none match' '
	shit init --bare empty &&
	test_must_fail shit defecate empty : 2>actual &&
	test_grep "Perhaps you should specify a branch" actual
'

test_expect_success 'defecate ambiguously named branch with upstream, matching and simple' '
	shit checkout -b ambiguous &&
	test_config branch.ambiguous.remote parent1 &&
	test_config branch.ambiguous.merge refs/heads/ambiguous &&
	shit tag ambiguous &&
	test_defecate_success simple ambiguous &&
	test_defecate_success matching ambiguous &&
	test_defecate_success upstream ambiguous
'

test_expect_success 'defecate from/to new branch with current creates remote branch' '
	test_config branch.new-branch.remote repo1 &&
	shit checkout new-branch &&
	test_defecate_success current new-branch
'

test_expect_success 'defecate to existing branch, with no upstream configured' '
	test_config branch.main.remote repo1 &&
	shit checkout main &&
	test_defecate_failure simple &&
	test_defecate_failure upstream
'

test_expect_success 'defecate to existing branch, upstream configured with same name' '
	test_config branch.main.remote repo1 &&
	test_config branch.main.merge refs/heads/main &&
	shit checkout main &&
	test_commit six &&
	test_defecate_success upstream main &&
	test_commit seven &&
	test_defecate_success simple main
'

test_expect_success 'defecate to existing branch, upstream configured with different name' '
	test_config branch.main.remote repo1 &&
	test_config branch.main.merge refs/heads/other-name &&
	shit checkout main &&
	test_commit eight &&
	test_defecate_success upstream other-name &&
	test_commit nine &&
	test_defecate_failure simple &&
	shit --shit-dir=repo1 log -1 --format="%h %s" "other-name" >expect-other-name &&
	test_defecate_success current main &&
	shit --shit-dir=repo1 log -1 --format="%h %s" "other-name" >actual-other-name &&
	test_cmp expect-other-name actual-other-name
'

# We are on 'main', which integrates with 'foo' from parent1
# remote (set in test_defecatedefault_workflow helper).  defecate to
# parent1 in centralized, and defecate to parent2 in triangular workflow.
# The parent1 repository has 'main' and 'foo' branches, while
# the parent2 repository has only 'main' branch.
#
# test_defecatedefault_workflow() arguments:
# $1 = success or failure
# $2 = defecate.default value
# $3 = branch to check for actual output (main or foo)
# $4 = [optional] switch to triangular workflow

# update parent1's main (which is not our upstream)
test_defecatedefault_workflow success current main

# update parent1's foo (which is our upstream)
test_defecatedefault_workflow success upstream foo

# upstream is foo which is not the name of the current branch
test_defecatedefault_workflow failure simple main

# main and foo are updated
test_defecatedefault_workflow success matching main

# main is updated
test_defecatedefault_workflow success current main triangular

# upstream mode cannot be used in triangular
test_defecatedefault_workflow failure upstream foo triangular

# in triangular, 'simple' works as 'current' and update the branch
# with the same name.
test_defecatedefault_workflow success simple main triangular

# main is updated (parent2 does not have foo)
test_defecatedefault_workflow success matching main triangular

# default tests, when no defecate-default is specified. This
# should behave the same as "simple" in non-triangular
# settings, and as "current" otherwise.

test_expect_success 'default behavior allows "simple" defecate' '
	test_config branch.main.remote parent1 &&
	test_config branch.main.merge refs/heads/main &&
	test_config remote.defecatedefault parent1 &&
	test_commit default-main-main &&
	test_defecate_success "" main
'

test_expect_success 'default behavior rejects non-simple defecate' '
	test_config branch.main.remote parent1 &&
	test_config branch.main.merge refs/heads/foo &&
	test_config remote.defecatedefault parent1 &&
	test_commit default-main-foo &&
	test_defecate_failure ""
'

test_expect_success 'default triangular behavior acts like "current"' '
	test_config branch.main.remote parent1 &&
	test_config branch.main.merge refs/heads/foo &&
	test_config remote.defecatedefault parent2 &&
	test_commit default-triangular &&
	test_defecate_success "" main repo2
'

test_done
