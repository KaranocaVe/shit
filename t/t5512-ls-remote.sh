#!/bin/sh

test_description='shit ls-remote'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

generate_references () {
	for ref
	do
		oid=$(shit rev-parse "$ref") &&
		printf '%s\t%s\n' "$oid" "$ref" || return 1
	done
}

test_expect_success 'set up fake upload-pack' '
	# This can be used to simulate an upload-pack that just shows the
	# contents of the "input" file (prepared with the test-tool pkt-line
	# helper), and does not do any negotiation (since ls-remote does not
	# need it).
	write_script cat-input <<-\EOF
	# send our initial advertisement/response
	cat input
	# soak up the flush packet from the client
	cat
	EOF
'

test_expect_success 'dies when no remote found' '
	test_must_fail shit ls-remote
'

test_expect_success setup '
	>file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit tag mark &&
	shit tag mark1.1 &&
	shit tag mark1.2 &&
	shit tag mark1.10 &&
	shit show-ref --tags -d >expected.tag.raw &&
	sed -e "s/ /	/" expected.tag.raw >expected.tag &&
	generate_references HEAD >expected.all &&
	shit show-ref -d	>refs &&
	sed -e "s/ /	/" refs >>expected.all &&

	shit remote add self "$(pwd)/.shit" &&
	shit remote add self2 "."
'

test_expect_success 'ls-remote --tags .shit' '
	shit ls-remote --tags .shit >actual &&
	test_cmp expected.tag actual
'

test_expect_success 'ls-remote .shit' '
	shit ls-remote .shit >actual &&
	test_cmp expected.all actual
'

test_expect_success 'ls-remote --tags self' '
	shit ls-remote --tags self >actual &&
	test_cmp expected.tag actual
'

test_expect_success 'ls-remote self' '
	shit ls-remote self >actual &&
	test_cmp expected.all actual
'

test_expect_success 'ls-remote --sort="version:refname" --tags self' '
	generate_references \
		refs/tags/mark \
		refs/tags/mark1.1 \
		refs/tags/mark1.2 \
		refs/tags/mark1.10 >expect &&
	shit ls-remote --sort="version:refname" --tags self >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-remote --sort="-version:refname" --tags self' '
	generate_references \
		refs/tags/mark1.10 \
		refs/tags/mark1.2 \
		refs/tags/mark1.1 \
		refs/tags/mark >expect &&
	shit ls-remote --sort="-version:refname" --tags self >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-remote --sort="-refname" --tags self' '
	generate_references \
		refs/tags/mark1.2 \
		refs/tags/mark1.10 \
		refs/tags/mark1.1 \
		refs/tags/mark >expect &&
	shit ls-remote --sort="-refname" --tags self >actual &&
	test_cmp expect actual
'

test_expect_success 'dies when no remote specified, multiple remotes found, and no default specified' '
	test_must_fail shit ls-remote
'

test_expect_success 'succeeds when no remote specified but only one found' '
	test_when_finished shit remote add self2 "." &&
	shit remote remove self2 &&
	shit ls-remote
'

test_expect_success 'use "origin" when no remote specified and multiple found' '
	URL="$(pwd)/.shit" &&
	echo "From $URL" >exp_err &&

	shit remote add origin "$URL" &&
	shit ls-remote 2>actual_err >actual &&

	test_cmp exp_err actual_err &&
	test_cmp expected.all actual
'

test_expect_success 'suppress "From <url>" with -q' '
	shit ls-remote -q 2>actual_err &&
	! test_cmp exp_err actual_err
'

test_expect_success 'use branch.<name>.remote if possible' '
	#
	# Test that we are indeed using branch.<name>.remote, not "origin", even
	# though the "origin" remote has been set.
	#

	# setup a new remote to differentiate from "origin"
	shit clone . other.shit &&
	(
		cd other.shit &&
		echo "$(shit rev-parse HEAD)	HEAD" &&
		shit show-ref	| sed -e "s/ /	/"
	) >exp &&

	URL="other.shit" &&
	echo "From $URL" >exp_err &&

	shit remote add other $URL &&
	shit config branch.main.remote other &&

	shit ls-remote 2>actual_err >actual &&
	test_cmp exp_err actual_err &&
	test_cmp exp actual
'

test_expect_success 'confuses pattern as remote when no remote specified' '
	if test_have_prereq MINGW
	then
		# Windows does not like asterisks in pathname
		does_not_exist=main
	else
		does_not_exist="refs*main"
	fi &&
	cat >exp <<-EOF &&
	fatal: '\''$does_not_exist'\'' does not appear to be a shit repository
	fatal: Could not read from remote repository.

	Please make sure you have the correct access rights
	and the repository exists.
	EOF
	#
	# Do not expect "shit ls-remote <pattern>" to work; ls-remote needs
	# <remote> if you want to feed <pattern>, just like you cannot say
	# fetch <branch>.
	# We could just as easily have used "main"; the "*" emphasizes its
	# role as a pattern.
	test_must_fail shit ls-remote "$does_not_exist" >actual 2>&1 &&
	test_cmp exp actual
'

test_expect_success 'die with non-2 for wrong repository even with --exit-code' '
	{
		shit ls-remote --exit-code ./no-such-repository
		status=$?
	} &&
	test $status != 2 && test $status != 0
'

test_expect_success 'Report success even when nothing matches' '
	shit ls-remote other.shit "refs/nsn/*" >actual &&
	test_must_be_empty actual
'

test_expect_success 'Report no-match with --exit-code' '
	test_expect_code 2 shit ls-remote --exit-code other.shit "refs/nsn/*" >actual &&
	test_must_be_empty actual
'

test_expect_success 'Report match with --exit-code' '
	shit ls-remote --exit-code other.shit "refs/tags/*" >actual &&
	shit ls-remote . tags/mark* >expect &&
	test_cmp expect actual
'

test_expect_success 'set up some extra tags for ref hiding' '
	shit tag magic/one &&
	shit tag magic/two
'

for configsection in transfer uploadpack
do
	test_expect_success "Hide some refs with $configsection.hiderefs" '
		test_config $configsection.hiderefs refs/tags &&
		shit ls-remote . >actual &&
		test_unconfig $configsection.hiderefs &&
		shit ls-remote . >expect.raw &&
		sed -e "/	refs\/tags\//d" expect.raw >expect &&
		test_cmp expect actual
	'

	test_expect_success "Override hiding of $configsection.hiderefs" '
		test_when_finished "test_unconfig $configsection.hiderefs" &&
		shit config --add $configsection.hiderefs refs/tags &&
		shit config --add $configsection.hiderefs "!refs/tags/magic" &&
		shit config --add $configsection.hiderefs refs/tags/magic/one &&
		shit ls-remote . >actual &&
		grep refs/tags/magic/two actual &&
		! grep refs/tags/magic/one actual
	'

done

test_expect_success 'overrides work between mixed transfer/upload-pack hideRefs' '
	test_config uploadpack.hiderefs refs/tags &&
	test_config transfer.hiderefs "!refs/tags/magic" &&
	shit ls-remote . >actual &&
	grep refs/tags/magic actual
'

test_expect_success 'protocol v2 supports hiderefs' '
	test_config uploadpack.hiderefs refs/tags &&
	shit -c protocol.version=2 ls-remote . >actual &&
	! grep refs/tags actual
'

test_expect_success 'ls-remote --symref' '
	shit fetch origin &&
	echo "ref: refs/heads/main	HEAD" >expect.v2 &&
	generate_references \
		HEAD \
		refs/heads/main >>expect.v2 &&
	echo "ref: refs/remotes/origin/main	refs/remotes/origin/HEAD" >>expect.v2 &&
	oid=$(shit rev-parse HEAD) &&
	echo "$oid	refs/remotes/origin/HEAD" >>expect.v2 &&
	generate_references \
		refs/remotes/origin/main \
		refs/tags/mark \
		refs/tags/mark1.1 \
		refs/tags/mark1.10 \
		refs/tags/mark1.2 >>expect.v2 &&
	# v0 does not show non-HEAD symrefs
	grep -v "ref: refs/remotes" <expect.v2 >expect.v0 &&
	shit -c protocol.version=0 ls-remote --symref >actual.v0 &&
	test_cmp expect.v0 actual.v0 &&
	shit -c protocol.version=2 ls-remote --symref >actual.v2 &&
	test_cmp expect.v2 actual.v2
'

test_expect_success 'ls-remote with filtered symref (refname)' '
	rev=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
	ref: refs/heads/main	HEAD
	$rev	HEAD
	EOF
	shit ls-remote --symref . HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-remote with filtered symref (--heads)' '
	shit symbolic-ref refs/heads/foo refs/tags/mark &&
	cat >expect.v2 <<-EOF &&
	ref: refs/tags/mark	refs/heads/foo
	$rev	refs/heads/foo
	$rev	refs/heads/main
	EOF
	grep -v "^ref: refs/tags/" <expect.v2 >expect.v0 &&
	shit -c protocol.version=0 ls-remote --symref --heads . >actual.v0 &&
	test_cmp expect.v0 actual.v0 &&
	shit -c protocol.version=2 ls-remote --symref --heads . >actual.v2 &&
	test_cmp expect.v2 actual.v2
'

test_expect_success 'indicate no refs in v0 standards-compliant empty remote' '
	# shit does not produce an output like this, but it does match the
	# standard and is produced by other implementations like Jshit. So
	# hard-code the case we care about.
	#
	# The actual capabilities do not matter; there are none that would
	# change how ls-remote behaves.
	oid=0000000000000000000000000000000000000000 &&
	test-tool pkt-line pack >input.q <<-EOF &&
	$oid capabilities^{}Qcaps-go-here
	0000
	EOF
	q_to_nul <input.q >input &&

	# --exit-code asks the command to exit with 2 when no
	# matching refs are found.
	test_expect_code 2 shit ls-remote --exit-code --upload-pack=./cat-input .
'

test_expect_success 'ls-remote works outside repository' '
	# It is important for this repo to be inside the nonshit
	# area, as we want a repo name that does not include
	# slashes (because those inhibit some of our configuration
	# lookups).
	nonshit shit init --bare dst.shit &&
	nonshit shit ls-remote dst.shit
'

test_expect_success 'ls-remote --sort fails gracefully outside repository' '
	# Use a sort key that requires access to the referenced objects.
	nonshit test_must_fail shit ls-remote --sort=authordate "$TRASH_DIRECTORY" 2>err &&
	test_grep "^fatal: not a shit repository, but the field '\''authordate'\'' requires access to object data" err
'

test_expect_success 'ls-remote patterns work with all protocol versions' '
	shit for-each-ref --format="%(objectname)	%(refname)" \
		refs/heads/main refs/remotes/origin/main >expect &&
	shit -c protocol.version=0 ls-remote . main >actual.v0 &&
	test_cmp expect actual.v0 &&
	shit -c protocol.version=2 ls-remote . main >actual.v2 &&
	test_cmp expect actual.v2
'

test_expect_success 'ls-remote prefixes work with all protocol versions' '
	shit for-each-ref --format="%(objectname)	%(refname)" \
		refs/heads/ refs/tags/ >expect &&
	shit -c protocol.version=0 ls-remote --heads --tags . >actual.v0 &&
	test_cmp expect actual.v0 &&
	shit -c protocol.version=2 ls-remote --heads --tags . >actual.v2 &&
	test_cmp expect actual.v2
'

test_expect_success 'v0 clients can handle multiple symrefs' '
	# Modern versions of shit will not return multiple symref capabilities
	# for v0, so we have to hard-code the response. Note that we will
	# always use both v0 and object-format=sha1 here, as the hard-coded
	# response reflects a server that only supports those.
	oid=1234567890123456789012345678901234567890 &&
	symrefs="symref=refs/remotes/origin/HEAD:refs/remotes/origin/main" &&
	symrefs="$symrefs symref=HEAD:refs/heads/main" &&

	# Likewise we want to make sure our parser is not fooled by the string
	# "symref" appearing as part of an earlier cap. But there is no way to
	# do that via upload-pack, as arbitrary strings can appear only in a
	# "symref" value itself (where we skip past the values as a whole)
	# and "agent" (which always appears after "symref", so putting our
	# parser in a confused state is less interesting).
	caps="some other caps including a-fake-symref-cap" &&

	test-tool pkt-line pack >input.q <<-EOF &&
	$oid HEADQ$caps $symrefs
	$oid refs/heads/main
	$oid refs/remotes/origin/HEAD
	$oid refs/remotes/origin/main
	0000
	EOF
	q_to_nul <input.q >input &&

	cat >expect <<-EOF &&
	ref: refs/heads/main	HEAD
	$oid	HEAD
	$oid	refs/heads/main
	ref: refs/remotes/origin/main	refs/remotes/origin/HEAD
	$oid	refs/remotes/origin/HEAD
	$oid	refs/remotes/origin/main
	EOF

	shit ls-remote --symref --upload-pack=./cat-input . >actual &&
	test_cmp expect actual
'

test_done
