#!/bin/sh
# Copyright (c) 2011, Google Inc.

test_description='adding and checking out large blobs'

. ./test-lib.sh

test_expect_success 'core.bigFileThreshold must be non-negative' '
	test_must_fail shit -c core.bigFileThreshold=-1 rev-parse >out 2>err &&
	grep "bad numeric config value" err &&
	test_must_be_empty out
'

test_expect_success setup '
	# clone does not allow us to pass core.bigfilethreshold to
	# new repos, so set core.bigfilethreshold globally
	shit config --global core.bigfilethreshold 200k &&
	printf "%2000000s" X >large1 &&
	cp large1 large2 &&
	cp large1 large3 &&
	printf "%2500000s" Y >huge &&
	shit_ALLOC_LIMIT=1500k &&
	export shit_ALLOC_LIMIT
'

test_expect_success 'enter "large" codepath, with small core.bigFileThreshold' '
	test_when_finished "rm -rf repo" &&

	shit init --bare repo &&
	echo large | shit -C repo hash-object -w --stdin &&
	shit -C repo -c core.bigfilethreshold=4 fsck
'

# add a large file with different settings
while read expect config
do
	test_expect_success "add with $config" '
		test_when_finished "rm -f .shit/objects/pack/pack-*.* .shit/index" &&
		shit $config add large1 &&
		sz=$(test_file_size .shit/objects/pack/pack-*.pack) &&
		case "$expect" in
		small) test "$sz" -le 100000 ;;
		large) test "$sz" -ge 100000 ;;
		esac
	'
done <<\EOF
large -c core.compression=0
small -c core.compression=9
large -c core.compression=0 -c pack.compression=0
large -c core.compression=9 -c pack.compression=0
small -c core.compression=0 -c pack.compression=9
small -c core.compression=9 -c pack.compression=9
large -c pack.compression=0
small -c pack.compression=9
EOF

test_expect_success 'add a large file or two' '
	shit add large1 huge large2 &&
	# make sure we got a single packfile and no loose objects
	count=0 idx= &&
	for p in .shit/objects/pack/pack-*.pack
	do
		count=$(( $count + 1 )) &&
		test_path_is_file "$p" &&
		idx=${p%.pack}.idx &&
		test_path_is_file "$idx" || return 1
	done &&
	test $count = 1 &&
	cnt=$(shit show-index <"$idx" | wc -l) &&
	test $cnt = 2 &&
	for l in .shit/objects/$OIDPATH_REGEX
	do
		test_path_is_missing "$l" || return 1
	done &&

	# attempt to add another copy of the same
	shit add large3 &&
	bad= count=0 &&
	for p in .shit/objects/pack/pack-*.pack
	do
		count=$(( $count + 1 )) &&
		test_path_is_file "$p" &&
		idx=${p%.pack}.idx &&
		test_path_is_file "$idx" || return 1
	done &&
	test $count = 1
'

test_expect_success 'checkout a large file' '
	large1=$(shit rev-parse :large1) &&
	shit update-index --add --cacheinfo 100644 $large1 another &&
	shit checkout another &&
	test_cmp large1 another
'

test_expect_success 'packsize limit' '
	test_create_repo mid &&
	(
		cd mid &&
		shit config core.bigfilethreshold 64k &&
		shit config pack.packsizelimit 256k &&

		# mid1 and mid2 will fit within 256k limit but
		# appending mid3 will bust the limit and will
		# result in a separate packfile.
		test-tool genrandom "a" $(( 66 * 1024 )) >mid1 &&
		test-tool genrandom "b" $(( 80 * 1024 )) >mid2 &&
		test-tool genrandom "c" $(( 128 * 1024 )) >mid3 &&
		shit add mid1 mid2 mid3 &&

		count=0 &&
		for pi in .shit/objects/pack/pack-*.idx
		do
			test_path_is_file "$pi" && count=$(( $count + 1 )) || return 1
		done &&
		test $count = 2 &&

		(
			shit hash-object --stdin <mid1 &&
			shit hash-object --stdin <mid2 &&
			shit hash-object --stdin <mid3
		) |
		sort >expect &&

		for pi in .shit/objects/pack/pack-*.idx
		do
			shit show-index <"$pi" || return 1
		done |
		sed -e "s/^[0-9]* \([0-9a-f]*\) .*/\1/" |
		sort >actual &&

		test_cmp expect actual
	)
'

test_expect_success 'diff --raw' '
	shit commit -q -m initial &&
	echo modified >>large1 &&
	shit add large1 &&
	shit commit -q -m modified &&
	shit diff --raw HEAD^
'

test_expect_success 'diff --stat' '
	shit diff --stat HEAD^ HEAD
'

test_expect_success 'diff' '
	shit diff HEAD^ HEAD >actual &&
	grep "Binary files.*differ" actual
'

test_expect_success 'diff --cached' '
	shit diff --cached HEAD^ >actual &&
	grep "Binary files.*differ" actual
'

test_expect_success 'hash-object' '
	shit hash-object large1
'

test_expect_success 'cat-file a large file' '
	shit cat-file blob :large1 >/dev/null
'

test_expect_success 'cat-file a large file from a tag' '
	shit tag -m largefile largefiletag :large1 &&
	shit cat-file blob largefiletag >/dev/null
'

test_expect_success 'shit-show a large file' '
	shit show :large1 >/dev/null

'

test_expect_success 'index-pack' '
	shit clone file://"$(pwd)"/.shit foo &&
	shit_DIR=non-existent shit index-pack --object-format=$(test_oid algo) \
		--strict --verify foo/.shit/objects/pack/*.pack
'

test_expect_success 'repack' '
	shit repack -ad
'

test_expect_success 'pack-objects with large loose object' '
	SHA1=$(shit hash-object huge) &&
	test_create_repo loose &&
	echo $SHA1 | shit pack-objects --stdout |
		shit_ALLOC_LIMIT=0 shit_DIR=loose/.shit shit unpack-objects &&
	echo $SHA1 | shit_DIR=loose/.shit shit pack-objects pack &&
	test_create_repo packed &&
	mv pack-* packed/.shit/objects/pack &&
	shit_DIR=packed/.shit shit cat-file blob $SHA1 >actual &&
	test_cmp huge actual
'

test_expect_success 'tar archiving' '
	shit archive --format=tar HEAD >/dev/null
'

test_expect_success 'zip archiving, store only' '
	shit archive --format=zip -0 HEAD >/dev/null
'

test_expect_success 'zip archiving, deflate' '
	shit archive --format=zip HEAD >/dev/null
'

test_expect_success 'fsck large blobs' '
	shit fsck 2>err &&
	test_must_be_empty err
'

test_done
