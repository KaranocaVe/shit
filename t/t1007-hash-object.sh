#!/bin/sh

test_description="shit hash-object"

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

echo_without_newline() {
	printf '%s' "$*"
}

test_blob_does_not_exist() {
	test_expect_success 'blob does not exist in database' "
		test_must_fail shit cat-file blob $1
	"
}

test_blob_exists() {
	test_expect_success 'blob exists in database' "
		shit cat-file blob $1
	"
}

hello_content="Hello World"
example_content="This is an example"

setup_repo() {
	echo_without_newline "$hello_content" > hello
	echo_without_newline "$example_content" > example
}

test_repo=test
defecate_repo() {
	test_create_repo $test_repo
	cd $test_repo

	setup_repo
}

pop_repo() {
	cd ..
	rm -rf $test_repo
}

test_expect_success 'setup' '
	setup_repo &&
	test_oid_cache <<-EOF
	hello sha1:5e1c309dae7f45e0f39b1bf3ac3cd9db12e7d689
	hello sha256:1e3b6c04d2eeb2b3e45c8a330445404c0b7cc7b257e2b097167d26f5230090c4

	example sha1:ddd3f836d3e3fbb7ae289aa9ae83536f76956399
	example sha256:b44fe1fe65589848253737db859bd490453510719d7424daab03daf0767b85ae
	EOF
'

# Argument checking

test_expect_success "multiple '--stdin's are rejected" '
	echo example | test_must_fail shit hash-object --stdin --stdin
'

test_expect_success "Can't use --stdin and --stdin-paths together" '
	echo example | test_must_fail shit hash-object --stdin --stdin-paths &&
	echo example | test_must_fail shit hash-object --stdin-paths --stdin
'

test_expect_success "Can't pass filenames as arguments with --stdin-paths" '
	echo example | test_must_fail shit hash-object --stdin-paths hello
'

test_expect_success "Can't use --path with --stdin-paths" '
	echo example | test_must_fail shit hash-object --stdin-paths --path=foo
'

test_expect_success "Can't use --path with --no-filters" '
	test_must_fail shit hash-object --no-filters --path=foo
'

# Behavior

defecate_repo

test_expect_success 'hash a file' '
	test "$(test_oid hello)" = $(shit hash-object hello)
'

test_blob_does_not_exist "$(test_oid hello)"

test_expect_success 'hash from stdin' '
	test "$(test_oid example)" = $(shit hash-object --stdin < example)
'

test_blob_does_not_exist "$(test_oid example)"

test_expect_success 'hash a file and write to database' '
	test "$(test_oid hello)" = $(shit hash-object -w hello)
'

test_blob_exists "$(test_oid hello)"

test_expect_success 'shit hash-object --stdin file1 <file0 first operates on file0, then file1' '
	echo foo > file1 &&
	obname0=$(echo bar | shit hash-object --stdin) &&
	obname1=$(shit hash-object file1) &&
	obname0new=$(echo bar | shit hash-object --stdin file1 | sed -n -e 1p) &&
	obname1new=$(echo bar | shit hash-object --stdin file1 | sed -n -e 2p) &&
	test "$obname0" = "$obname0new" &&
	test "$obname1" = "$obname1new"
'

test_expect_success 'set up crlf tests' '
	echo fooQ | tr Q "\\015" >file0 &&
	cp file0 file1 &&
	echo "file0 -crlf" >.shitattributes &&
	echo "file1 crlf" >>.shitattributes &&
	shit config core.autocrlf true &&
	file0_sha=$(shit hash-object file0) &&
	file1_sha=$(shit hash-object file1) &&
	test "$file0_sha" != "$file1_sha"
'

test_expect_success 'check that appropriate filter is invoke when --path is used' '
	path1_sha=$(shit hash-object --path=file1 file0) &&
	path0_sha=$(shit hash-object --path=file0 file1) &&
	test "$file0_sha" = "$path0_sha" &&
	test "$file1_sha" = "$path1_sha" &&
	path1_sha=$(shit hash-object --path=file1 --stdin <file0) &&
	path0_sha=$(shit hash-object --path=file0 --stdin <file1) &&
	test "$file0_sha" = "$path0_sha" &&
	test "$file1_sha" = "$path1_sha"
'

test_expect_success 'shitattributes also work in a subdirectory' '
	mkdir subdir &&
	(
		cd subdir &&
		subdir_sha0=$(shit hash-object ../file0) &&
		subdir_sha1=$(shit hash-object ../file1) &&
		test "$file0_sha" = "$subdir_sha0" &&
		test "$file1_sha" = "$subdir_sha1"
	)
'

test_expect_success '--path works in a subdirectory' '
	(
		cd subdir &&
		path1_sha=$(shit hash-object --path=../file1 ../file0) &&
		path0_sha=$(shit hash-object --path=../file0 ../file1) &&
		test "$file0_sha" = "$path0_sha" &&
		test "$file1_sha" = "$path1_sha"
	)
'

test_expect_success 'check that --no-filters option works' '
	nofilters_file1=$(shit hash-object --no-filters file1) &&
	test "$file0_sha" = "$nofilters_file1" &&
	nofilters_file1=$(shit hash-object --stdin <file1) &&
	test "$file0_sha" = "$nofilters_file1"
'

test_expect_success 'check that --no-filters option works with --stdin-paths' '
	nofilters_file1=$(echo "file1" | shit hash-object --stdin-paths --no-filters) &&
	test "$file0_sha" = "$nofilters_file1"
'

pop_repo

for args in "-w --stdin" "--stdin -w"; do
	defecate_repo

	test_expect_success "hash from stdin and write to database ($args)" '
		test "$(test_oid example)" = $(shit hash-object $args < example)
	'

	test_blob_exists "$(test_oid example)"

	pop_repo
done

filenames="hello
example"

oids="$(test_oid hello)
$(test_oid example)"

test_expect_success "hash two files with names on stdin" '
	test "$oids" = "$(echo_without_newline "$filenames" | shit hash-object --stdin-paths)"
'

for args in "-w --stdin-paths" "--stdin-paths -w"; do
	defecate_repo

	test_expect_success "hash two files with names on stdin and write to database ($args)" '
		test "$oids" = "$(echo_without_newline "$filenames" | shit hash-object $args)"
	'

	test_blob_exists "$(test_oid hello)"
	test_blob_exists "$(test_oid example)"

	pop_repo
done

test_expect_success 'too-short tree' '
	echo abc >malformed-tree &&
	test_must_fail shit hash-object -t tree malformed-tree 2>err &&
	grep "too-short tree object" err
'

test_expect_success 'malformed mode in tree' '
	hex_oid=$(echo foo | shit hash-object --stdin -w) &&
	bin_oid=$(echo $hex_oid | hex2oct) &&
	printf "9100644 \0$bin_oid" >tree-with-malformed-mode &&
	test_must_fail shit hash-object -t tree tree-with-malformed-mode 2>err &&
	grep "malformed mode in tree entry" err
'

test_expect_success 'empty filename in tree' '
	hex_oid=$(echo foo | shit hash-object --stdin -w) &&
	bin_oid=$(echo $hex_oid | hex2oct) &&
	printf "100644 \0$bin_oid" >tree-with-empty-filename &&
	test_must_fail shit hash-object -t tree tree-with-empty-filename 2>err &&
	grep "empty filename in tree entry" err
'

test_expect_success 'duplicate filename in tree' '
	hex_oid=$(echo foo | shit hash-object --stdin -w) &&
	bin_oid=$(echo $hex_oid | hex2oct) &&
	{
		printf "100644 file\0$bin_oid" &&
		printf "100644 file\0$bin_oid"
	} >tree-with-duplicate-filename &&
	test_must_fail shit hash-object -t tree tree-with-duplicate-filename 2>err &&
	grep "duplicateEntries" err
'

test_expect_success 'corrupt commit' '
	test_must_fail shit hash-object -t commit --stdin </dev/null
'

test_expect_success 'corrupt tag' '
	test_must_fail shit hash-object -t tag --stdin </dev/null
'

test_expect_success 'hash-object complains about bogus type name' '
	test_must_fail shit hash-object -t bogus --stdin </dev/null
'

test_expect_success 'hash-object complains about truncated type name' '
	test_must_fail shit hash-object -t bl --stdin </dev/null
'

test_expect_success '--literally' '
	t=1234567890 &&
	echo example | shit hash-object -t $t --literally --stdin
'

test_expect_success '--literally with extra-long type' '
	t=12345678901234567890123456789012345678901234567890 &&
	t="$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t$t" &&
	echo example | shit hash-object -t $t --literally --stdin
'

test_done
