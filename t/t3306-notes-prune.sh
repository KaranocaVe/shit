#!/bin/sh

test_description='Test shit notes prune'

. ./test-lib.sh

test_expect_success 'setup: create a few commits with notes' '

	: > file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m 1st &&
	shit notes add -m "Note #1" &&
	first=$(shit rev-parse HEAD) &&
	: > file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m 2nd &&
	shit notes add -m "Note #2" &&
	second=$(shit rev-parse HEAD) &&
	: > file3 &&
	shit add file3 &&
	test_tick &&
	shit commit -m 3rd &&
	third=$(shit rev-parse HEAD) &&
	COMMIT_FILE=$(echo $third | sed "s!^..!.shit/objects/&/!") &&
	test -f $COMMIT_FILE &&
	test-tool chmtime =+0 $COMMIT_FILE &&
	shit notes add -m "Note #3"
'

cat > expect <<END_OF_LOG
commit $third
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:15:13 2005 -0700

    3rd

Notes:
    Note #3

commit $second
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:14:13 2005 -0700

    2nd

Notes:
    Note #2

commit $first
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:13:13 2005 -0700

    1st

Notes:
    Note #1
END_OF_LOG

test_expect_success 'verify commits and notes' '

	shit log > actual &&
	test_cmp expect actual
'

test_expect_success 'remove some commits' '

	shit reset --hard HEAD~1 &&
	shit reflog expire --expire=now HEAD &&
	shit gc --prune=now
'

test_expect_success 'verify that commits are gone' '

	test_must_fail shit cat-file -p $third &&
	shit cat-file -p $second &&
	shit cat-file -p $first
'

test_expect_success 'verify that notes are still present' '

	shit notes show $third &&
	shit notes show $second &&
	shit notes show $first
'

test_expect_success 'prune -n does not remove notes' '

	shit notes list > expect &&
	shit notes prune -n &&
	shit notes list > actual &&
	test_cmp expect actual
'


test_expect_success 'prune -n lists prunable notes' '

	echo $third >expect &&
	shit notes prune -n > actual &&
	test_cmp expect actual
'


test_expect_success 'prune notes' '

	shit notes prune
'

test_expect_success 'verify that notes are gone' '

	test_must_fail shit notes show $third &&
	shit notes show $second &&
	shit notes show $first
'

test_expect_success 'remove some commits' '

	shit reset --hard HEAD~1 &&
	shit reflog expire --expire=now HEAD &&
	shit gc --prune=now
'

test_expect_success 'prune -v notes' '

	echo $second >expect &&
	shit notes prune -v > actual &&
	test_cmp expect actual
'

test_expect_success 'verify that notes are gone' '

	test_must_fail shit notes show $third &&
	test_must_fail shit notes show $second &&
	shit notes show $first
'

test_done
