#!/bin/sh

test_description='Clone repositories and store files in shit LFS'

. ./lib-shit-p4.sh

shit lfs help >/dev/null 2>&1 || {
	skip_all='skipping shit p4 shit LFS tests; shit LFS not found'
	test_done
}

test_file_in_lfs () {
	FILE="$1" &&
	SIZE="$2" &&
	EXPECTED_CONTENT="$3" &&
	sed -n '1,1 p' "$FILE" | grep "^version " &&
	sed -n '2,2 p' "$FILE" | grep "^oid " &&
	sed -n '3,3 p' "$FILE" | grep "^size " &&
	test_line_count = 3 "$FILE" &&
	grep "size $SIZE" "$FILE" &&
	HASH=$(sed -ne "/oid sha256:/s/oid sha256://gp" "$FILE") &&
	LFS_FILE=".shit/lfs/objects/$(echo "$HASH" | cut -c1-2)/$(echo "$HASH" | cut -c3-4)/$HASH" &&
	echo $EXPECTED_CONTENT >expect &&
	test_path_is_file "$FILE" &&
	test_path_is_file "$LFS_FILE" &&
	test_cmp expect "$LFS_FILE"
}

test_file_count_in_dir () {
	DIR="$1" &&
	EXPECTED_COUNT="$2" &&
	find "$DIR" -type f >actual &&
	test_line_count = $EXPECTED_COUNT actual
}

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'Create repo with binary files' '
	client_view "//depot/... //client/..." &&
	(
		cd "$cli" &&

		>file0.dat &&
		p4 add file0.dat &&
		echo "content 1 txt 23 bytes" >file1.txt &&
		p4 add file1.txt &&
		echo "content 2-3 bin 25 bytes" >file2.dat &&
		p4 add file2.dat &&
		p4 submit -d "Add text and binary file" &&

		mkdir "path with spaces" &&
		echo "content 2-3 bin 25 bytes" >"path with spaces/file3.bin" &&
		p4 add "path with spaces/file3.bin" &&
		p4 submit -d "Add another binary file with same content and spaces in path" &&

		echo "content 4 bin 26 bytes XX" >file4.bin &&
		p4 add file4.bin &&
		p4 submit -d "Add another binary file with different content"
	)
'

test_expect_success 'Store files in LFS based on size (>24 bytes)' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileThreshold 24 &&
		shit p4 clone --destination="$shit" //depot@all &&

		test_file_in_lfs file2.dat 25 "content 2-3 bin 25 bytes" &&
		test_file_in_lfs "path with spaces/file3.bin" 25 "content 2-3 bin 25 bytes" &&
		test_file_in_lfs file4.bin 26 "content 4 bin 26 bytes XX" &&

		test_file_count_in_dir ".shit/lfs/objects" 2 &&

		cat >expect <<-\EOF &&

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		/file2.dat filter=lfs diff=lfs merge=lfs -text
		/file4.bin filter=lfs diff=lfs merge=lfs -text
		/path[[:space:]]with[[:space:]]spaces/file3.bin filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_expect_success 'Store files in LFS based on size (>25 bytes)' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileThreshold 25 &&
		shit p4 clone --destination="$shit" //depot@all &&

		test_file_in_lfs file4.bin 26 "content 4 bin 26 bytes XX" &&
		test_file_count_in_dir ".shit/lfs/objects" 1 &&

		cat >expect <<-\EOF &&

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		/file4.bin filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_expect_success 'Store files in LFS based on extension (dat)' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileExtensions dat &&
		shit p4 clone --destination="$shit" //depot@all &&

		test_file_in_lfs file2.dat 25 "content 2-3 bin 25 bytes" &&
		test_file_count_in_dir ".shit/lfs/objects" 1 &&

		cat >expect <<-\EOF &&

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		*.dat filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_expect_success 'Store files in LFS based on size (>25 bytes) and extension (dat)' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileExtensions dat &&
		shit config shit-p4.largeFileThreshold 25 &&
		shit p4 clone --destination="$shit" //depot@all &&

		test_file_in_lfs file2.dat 25 "content 2-3 bin 25 bytes" &&
		test_file_in_lfs file4.bin 26 "content 4 bin 26 bytes XX" &&
		test_file_count_in_dir ".shit/lfs/objects" 2 &&

		cat >expect <<-\EOF &&

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		*.dat filter=lfs diff=lfs merge=lfs -text
		/file4.bin filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_expect_success 'Remove file from repo and store files in LFS based on size (>24 bytes)' '
	client_view "//depot/... //client/..." &&
	(
		cd "$cli" &&
		p4 delete file4.bin &&
		p4 submit -d "Remove file"
	) &&

	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileThreshold 24 &&
		shit p4 clone --destination="$shit" //depot@all &&

		test_file_in_lfs file2.dat 25 "content 2-3 bin 25 bytes" &&
		test_file_in_lfs "path with spaces/file3.bin" 25 "content 2-3 bin 25 bytes" &&
		test_path_is_missing file4.bin &&
		test_file_count_in_dir ".shit/lfs/objects" 2 &&

		cat >expect <<-\EOF &&

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		/file2.dat filter=lfs diff=lfs merge=lfs -text
		/path[[:space:]]with[[:space:]]spaces/file3.bin filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_expect_success 'Add .shitattributes and store files in LFS based on size (>24 bytes)' '
	client_view "//depot/... //client/..." &&
	(
		cd "$cli" &&
		echo "*.txt text" >.shitattributes &&
		p4 add .shitattributes &&
		p4 submit -d "Add .shitattributes"
	) &&

	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileThreshold 24 &&
		shit p4 clone --destination="$shit" //depot@all &&

		test_file_in_lfs file2.dat 25 "content 2-3 bin 25 bytes" &&
		test_file_in_lfs "path with spaces/file3.bin" 25 "content 2-3 bin 25 bytes" &&
		test_path_is_missing file4.bin &&
		test_file_count_in_dir ".shit/lfs/objects" 2 &&

		cat >expect <<-\EOF &&
		*.txt text

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		/file2.dat filter=lfs diff=lfs merge=lfs -text
		/path[[:space:]]with[[:space:]]spaces/file3.bin filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_expect_success 'Add big files to repo and store files in LFS based on compressed size (>28 bytes)' '
	client_view "//depot/... //client/..." &&
	(
		cd "$cli" &&
		echo "content 5 bin 40 bytes XXXXXXXXXXXXXXXX" >file5.bin &&
		p4 add file5.bin &&
		p4 submit -d "Add file with small footprint after compression" &&

		echo "content 6 bin 39 bytes XXXXXYYYYYZZZZZ" >file6.bin &&
		p4 add file6.bin &&
		p4 submit -d "Add file with large footprint after compression"
	) &&

	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit init . &&
		shit config shit-p4.useClientSpec true &&
		shit config shit-p4.largeFileSystem shitLFS &&
		shit config shit-p4.largeFileCompressedThreshold 28 &&
		# We only import HEAD here ("@all" is missing!)
		shit p4 clone --destination="$shit" //depot &&

		test_file_in_lfs file6.bin 39 "content 6 bin 39 bytes XXXXXYYYYYZZZZZ" &&
		test_file_count_in_dir ".shit/lfs/objects" 1 &&

		cat >expect <<-\EOF &&
		*.txt text

		#
		# shit LFS (see https://shit-lfs.shithub.com/)
		#
		/file6.bin filter=lfs diff=lfs merge=lfs -text
		EOF
		test_path_is_file .shitattributes &&
		test_cmp expect .shitattributes
	)
'

test_done
