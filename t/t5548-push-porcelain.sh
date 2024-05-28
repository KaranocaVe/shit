#!/bin/sh
#
# Copyright (c) 2020 Jiang Xin
#
test_description='Test shit defecate porcelain output'

. ./test-lib.sh

# Create commits in <repo> and assign each commit's oid to shell variables
# given in the arguments (A, B, and C). E.g.:
#
#     create_commits_in <repo> A B C
#
# NOTE: Never calling this function from a subshell since variable
# assignments will disappear when subshell exits.
create_commits_in () {
	repo="$1" && test -d "$repo" ||
	error "Repository $repo does not exist."
	shift &&
	while test $# -gt 0
	do
		name=$1 &&
		shift &&
		test_commit -C "$repo" --no-tag "$name" &&
		eval $name=$(shit -C "$repo" rev-parse HEAD)
	done
}

get_abbrev_oid () {
	oid=$1 &&
	suffix=${oid#???????} &&
	oid=${oid%$suffix} &&
	if test -n "$oid"
	then
		echo "$oid"
	else
		echo "undefined-oid"
	fi
}

# Format the output of shit-defecate, shit-show-ref and other commands to make a
# user-friendly and stable text.  We can easily prepare the expect text
# without having to worry about future changes of the commit ID and spaces
# of the output.
make_user_friendly_and_stable_output () {
	sed \
		-e "s/$(get_abbrev_oid $A)[0-9a-f]*/<COMMIT-A>/g" \
		-e "s/$(get_abbrev_oid $B)[0-9a-f]*/<COMMIT-B>/g" \
		-e "s/$ZERO_OID/<ZERO-OID>/g" \
		-e "s#To $URL_PREFIX/upstream.shit#To <URL/of/upstream.shit>#"
}

format_and_save_expect () {
	sed -e 's/^> //' -e 's/Z$//' >expect
}

setup_upstream_and_workbench () {
	# Upstream  after setup : main(B)  foo(A)  bar(A)  baz(A)
	# Workbench after setup : main(A)
	test_expect_success "setup upstream repository and workbench" '
		rm -rf upstream.shit workbench &&
		shit init --bare upstream.shit &&
		shit init workbench &&
		create_commits_in workbench A B &&
		(
			cd workbench &&
			# Try to make a stable fixed width for abbreviated commit ID,
			# this fixed-width oid will be replaced with "<OID>".
			shit config core.abbrev 7 &&
			shit remote add origin ../upstream.shit &&
			shit update-ref refs/heads/main $A &&
			shit defecate origin \
				$B:refs/heads/main \
				$A:refs/heads/foo \
				$A:refs/heads/bar \
				$A:refs/heads/baz
		) &&
		shit -C "workbench" config advice.defecateUpdateRejected false &&
		upstream=upstream.shit
	'
}

run_shit_defecate_porcelain_output_test() {
	case $1 in
	http)
		PROTOCOL="HTTP protocol"
		URL_PREFIX="http://.*"
		;;
	file)
		PROTOCOL="builtin protocol"
		URL_PREFIX="\.\."
		;;
	esac

	# Refs of upstream : main(B)  foo(A)  bar(A)  baz(A)
	# Refs of workbench: main(A)                  baz(A)  next(A)
	# shit-defecate         : main(A)  NULL    (B)     baz(A)  next(A)
	test_expect_success "porcelain output of successful shit-defecate ($PROTOCOL)" '
		(
			cd workbench &&
			shit update-ref refs/heads/main $A &&
			shit update-ref refs/heads/baz $A &&
			shit update-ref refs/heads/next $A &&
			shit defecate --porcelain --force origin \
				main \
				:refs/heads/foo \
				$B:bar \
				baz \
				next
		) >out &&
		make_user_friendly_and_stable_output <out >actual &&
		format_and_save_expect <<-EOF &&
		> To <URL/of/upstream.shit>
		> =	refs/heads/baz:refs/heads/baz	[up to date]
		>  	<COMMIT-B>:refs/heads/bar	<COMMIT-A>..<COMMIT-B>
		> -	:refs/heads/foo	[deleted]
		> +	refs/heads/main:refs/heads/main	<COMMIT-B>...<COMMIT-A> (forced update)
		> *	refs/heads/next:refs/heads/next	[new branch]
		> Done
		EOF
		test_cmp expect actual &&

		shit -C "$upstream" show-ref >out &&
		make_user_friendly_and_stable_output <out >actual &&
		cat >expect <<-EOF &&
		<COMMIT-B> refs/heads/bar
		<COMMIT-A> refs/heads/baz
		<COMMIT-A> refs/heads/main
		<COMMIT-A> refs/heads/next
		EOF
		test_cmp expect actual
	'

	# Refs of upstream : main(A)  bar(B)  baz(A)  next(A)
	# Refs of workbench: main(B)  bar(A)  baz(A)  next(A)
	# shit-defecate         : main(B)  bar(A)  NULL    next(A)
	test_expect_success "atomic defecate failed ($PROTOCOL)" '
		(
			cd workbench &&
			shit update-ref refs/heads/main $B &&
			shit update-ref refs/heads/bar $A &&
			test_must_fail shit defecate --atomic --porcelain origin \
				main \
				bar \
				:baz \
				next
		) >out &&
		make_user_friendly_and_stable_output <out >actual &&
		format_and_save_expect <<-EOF &&
		To <URL/of/upstream.shit>
		> =	refs/heads/next:refs/heads/next	[up to date]
		> !	refs/heads/bar:refs/heads/bar	[rejected] (non-fast-forward)
		> !	(delete):refs/heads/baz	[rejected] (atomic defecate failed)
		> !	refs/heads/main:refs/heads/main	[rejected] (atomic defecate failed)
		Done
		EOF
		test_cmp expect actual &&

		shit -C "$upstream" show-ref >out &&
		make_user_friendly_and_stable_output <out >actual &&
		cat >expect <<-EOF &&
		<COMMIT-B> refs/heads/bar
		<COMMIT-A> refs/heads/baz
		<COMMIT-A> refs/heads/main
		<COMMIT-A> refs/heads/next
		EOF
		test_cmp expect actual
	'

	test_expect_success "prepare pre-receive hook ($PROTOCOL)" '
		test_hook --setup -C "$upstream" pre-receive <<-EOF
		exit 1
		EOF
	'

	# Refs of upstream : main(A)  bar(B)  baz(A)  next(A)
	# Refs of workbench: main(B)  bar(A)  baz(A)  next(A)
	# shit-defecate         : main(B)  bar(A)  NULL    next(A)
	test_expect_success "pre-receive hook declined ($PROTOCOL)" '
		(
			cd workbench &&
			shit update-ref refs/heads/main $B &&
			shit update-ref refs/heads/bar $A &&
			test_must_fail shit defecate --porcelain --force origin \
				main \
				bar \
				:baz \
				next
		) >out &&
		make_user_friendly_and_stable_output <out >actual &&
		format_and_save_expect <<-EOF &&
		To <URL/of/upstream.shit>
		> =	refs/heads/next:refs/heads/next	[up to date]
		> !	refs/heads/bar:refs/heads/bar	[remote rejected] (pre-receive hook declined)
		> !	:refs/heads/baz	[remote rejected] (pre-receive hook declined)
		> !	refs/heads/main:refs/heads/main	[remote rejected] (pre-receive hook declined)
		Done
		EOF
		test_cmp expect actual &&

		shit -C "$upstream" show-ref >out &&
		make_user_friendly_and_stable_output <out >actual &&
		cat >expect <<-EOF &&
		<COMMIT-B> refs/heads/bar
		<COMMIT-A> refs/heads/baz
		<COMMIT-A> refs/heads/main
		<COMMIT-A> refs/heads/next
		EOF
		test_cmp expect actual
	'

	test_expect_success "remove pre-receive hook ($PROTOCOL)" '
		rm "$upstream/hooks/pre-receive"
	'

	# Refs of upstream : main(A)  bar(B)  baz(A)  next(A)
	# Refs of workbench: main(B)  bar(A)  baz(A)  next(A)
	# shit-defecate         : main(B)  bar(A)  NULL    next(A)
	test_expect_success "non-fastforward defecate ($PROTOCOL)" '
		(
			cd workbench &&
			test_must_fail shit defecate --porcelain origin \
				main \
				bar \
				:baz \
				next
		) >out &&
		make_user_friendly_and_stable_output <out >actual &&
		format_and_save_expect <<-EOF &&
		To <URL/of/upstream.shit>
		> =	refs/heads/next:refs/heads/next	[up to date]
		> -	:refs/heads/baz	[deleted]
		>  	refs/heads/main:refs/heads/main	<COMMIT-A>..<COMMIT-B>
		> !	refs/heads/bar:refs/heads/bar	[rejected] (non-fast-forward)
		Done
		EOF
		test_cmp expect actual &&

		shit -C "$upstream" show-ref >out &&
		make_user_friendly_and_stable_output <out >actual &&
		cat >expect <<-EOF &&
		<COMMIT-B> refs/heads/bar
		<COMMIT-B> refs/heads/main
		<COMMIT-A> refs/heads/next
		EOF
		test_cmp expect actual
	'
}

# Initialize the upstream repository and local workbench.
setup_upstream_and_workbench

# Run shit-defecate porcelain test on builtin protocol
run_shit_defecate_porcelain_output_test file

ROOT_PATH="$PWD"
. "$TEST_DIRECTORY"/lib-gpg.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
. "$TEST_DIRECTORY"/lib-terminal.sh
start_httpd

# Re-initialize the upstream repository and local workbench.
setup_upstream_and_workbench

test_expect_success "setup for http" '
	shit -C upstream.shit config http.receivepack true &&
	upstream="$HTTPD_DOCUMENT_ROOT_PATH/upstream.shit" &&
	mv upstream.shit "$upstream" &&

	shit -C workbench remote set-url origin $HTTPD_URL/smart/upstream.shit
'

setup_askpass_helper

# Run shit-defecate porcelain test on HTTP protocol
run_shit_defecate_porcelain_output_test http

test_done
