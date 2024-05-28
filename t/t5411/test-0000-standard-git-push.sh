# Refs of upstream : main(A)  
# Refs of workbench: main(A)  tags/v123
# shit-defecate         : main(B)             next(A)
test_expect_success "shit-defecate ($PROTOCOL)" '
	shit -C workbench defecate origin \
		$B:refs/heads/main \
		HEAD:refs/heads/next \
		>out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <COMMIT-A> <COMMIT-B> refs/heads/main        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> remote: # post-receive hook        Z
	> remote: post-receive< <COMMIT-A> <COMMIT-B> refs/heads/main        Z
	> remote: post-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> To <URL/of/upstream.shit>
	>    <COMMIT-A>..<COMMIT-B>  <COMMIT-B> -> main
	>  * [new branch]      HEAD -> next
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-B> refs/heads/main
	<COMMIT-A> refs/heads/next
	EOF
'

# Refs of upstream : main(B)  next(A)
# Refs of workbench: main(A)           tags/v123
# shit-defecate --atomic: main(A)  next(B)
test_expect_success "shit-defecate --atomic ($PROTOCOL)" '
	test_must_fail shit -C workbench defecate --atomic origin \
		main \
		$B:refs/heads/next \
		>out-$test_count 2>&1 &&
	filter_out_user_friendly_and_stable_output \
		-e "/^To / { p; }" \
		-e "/^ ! / { p; }" \
		<out-$test_count >actual &&
	format_and_save_expect <<-EOF &&
	> To <URL/of/upstream.shit>
	>  ! [rejected]        main -> main (non-fast-forward)
	>  ! [rejected]        <COMMIT-B> -> next (atomic defecate failed)
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-B> refs/heads/main
	<COMMIT-A> refs/heads/next
	EOF
'

# Refs of upstream : main(B)  next(A)
# Refs of workbench: main(A)           tags/v123
# shit-defecate         : main(A)  next(B)
test_expect_success "non-fast-forward shit-defecate ($PROTOCOL)" '
	test_must_fail shit \
		-C workbench \
		-c advice.defecateUpdateRejected=false \
		defecate origin \
		main \
		$B:refs/heads/next \
		>out-$test_count 2>&1 &&
	make_user_friendly_and_stable_output <out-$test_count >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <COMMIT-A> <COMMIT-B> refs/heads/next        Z
	> remote: # post-receive hook        Z
	> remote: post-receive< <COMMIT-A> <COMMIT-B> refs/heads/next        Z
	> To <URL/of/upstream.shit>
	>    <COMMIT-A>..<COMMIT-B>  <COMMIT-B> -> next
	>  ! [rejected]        main -> main (non-fast-forward)
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-B> refs/heads/main
	<COMMIT-B> refs/heads/next
	EOF
'

# Refs of upstream : main(B)  next(B)
# Refs of workbench: main(A)           tags/v123
# shit-defecate -f      : main(A)  NULL     tags/v123  refs/review/main/topic(A)  a/b/c(A)
test_expect_success "shit-defecate -f ($PROTOCOL)" '
	shit -C workbench defecate -f origin \
		refs/tags/v123 \
		:refs/heads/next \
		main \
		main:refs/review/main/topic \
		HEAD:refs/heads/a/b/c \
		>out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <COMMIT-B> <COMMIT-A> refs/heads/main        Z
	> remote: pre-receive< <COMMIT-B> <ZERO-OID> refs/heads/next        Z
	> remote: pre-receive< <ZERO-OID> <TAG-v123> refs/tags/v123        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/review/main/topic        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/heads/a/b/c        Z
	> remote: # post-receive hook        Z
	> remote: post-receive< <COMMIT-B> <COMMIT-A> refs/heads/main        Z
	> remote: post-receive< <COMMIT-B> <ZERO-OID> refs/heads/next        Z
	> remote: post-receive< <ZERO-OID> <TAG-v123> refs/tags/v123        Z
	> remote: post-receive< <ZERO-OID> <COMMIT-A> refs/review/main/topic        Z
	> remote: post-receive< <ZERO-OID> <COMMIT-A> refs/heads/a/b/c        Z
	> To <URL/of/upstream.shit>
	>  + <COMMIT-B>...<COMMIT-A> main -> main (forced update)
	>  - [deleted]         next
	>  * [new tag]         v123 -> v123
	>  * [new reference]   main -> refs/review/main/topic
	>  * [new branch]      HEAD -> a/b/c
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/a/b/c
	<COMMIT-A> refs/heads/main
	<COMMIT-A> refs/review/main/topic
	<TAG-v123> refs/tags/v123
	EOF
'

# Refs of upstream : main(A)  tags/v123  refs/review/main/topic(A)  a/b/c(A)
# Refs of workbench: main(A)  tags/v123
test_expect_success "cleanup ($PROTOCOL)" '
	(
		cd "$upstream" &&
		shit update-ref -d refs/review/main/topic &&
		shit update-ref -d refs/tags/v123 &&
		shit update-ref -d refs/heads/a/b/c
	)
'
