# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
# shit defecate         :                       next(A)  refs/for/main/topic(A)
test_expect_success "proc-receive: no hook, fail to defecate special ref ($PROTOCOL/porcelain)" '
	test_must_fail shit -C workbench defecate --porcelain origin \
		HEAD:next \
		HEAD:refs/for/main/topic \
		>out-$test_count 2>&1 &&
	make_user_friendly_and_stable_output <out-$test_count >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/for/main/topic        Z
	> remote: error: cannot find hook "proc-receive"        Z
	> remote: # post-receive hook        Z
	> remote: post-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> To <URL/of/upstream.shit>
	> *	HEAD:refs/heads/next	[new branch]
	> !	HEAD:refs/for/main/topic	[remote rejected] (fail to run proc-receive hook)
	Done
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	<COMMIT-A> refs/heads/next
	EOF
'

# Refs of upstream : main(A)             next(A)
# Refs of workbench: main(A)  tags/v123
test_expect_success "cleanup ($PROTOCOL/porcelain)" '
	shit -C "$upstream" update-ref -d refs/heads/next
'

# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
# shit defecate --atomic: (B)                   next(A)  refs/for/main/topic(A)
test_expect_success "proc-receive: no hook, all failed for atomic defecate ($PROTOCOL/porcelain)" '
	test_must_fail shit -C workbench defecate --porcelain --atomic origin \
		$B:main \
		HEAD:next \
		HEAD:refs/for/main/topic >out-$test_count 2>&1 &&
	make_user_friendly_and_stable_output <out-$test_count >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <COMMIT-A> <COMMIT-B> refs/heads/main        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/for/main/topic        Z
	> remote: error: cannot find hook "proc-receive"        Z
	> To <URL/of/upstream.shit>
	> !	<COMMIT-B>:refs/heads/main	[remote rejected] (fail to run proc-receive hook)
	> !	HEAD:refs/heads/next	[remote rejected] (fail to run proc-receive hook)
	> !	HEAD:refs/for/main/topic	[remote rejected] (fail to run proc-receive hook)
	> Done
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	EOF
'
