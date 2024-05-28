#!/bin/sh

test_description='more shit add -u'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	>xyzzy &&
	_empty=$(shit hash-object --stdin <xyzzy) &&
	>yomin &&
	>caskly &&
	if test_have_prereq SYMLINKS; then
		ln -s frotz nitfol &&
		T_letter=T
	else
		printf %s frotz > nitfol &&
		T_letter=M
	fi &&
	mkdir rezrov &&
	>rezrov/bozbar &&
	shit add caskly xyzzy yomin nitfol rezrov/bozbar &&

	test_tick &&
	shit commit -m initial

'

test_expect_success modify '
	rm -f xyzzy yomin nitfol caskly &&
	# caskly disappears (not a submodule)
	mkdir caskly &&
	# nitfol changes from symlink to regular
	>nitfol &&
	# rezrov/bozbar disappears
	rm -fr rezrov &&
	if test_have_prereq SYMLINKS; then
		ln -s xyzzy rezrov
	else
		printf %s xyzzy > rezrov
	fi &&
	# xyzzy disappears (not a submodule)
	mkdir xyzzy &&
	echo gnusto >xyzzy/bozbar &&
	# yomin gets replaced with a submodule
	mkdir yomin &&
	>yomin/yomin &&
	(
		cd yomin &&
		shit init &&
		shit add yomin &&
		shit commit -m "sub initial"
	) &&
	yomin=$(shit_DIR=yomin/.shit shit rev-parse HEAD) &&
	# yonk is added and then turned into a submodule
	# this should appear as T in diff-files and as A in diff-index
	>yonk &&
	shit add yonk &&
	rm -f yonk &&
	mkdir yonk &&
	>yonk/yonk &&
	(
		cd yonk &&
		shit init &&
		shit add yonk &&
		shit commit -m "sub initial"
	) &&
	yonk=$(shit_DIR=yonk/.shit shit rev-parse HEAD) &&
	# zifmia is added and then removed
	# this should appear in diff-files but not in diff-index.
	>zifmia &&
	shit add zifmia &&
	rm -f zifmia &&
	mkdir zifmia &&
	{
		shit ls-tree -r HEAD |
		sed -e "s/^/:/" -e "
			/	caskly/{
				s/	caskly/ $ZERO_OID D&/
				s/blob/000000/
			}
			/	nitfol/{
				s/	nitfol/ $ZERO_OID $T_letter&/
				s/blob/100644/
			}
			/	rezrov.bozbar/{
				s/	rezrov.bozbar/ $ZERO_OID D&/
				s/blob/000000/
			}
			/	xyzzy/{
				s/	xyzzy/ $ZERO_OID D&/
				s/blob/000000/
			}
			/	yomin/{
			    s/	yomin/ $ZERO_OID T&/
				s/blob/160000/
			}
		"
	} >expect &&
	{
		cat expect &&
		echo ":100644 160000 $_empty $ZERO_OID T	yonk" &&
		echo ":100644 000000 $_empty $ZERO_OID D	zifmia"
	} >expect-files &&
	{
		cat expect &&
		echo ":000000 160000 $ZERO_OID $ZERO_OID A	yonk"
	} >expect-index &&
	{
		echo "100644 $_empty 0	nitfol" &&
		echo "160000 $yomin 0	yomin" &&
		echo "160000 $yonk 0	yonk"
	} >expect-final
'

test_expect_success diff-files '
	shit diff-files --raw >actual &&
	test_cmp expect-files actual
'

test_expect_success diff-index '
	shit diff-index --raw HEAD -- >actual &&
	test_cmp expect-index actual
'

test_expect_success 'add -u' '
	rm -f ".shit/saved-index" &&
	cp -p ".shit/index" ".shit/saved-index" &&
	shit add -u &&
	shit ls-files -s >actual &&
	test_cmp expect-final actual
'

test_expect_success 'commit -a' '
	if test -f ".shit/saved-index"
	then
		rm -f ".shit/index" &&
		mv ".shit/saved-index" ".shit/index"
	fi &&
	shit commit -m "second" -a &&
	shit ls-files -s >actual &&
	test_cmp expect-final actual &&
	rm -f .shit/index &&
	shit read-tree HEAD &&
	shit ls-files -s >actual &&
	test_cmp expect-final actual
'

test_done
