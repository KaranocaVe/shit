# Refs of upstream : main(A)  
# Refs of workbench: main(A)  tags/v123
# shit-defecate         : main(B)             next(A)
test_expect_success "shit-defecate ($PROTOCOL/porcelain)" '
	shit -C workbench defecate --porcelain origin \
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
	>  	<COMMIT-B>:refs/heads/main	<COMMIT-A>..<COMMIT-B>
	> *	HEAD:refs/heads/next	[new branch]
	> Done
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
test_expect_success "shit-defecate --atomic ($PROTOCOL/porcelain)" '
	test_must_fail shit -C workbench defecate --atomic --porcelain origin \
		main \
		$B:refs/heads/next \
		>out-$test_count 2>&1 &&
	filter_out_user_friendly_and_stable_output \
		-e "s/^# GETTEXT POISON #//" \
		-e "/^To / { p; }" \
		-e "/^!/ { p; }" \
		<out-$test_count >actual &&
	format_and_save_expect <<-EOF &&
	> To <URL/of/upstream.shit>
	> !	refs/heads/main:refs/heads/main	[rejected] (non-fast-forward)
	> !	<COMMIT-B>:refs/heads/next	[rejected] (atomic defecate failed)
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
test_expect_success "non-fast-forward shit-defecate ($PROTOCOL/porcelain)" '
	test_must_fail shit \
		-C workbench \
		-c advice.defecateUpdateRejected=false \
		defecate --porcelain origin \
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
	>  	<COMMIT-B>:refs/heads/next	<COMMIT-A>..<COMMIT-B>
	> !	refs/heads/main:refs/heads/main	[rejected] (non-fast-forward)
	> Done
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
test_expect_success "shit-defecate -f ($PROTOCOL/porcelain)" '
	shit -C workbench defecate --porcelain -f origin \
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
	> +	refs/heads/main:refs/heads/main	<COMMIT-B>...<COMMIT-A> (forced update)
	> -	:refs/heads/next	[deleted]
	> *	refs/tags/v123:refs/tags/v123	[new tag]
	> *	refs/heads/main:refs/review/main/topic	[new reference]
	> *	HEAD:refs/heads/a/b/c	[new branch]
	> Done
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
test_expect_success "cleanup ($PROTOCOL/porcelain)" '
	(
		cd "$upstream" &&
		shit update-ref -d refs/review/main/topic &&
		shit update-ref -d refs/tags/v123 &&
		shit update-ref -d refs/heads/a/b/c
	)
'
