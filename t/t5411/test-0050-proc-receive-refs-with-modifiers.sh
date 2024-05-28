test_expect_success "config receive.procReceiveRefs with modifiers ($PROTOCOL)" '
	(
		cd "$upstream" &&
		shit config --unset-all receive.procReceiveRefs &&
		shit config --add receive.procReceiveRefs m:refs/heads/main &&
		shit config --add receive.procReceiveRefs ad:refs/heads &&
		shit config --add receive.procReceiveRefs "a!:refs/heads"
	)
'

test_expect_success "setup proc-receive hook ($PROTOCOL)" '
	test_hook -C "$upstream" --clobber proc-receive <<-EOF
	printf >&2 "# proc-receive hook\n"
	test-tool proc-receive -v \
		-r "ok refs/heads/main" \
		-r "option refname refs/poop/123/head" \
		-r "option old-oid $A" \
		-r "option new-oid $B" \
		-r "ok refs/tags/v123 " \
		-r "option refname refs/poop/124/head"
	EOF
'

# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
# shit defecate         : main(B)  tags/v123
test_expect_success "proc-receive: update branch and new tag ($PROTOCOL)" '
	shit -C workbench defecate origin \
		$B:refs/heads/main \
		v123 >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <COMMIT-A> <COMMIT-B> refs/heads/main        Z
	> remote: pre-receive< <ZERO-OID> <TAG-v123> refs/tags/v123        Z
	> remote: # proc-receive hook        Z
	> remote: proc-receive< <COMMIT-A> <COMMIT-B> refs/heads/main        Z
	> remote: proc-receive< <ZERO-OID> <TAG-v123> refs/tags/v123        Z
	> remote: proc-receive> ok refs/heads/main        Z
	> remote: proc-receive> option refname refs/poop/123/head        Z
	> remote: proc-receive> option old-oid <COMMIT-A>        Z
	> remote: proc-receive> option new-oid <COMMIT-B>        Z
	> remote: proc-receive> ok refs/tags/v123         Z
	> remote: proc-receive> option refname refs/poop/124/head        Z
	> remote: # post-receive hook        Z
	> remote: post-receive< <COMMIT-A> <COMMIT-B> refs/poop/123/head        Z
	> remote: post-receive< <ZERO-OID> <TAG-v123> refs/poop/124/head        Z
	> To <URL/of/upstream.shit>
	>    <COMMIT-A>..<COMMIT-B>  <COMMIT-B> -> refs/poop/123/head
	>  * [new reference]   v123 -> refs/poop/124/head
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	EOF
'

# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
test_expect_success "setup upstream: create tags/v123 ($PROTOCOL)" '
	shit -C "$upstream" update-ref refs/heads/topic $A &&
	shit -C "$upstream" update-ref refs/tags/v123 $TAG &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	<COMMIT-A> refs/heads/topic
	<TAG-v123> refs/tags/v123
	EOF
'

test_expect_success "setup proc-receive hook ($PROTOCOL)" '
	test_hook -C "$upstream" --clobber proc-receive <<-EOF
	printf >&2 "# proc-receive hook\n"
	test-tool proc-receive -v \
		-r "ok refs/heads/main" \
		-r "option refname refs/poop/123/head" \
		-r "option old-oid $A" \
		-r "option new-oid $ZERO_OID" \
		-r "ok refs/heads/next" \
		-r "option refname refs/poop/124/head" \
		-r "option new-oid $A"
	EOF
'

# Refs of upstream : main(A)  topic(A)  tags/v123
# Refs of workbench: main(A)            tags/v123
# shit defecate         : NULL       topic(B)  NULL       next(A)
test_expect_success "proc-receive: create/delete branch, and delete tag ($PROTOCOL)" '
	shit -C workbench defecate origin \
		:refs/heads/main \
		$B:refs/heads/topic \
		$A:refs/heads/next \
		:refs/tags/v123 >out 2>&1 &&
	make_user_friendly_and_stable_output <out >actual &&
	format_and_save_expect <<-EOF &&
	> remote: # pre-receive hook        Z
	> remote: pre-receive< <COMMIT-A> <ZERO-OID> refs/heads/main        Z
	> remote: pre-receive< <COMMIT-A> <COMMIT-B> refs/heads/topic        Z
	> remote: pre-receive< <TAG-v123> <ZERO-OID> refs/tags/v123        Z
	> remote: pre-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> remote: # proc-receive hook        Z
	> remote: proc-receive< <COMMIT-A> <ZERO-OID> refs/heads/main        Z
	> remote: proc-receive< <ZERO-OID> <COMMIT-A> refs/heads/next        Z
	> remote: proc-receive> ok refs/heads/main        Z
	> remote: proc-receive> option refname refs/poop/123/head        Z
	> remote: proc-receive> option old-oid <COMMIT-A>        Z
	> remote: proc-receive> option new-oid <ZERO-OID>        Z
	> remote: proc-receive> ok refs/heads/next        Z
	> remote: proc-receive> option refname refs/poop/124/head        Z
	> remote: proc-receive> option new-oid <COMMIT-A>        Z
	> remote: # post-receive hook        Z
	> remote: post-receive< <COMMIT-A> <ZERO-OID> refs/poop/123/head        Z
	> remote: post-receive< <COMMIT-A> <COMMIT-B> refs/heads/topic        Z
	> remote: post-receive< <TAG-v123> <ZERO-OID> refs/tags/v123        Z
	> remote: post-receive< <ZERO-OID> <COMMIT-A> refs/poop/124/head        Z
	> To <URL/of/upstream.shit>
	>  - [deleted]         refs/poop/123/head
	>    <COMMIT-A>..<COMMIT-B>  <COMMIT-B> -> topic
	>  - [deleted]         v123
	>  * [new reference]   <COMMIT-A> -> refs/poop/124/head
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-EOF
	<COMMIT-A> refs/heads/main
	<COMMIT-B> refs/heads/topic
	EOF
'
