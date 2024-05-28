test_expect_success "add two receive.procReceiveRefs settings" '
	(
		cd "$upstream" &&
		shit config --add receive.procReceiveRefs refs/for &&
		shit config --add receive.procReceiveRefs refs/review/
	)
'
