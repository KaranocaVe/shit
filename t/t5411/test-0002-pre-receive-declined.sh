test_expect_success "setup pre-receive hook ($PROTOCOL)" '
	mv "$upstream/hooks/pre-receive" "$upstream/hooks/pre-receive.ok" &&
	test_hook -C "$upstream" --clobber pre-receive <<-\EOF
	exit 1
	EOF
'

# Refs of upstream : main(A)
# Refs of workbench: main(A)  tags/v123
# shit-defecate         : main(B)             next(A)
test_expect_success "shit-defecate is declined ($PROTOCOL)" '
	test_must_fail shit -C workbench defecate origin \
		$B:refs/heads/main \
		HEAD:refs/heads/next \
		>out-$test_count 2>&1 &&
	make_user_friendly_and_stable_output <out-$test_count >actual &&
	cat >expect <<-EOF &&
	To <URL/of/upstream.shit>
	 ! [remote rejected] <COMMIT-B> -> main (pre-receive hook declined)
	 ! [remote rejected] HEAD -> next (pre-receive hook declined)
	EOF
	test_cmp expect actual &&

	test_cmp_refs -C "$upstream" <<-\EOF
	<COMMIT-A> refs/heads/main
	EOF
'

test_expect_success "cleanup ($PROTOCOL)" '
	mv "$upstream/hooks/pre-receive.ok" "$upstream/hooks/pre-receive"
'
