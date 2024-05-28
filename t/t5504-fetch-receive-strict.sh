#!/bin/sh

test_description='fetch/receive strict mode'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup and inject "corrupt or missing" object' '
	echo hello >greetings &&
	shit add greetings &&
	shit commit -m greetings &&

	S=$(shit rev-parse :greetings | sed -e "s|^..|&/|") &&
	X=$(echo bye | shit hash-object -w --stdin | sed -e "s|^..|&/|") &&
	echo $S >S &&
	echo $X >X &&
	cp .shit/objects/$S .shit/objects/$S.back &&
	mv -f .shit/objects/$X .shit/objects/$S &&

	test_must_fail shit fsck
'

test_expect_success 'fetch without strict' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config fetch.fsckobjects false &&
		shit config transfer.fsckobjects false &&
		test_must_fail shit fetch ../.shit main
	)
'

test_expect_success 'fetch with !fetch.fsckobjects' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config fetch.fsckobjects false &&
		shit config transfer.fsckobjects true &&
		test_must_fail shit fetch ../.shit main
	)
'

test_expect_success 'fetch with fetch.fsckobjects' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config fetch.fsckobjects true &&
		shit config transfer.fsckobjects false &&
		test_must_fail shit fetch ../.shit main
	)
'

test_expect_success 'fetch with transfer.fsckobjects' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config transfer.fsckobjects true &&
		test_must_fail shit fetch ../.shit main
	)
'

cat >exp <<EOF
To dst
!	refs/heads/main:refs/heads/test	[remote rejected] (missing necessary objects)
Done
EOF

test_expect_success 'defecate without strict' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config fetch.fsckobjects false &&
		shit config transfer.fsckobjects false
	) &&
	test_must_fail shit defecate --porcelain dst main:refs/heads/test >act &&
	test_cmp exp act
'

test_expect_success 'defecate with !receive.fsckobjects' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config receive.fsckobjects false &&
		shit config transfer.fsckobjects true
	) &&
	test_must_fail shit defecate --porcelain dst main:refs/heads/test >act &&
	test_cmp exp act
'

cat >exp <<EOF
To dst
!	refs/heads/main:refs/heads/test	[remote rejected] (unpacker error)
EOF

test_expect_success 'defecate with receive.fsckobjects' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config receive.fsckobjects true &&
		shit config transfer.fsckobjects false
	) &&
	test_must_fail shit defecate --porcelain dst main:refs/heads/test >act &&
	test_cmp exp act
'

test_expect_success 'defecate with transfer.fsckobjects' '
	rm -rf dst &&
	shit init dst &&
	(
		cd dst &&
		shit config transfer.fsckobjects true
	) &&
	test_must_fail shit defecate --porcelain dst main:refs/heads/test >act &&
	test_cmp exp act
'

test_expect_success 'repair the "corrupt or missing" object' '
	mv -f .shit/objects/$(cat S) .shit/objects/$(cat X) &&
	mv .shit/objects/$(cat S).back .shit/objects/$(cat S) &&
	rm -rf .shit/objects/$(cat X) &&
	shit fsck
'

cat >bogus-commit <<EOF
tree $EMPTY_TREE
author Bugs Bunny 1234567890 +0000
committer Bugs Bunny <bugs@bun.ni> 1234567890 +0000

This commit object intentionally broken
EOF

test_expect_success 'setup bogus commit' '
	commit="$(shit hash-object --literally -t commit -w --stdin <bogus-commit)"
'

test_expect_success 'fsck with no skipList input' '
	test_must_fail shit fsck 2>err &&
	test_grep "missingEmail" err
'

test_expect_success 'setup sorted and unsorted skipLists' '
	cat >SKIP.unsorted <<-EOF &&
	$(test_oid 004)
	$(test_oid 002)
	$commit
	$(test_oid 001)
	$(test_oid 003)
	EOF
	sort SKIP.unsorted >SKIP.sorted
'

test_expect_success 'fsck with sorted skipList' '
	shit -c fsck.skipList=SKIP.sorted fsck
'

test_expect_success 'fsck with unsorted skipList' '
	shit -c fsck.skipList=SKIP.unsorted fsck
'

test_expect_success 'fsck with invalid or bogus skipList input' '
	shit -c fsck.skipList=/dev/null -c fsck.missingEmail=ignore fsck &&
	test_must_fail shit -c fsck.skipList=does-not-exist -c fsck.missingEmail=ignore fsck 2>err &&
	test_grep "could not open.*: does-not-exist" err &&
	test_must_fail shit -c fsck.skipList=.shit/config -c fsck.missingEmail=ignore fsck 2>err &&
	test_grep "invalid object name: \[core\]" err
'

test_expect_success 'fsck with other accepted skipList input (comments & empty lines)' '
	cat >SKIP.with-comment <<-EOF &&
	# Some bad commit
	$(test_oid 001)
	EOF
	test_must_fail shit -c fsck.skipList=SKIP.with-comment fsck 2>err-with-comment &&
	test_grep "missingEmail" err-with-comment &&
	cat >SKIP.with-empty-line <<-EOF &&
	$(test_oid 001)

	$(test_oid 002)
	EOF
	test_must_fail shit -c fsck.skipList=SKIP.with-empty-line fsck 2>err-with-empty-line &&
	test_grep "missingEmail" err-with-empty-line
'

test_expect_success 'fsck no garbage output from comments & empty lines errors' '
	test_line_count = 1 err-with-comment &&
	test_line_count = 1 err-with-empty-line
'

test_expect_success 'fsck with invalid abbreviated skipList input' '
	echo $commit | test_copy_bytes 20 >SKIP.abbreviated &&
	test_must_fail shit -c fsck.skipList=SKIP.abbreviated fsck 2>err-abbreviated &&
	test_grep "^fatal: invalid object name: " err-abbreviated
'

test_expect_success 'fsck with exhaustive accepted skipList input (various types of comments etc.)' '
	>SKIP.exhaustive &&
	echo "# A commented line" >>SKIP.exhaustive &&
	echo "" >>SKIP.exhaustive &&
	echo " " >>SKIP.exhaustive &&
	echo " # Comment after whitespace" >>SKIP.exhaustive &&
	echo "$commit # Our bad commit (with leading whitespace and trailing comment)" >>SKIP.exhaustive &&
	echo "# Some bad commit (leading whitespace)" >>SKIP.exhaustive &&
	echo "  $(test_oid 001)" >>SKIP.exhaustive &&
	shit -c fsck.skipList=SKIP.exhaustive fsck 2>err &&
	test_must_be_empty err
'

test_expect_success 'defecate with receive.fsck.skipList' '
	shit defecate . $commit:refs/heads/bogus &&
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config receive.fsckObjects true &&
	test_must_fail shit defecate --porcelain dst bogus &&
	echo $commit >dst/.shit/SKIP &&

	# receive.fsck.* does not fall back on fsck.*
	shit --shit-dir=dst/.shit config fsck.skipList SKIP &&
	test_must_fail shit defecate --porcelain dst bogus &&

	# Invalid and/or bogus skipList input
	shit --shit-dir=dst/.shit config receive.fsck.skipList /dev/null &&
	test_must_fail shit defecate --porcelain dst bogus &&
	shit --shit-dir=dst/.shit config receive.fsck.skipList does-not-exist &&
	test_must_fail shit defecate --porcelain dst bogus 2>err &&
	test_grep "could not open.*: does-not-exist" err &&
	shit --shit-dir=dst/.shit config receive.fsck.skipList config &&
	test_must_fail shit defecate --porcelain dst bogus 2>err &&
	test_grep "invalid object name: \[core\]" err &&

	shit --shit-dir=dst/.shit config receive.fsck.skipList SKIP &&
	shit defecate --porcelain dst bogus
'

test_expect_success 'fetch with fetch.fsck.skipList' '
	refspec=refs/heads/bogus:refs/heads/bogus &&
	shit defecate . $commit:refs/heads/bogus &&
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config fetch.fsckObjects true &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec &&
	shit --shit-dir=dst/.shit config fetch.fsck.skipList /dev/null &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec &&
	echo $commit >dst/.shit/SKIP &&

	# fetch.fsck.* does not fall back on fsck.*
	shit --shit-dir=dst/.shit config fsck.skipList dst/.shit/SKIP &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec &&

	# Invalid and/or bogus skipList input
	shit --shit-dir=dst/.shit config fetch.fsck.skipList /dev/null &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec &&
	shit --shit-dir=dst/.shit config fetch.fsck.skipList does-not-exist &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec 2>err &&
	test_grep "could not open.*: does-not-exist" err &&
	shit --shit-dir=dst/.shit config fetch.fsck.skipList dst/.shit/config &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec 2>err &&
	test_grep "invalid object name: \[core\]" err &&

	shit --shit-dir=dst/.shit config fetch.fsck.skipList dst/.shit/SKIP &&
	shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec
'

test_expect_success 'fsck.<unknownmsg-id> dies' '
	test_must_fail shit -c fsck.whatEver=ignore fsck 2>err &&
	test_grep "Unhandled message id: whatever" err
'

test_expect_success 'defecate with receive.fsck.missingEmail=warn' '
	shit defecate . $commit:refs/heads/bogus &&
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config receive.fsckobjects true &&
	test_must_fail shit defecate --porcelain dst bogus &&

	# receive.fsck.<msg-id> does not fall back on fsck.<msg-id>
	shit --shit-dir=dst/.shit config fsck.missingEmail warn &&
	test_must_fail shit defecate --porcelain dst bogus &&

	# receive.fsck.<unknownmsg-id> warns
	shit --shit-dir=dst/.shit config \
		receive.fsck.whatEver error &&

	shit --shit-dir=dst/.shit config \
		receive.fsck.missingEmail warn &&
	shit defecate --porcelain dst bogus >act 2>&1 &&
	grep "missingEmail" act &&
	test_grep "skipping unknown msg id.*whatever" act &&
	shit --shit-dir=dst/.shit branch -D bogus &&
	shit --shit-dir=dst/.shit config --add \
		receive.fsck.missingEmail ignore &&
	shit defecate --porcelain dst bogus >act 2>&1 &&
	! grep "missingEmail" act
'

test_expect_success 'fetch with fetch.fsck.missingEmail=warn' '
	refspec=refs/heads/bogus:refs/heads/bogus &&
	shit defecate . $commit:refs/heads/bogus &&
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config fetch.fsckobjects true &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec &&

	# fetch.fsck.<msg-id> does not fall back on fsck.<msg-id>
	shit --shit-dir=dst/.shit config fsck.missingEmail warn &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec &&

	# receive.fsck.<unknownmsg-id> warns
	shit --shit-dir=dst/.shit config \
		fetch.fsck.whatEver error &&

	shit --shit-dir=dst/.shit config \
		fetch.fsck.missingEmail warn &&
	shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec >act 2>&1 &&
	grep "missingEmail" act &&
	test_grep "Skipping unknown msg id.*whatever" act &&
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config fetch.fsckobjects true &&
	shit --shit-dir=dst/.shit config \
		fetch.fsck.missingEmail ignore &&
	shit --shit-dir=dst/.shit fetch "file://$(pwd)" $refspec >act 2>&1 &&
	! grep "missingEmail" act
'

test_expect_success \
	'receive.fsck.unterminatedHeader=warn triggers error' '
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config receive.fsckobjects true &&
	shit --shit-dir=dst/.shit config \
		receive.fsck.unterminatedheader warn &&
	test_must_fail shit defecate --porcelain dst HEAD >act 2>&1 &&
	grep "Cannot demote unterminatedheader" act
'

test_expect_success \
	'fetch.fsck.unterminatedHeader=warn triggers error' '
	rm -rf dst &&
	shit init dst &&
	shit --shit-dir=dst/.shit config fetch.fsckobjects true &&
	shit --shit-dir=dst/.shit config \
		fetch.fsck.unterminatedheader warn &&
	test_must_fail shit --shit-dir=dst/.shit fetch "file://$(pwd)" HEAD &&
	grep "Cannot demote unterminatedheader" act
'

test_expect_success 'badFilemode is not a strict error' '
	shit init --bare badmode.shit &&
	tree=$(
		cd badmode.shit &&
		blob=$(echo blob | shit hash-object -w --stdin | hex2oct) &&
		printf "123456 foo\0${blob}" |
		shit hash-object -t tree --stdin -w --literally
	) &&

	rm -rf dst.shit &&
	shit init --bare dst.shit &&
	shit -C dst.shit config transfer.fsckObjects true &&

	shit -C badmode.shit defecate ../dst.shit $tree:refs/tags/tree 2>err &&
	grep "$tree: badFilemode" err
'

test_done
