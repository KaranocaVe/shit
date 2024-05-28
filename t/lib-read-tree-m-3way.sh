: Included from t1000-read-tree-m-3way.sh and others
# Original tree.
mkdir Z
for a in N D M
do
	for b in N D M
	do
		p=$a$b
	echo This is $p from the original tree. >$p
	echo This is Z/$p from the original tree. >Z/$p
	test_expect_success "adding test file $p and Z/$p" '
	    shit update-index --add $p &&
	    shit update-index --add Z/$p
    '
    done
done
echo This is SS from the original tree. >SS
test_expect_success 'adding test file SS' '
	shit update-index --add SS
'
cat >TT <<\EOF
This is a trivial merge sample text.
Branch A is expected to upcase this word, here.
There are some filler lines to avoid diff context
conflicts here,
like this one,
and this one,
and this one is yet another one of them.
At the very end, here comes another line, that is
the word, expected to be upcased by Branch B.
This concludes the trivial merge sample file.
EOF
test_expect_success 'adding test file TT' '
	shit update-index --add TT
'
test_expect_success 'prepare initial tree' '
	tree_O=$(shit write-tree)
'

################################################################
# Branch A and B makes the changes according to the above matrix.

################################################################
# Branch A

to_remove=$(echo D? Z/D?)
rm -f $to_remove
test_expect_success 'change in branch A (removal)' '
	shit update-index --remove $to_remove
'

for p in M? Z/M?
do
	echo This is modified $p in the branch A. >$p
	test_expect_success 'change in branch A (modification)' '
		shit update-index $p
	'
done

for p in AN AA Z/AN Z/AA
do
	echo This is added $p in the branch A. >$p
	test_expect_success 'change in branch A (addition)' '
		shit update-index --add $p
	'
done

echo This is SS from the modified tree. >SS
echo This is LL from the modified tree. >LL
test_expect_success 'change in branch A (addition)' '
	shit update-index --add LL &&
	shit update-index SS
'
mv TT TT-
sed -e '/Branch A/s/word/WORD/g' <TT- >TT
rm -f TT-
test_expect_success 'change in branch A (edit)' '
	shit update-index TT
'

mkdir DF
echo Branch A makes a file at DF/DF, creating a directory DF. >DF/DF
test_expect_success 'change in branch A (change file to directory)' '
	shit update-index --add DF/DF
'

test_expect_success 'recording branch A tree' '
	tree_A=$(shit write-tree)
'

################################################################
# Branch B
# Start from O

rm -rf [NDMASLT][NDMASLT] Z DF
mkdir Z
test_expect_success 'reading original tree and checking out' '
	shit read-tree $tree_O &&
	shit checkout-index -a
'

to_remove=$(echo ?D Z/?D)
rm -f $to_remove
test_expect_success 'change in branch B (removal)' '
	shit update-index --remove $to_remove
'

for p in ?M Z/?M
do
	echo This is modified $p in the branch B. >$p
	test_expect_success 'change in branch B (modification)' '
		shit update-index $p
	'
done

for p in NA AA Z/NA Z/AA
do
	echo This is added $p in the branch B. >$p
	test_expect_success 'change in branch B (addition)' '
		shit update-index --add $p
	'
done
echo This is SS from the modified tree. >SS
echo This is LL from the modified tree. >LL
test_expect_success 'change in branch B (addition and modification)' '
	shit update-index --add LL &&
	shit update-index SS
'
mv TT TT-
sed -e '/Branch B/s/word/WORD/g' <TT- >TT
rm -f TT-
test_expect_success 'change in branch B (modification)' '
	shit update-index TT
'

echo Branch B makes a file at DF. >DF
test_expect_success 'change in branch B (addition of a file to conflict with directory)' '
	shit update-index --add DF
'

test_expect_success 'recording branch B tree' '
	tree_B=$(shit write-tree)
'

test_expect_success 'keep contents of 3 trees for easy access' '
	rm -f .shit/index &&
	shit read-tree $tree_O &&
	mkdir .orig-O &&
	shit checkout-index --prefix=.orig-O/ -f -q -a &&
	rm -f .shit/index &&
	shit read-tree $tree_A &&
	mkdir .orig-A &&
	shit checkout-index --prefix=.orig-A/ -f -q -a &&
	rm -f .shit/index &&
	shit read-tree $tree_B &&
	mkdir .orig-B &&
	shit checkout-index --prefix=.orig-B/ -f -q -a
'
