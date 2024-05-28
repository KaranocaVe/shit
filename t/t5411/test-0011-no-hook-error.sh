# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
# shit defecate         :                       next(A)  refs/for/main/topic(A)
test_expect_success "proc-receive: no hook, fail to defecate special ref ($PROTOCOL)" '
	test_must_fail shit -C workbench defecate origin \
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
	>  * [new branch]      HEAD -> next
	>  ! [remote rejected] HEAD -> refs/for/main/topic (fail to run proc-receive hook)
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	<COMMIT-A> refs/heads/next
	EOF
'

# Refs of upstream : main(A)             next(A)
# Refs of workbench: main(A)  tags/v123
test_expect_success "cleanup ($PROTOCOL)" '
	shit -C "$upstream" update-ref -d refs/heads/next
'

# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
# shit defecate --atomic: (B)                   next(A)  refs/for/main/topic(A)
test_expect_success "proc-receive: no hook, all failed for atomic defecate ($PROTOCOL)" '
	test_must_fail shit -C workbench defecate --atomic origin \
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
	>  ! [remote rejected] <COMMIT-B> -> main (fail to run proc-receive hook)
	>  ! [remote rejected] HEAD -> next (fail to run proc-receive hook)
	>  ! [remote rejected] HEAD -> refs/for/main/topic (fail to run proc-receive hook)
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	EOF
'
