#!/bin/sh

test_description='shit fsck random collection of tests

* (HEAD) B
* (main) A
'

. ./test-lib.sh

test_expect_success setup '
	shit config gc.auto 0 &&
	shit config i18n.commitencoding ISO-8859-1 &&
	test_commit A fileA one &&
	shit config --unset i18n.commitencoding &&
	shit checkout HEAD^0 &&
	test_commit B fileB two &&
	orig_head=$(shit rev-parse HEAD) &&
	shit tag -d A B &&
	shit reflog expire --expire=now --all
'

test_expect_success 'loose objects borrowed from alternate are not missing' '
	mkdir another &&
	(
		cd another &&
		shit init &&
		echo ../../../.shit/objects >.shit/objects/info/alternates &&
		test_commit C fileC one &&
		shit fsck --no-dangling >../actual 2>&1
	) &&
	test_must_be_empty actual
'

test_expect_success 'HEAD is part of refs, valid objects appear valid' '
	shit fsck >actual 2>&1 &&
	test_must_be_empty actual
'

# Corruption tests follow.  Make sure to remove all traces of the
# specific corruption you test afterwards, lest a later test trip over
# it.

sha1_file () {
	shit rev-parse --shit-path objects/$(test_oid_to_path "$1")
}

remove_object () {
	rm "$(sha1_file "$1")"
}

test_expect_success 'object with hash mismatch' '
	shit init --bare hash-mismatch &&
	(
		cd hash-mismatch &&

		oid=$(echo blob | shit hash-object -w --stdin) &&
		oldoid=$oid &&
		old=$(test_oid_to_path "$oid") &&
		new=$(dirname $old)/$(test_oid ff_2) &&
		oid="$(dirname $new)$(basename $new)" &&

		mv objects/$old objects/$new &&
		shit update-index --add --cacheinfo 100644 $oid foo &&
		tree=$(shit write-tree) &&
		cmt=$(echo bogus | shit commit-tree $tree) &&
		shit update-ref refs/heads/bogus $cmt &&

		test_must_fail shit fsck 2>out &&
		grep "$oldoid: hash-path mismatch, found at: .*$new" out
	)
'

test_expect_success 'object with hash and type mismatch' '
	shit init --bare hash-type-mismatch &&
	(
		cd hash-type-mismatch &&

		oid=$(echo blob | shit hash-object -w --stdin -t garbage --literally) &&
		oldoid=$oid &&
		old=$(test_oid_to_path "$oid") &&
		new=$(dirname $old)/$(test_oid ff_2) &&
		oid="$(dirname $new)$(basename $new)" &&

		mv objects/$old objects/$new &&
		shit update-index --add --cacheinfo 100644 $oid foo &&
		tree=$(shit write-tree) &&
		cmt=$(echo bogus | shit commit-tree $tree) &&
		shit update-ref refs/heads/bogus $cmt &&


		test_must_fail shit fsck 2>out &&
		grep "^error: $oldoid: hash-path mismatch, found at: .*$new" out &&
		grep "^error: $oldoid: object is of unknown type '"'"'garbage'"'"'" out
	)
'

test_expect_success 'zlib corrupt loose object output ' '
	shit init --bare corrupt-loose-output &&
	(
		cd corrupt-loose-output &&
		oid=$(shit hash-object -w --stdin --literally </dev/null) &&
		oidf=objects/$(test_oid_to_path "$oid") &&
		chmod +w $oidf &&
		echo extra garbage >>$oidf &&

		cat >expect.error <<-EOF &&
		error: garbage at end of loose object '\''$oid'\''
		error: unable to unpack contents of ./$oidf
		error: $oid: object corrupt or missing: ./$oidf
		EOF
		test_must_fail shit fsck 2>actual &&
		grep ^error: actual >error &&
		test_cmp expect.error error
	)
'

test_expect_success 'branch pointing to non-commit' '
	tree_oid=$(shit rev-parse --verify HEAD^{tree}) &&
	test_when_finished "shit update-ref -d refs/heads/invalid" &&
	test-tool ref-store main update-ref msg refs/heads/invalid $tree_oid $ZERO_OID REF_SKIP_OID_VERIFICATION &&
	test_must_fail shit fsck 2>out &&
	test_grep "not a commit" out
'

test_expect_success REFFILES 'HEAD link pointing at a funny object' '
	test_when_finished "shit update-ref HEAD $orig_head" &&
	echo $ZERO_OID >.shit/HEAD &&
	# avoid corrupt/broken HEAD from interfering with repo discovery
	test_must_fail env shit_DIR=.shit shit fsck 2>out &&
	test_grep "detached HEAD points" out
'

test_expect_success 'HEAD link pointing at a funny place' '
	test_when_finished "shit update-ref --no-deref HEAD $orig_head" &&
	test-tool ref-store main create-symref HEAD refs/funny/place &&
	# avoid corrupt/broken HEAD from interfering with repo discovery
	test_must_fail env shit_DIR=.shit shit fsck 2>out &&
	test_grep "HEAD points to something strange" out
'

test_expect_success REFFILES 'HEAD link pointing at a funny object (from different wt)' '
	test_when_finished "shit update-ref HEAD $orig_head" &&
	test_when_finished "shit worktree remove -f wt" &&
	shit worktree add wt &&
	echo $ZERO_OID >.shit/HEAD &&
	# avoid corrupt/broken HEAD from interfering with repo discovery
	test_must_fail shit -C wt fsck 2>out &&
	test_grep "main-worktree/HEAD: detached HEAD points" out
'

test_expect_success REFFILES 'other worktree HEAD link pointing at a funny object' '
	test_when_finished "shit worktree remove -f other" &&
	shit worktree add other &&
	echo $ZERO_OID >.shit/worktrees/other/HEAD &&
	test_must_fail shit fsck 2>out &&
	test_grep "worktrees/other/HEAD: detached HEAD points" out
'

test_expect_success 'other worktree HEAD link pointing at missing object' '
	test_when_finished "shit worktree remove -f other" &&
	shit worktree add other &&
	object_id=$(echo "Contents missing from repo" | shit hash-object --stdin) &&
	test-tool -C other ref-store main update-ref msg HEAD $object_id "" REF_NO_DEREF,REF_SKIP_OID_VERIFICATION &&
	test_must_fail shit fsck 2>out &&
	test_grep "worktrees/other/HEAD: invalid sha1 pointer" out
'

test_expect_success 'other worktree HEAD link pointing at a funny place' '
	test_when_finished "shit worktree remove -f other" &&
	shit worktree add other &&
	shit -C other symbolic-ref HEAD refs/funny/place &&
	test_must_fail shit fsck 2>out &&
	test_grep "worktrees/other/HEAD points to something strange" out
'

test_expect_success 'commit with multiple signatures is okay' '
	shit cat-file commit HEAD >basis &&
	cat >sigs <<-EOF &&
	gpgsig -----BEGIN PGP SIGNATURE-----
	  VGhpcyBpcyBub3QgcmVhbGx5IGEgc2lnbmF0dXJlLg==
	  -----END PGP SIGNATURE-----
	gpgsig-sha256 -----BEGIN PGP SIGNATURE-----
	  VGhpcyBpcyBub3QgcmVhbGx5IGEgc2lnbmF0dXJlLg==
	  -----END PGP SIGNATURE-----
	EOF
	sed -e "/^committer/q" basis >okay &&
	cat sigs >>okay &&
	echo >>okay &&
	sed -e "1,/^$/d" basis >>okay &&
	cat okay &&
	new=$(shit hash-object -t commit -w --stdin <okay) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	shit fsck 2>out &&
	cat out &&
	! grep "commit $new" out
'

test_expect_success 'email without @ is okay' '
	shit cat-file commit HEAD >basis &&
	sed "s/@/AT/" basis >okay &&
	new=$(shit hash-object -t commit -w --stdin <okay) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	shit fsck 2>out &&
	! grep "commit $new" out
'

test_expect_success 'email with embedded > is not okay' '
	shit cat-file commit HEAD >basis &&
	sed "s/@[a-z]/&>/" basis >bad-email &&
	new=$(shit hash-object --literally -t commit -w --stdin <bad-email) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $new" out
'

test_expect_success 'missing < email delimiter is reported nicely' '
	shit cat-file commit HEAD >basis &&
	sed "s/<//" basis >bad-email-2 &&
	new=$(shit hash-object --literally -t commit -w --stdin <bad-email-2) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $new.* - bad name" out
'

test_expect_success 'missing email is reported nicely' '
	shit cat-file commit HEAD >basis &&
	sed "s/[a-z]* <[^>]*>//" basis >bad-email-3 &&
	new=$(shit hash-object --literally -t commit -w --stdin <bad-email-3) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $new.* - missing email" out
'

test_expect_success '> in name is reported' '
	shit cat-file commit HEAD >basis &&
	sed "s/ </> </" basis >bad-email-4 &&
	new=$(shit hash-object --literally -t commit -w --stdin <bad-email-4) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $new" out
'

# date is 2^64 + 1
test_expect_success 'integer overflow in timestamps is reported' '
	shit cat-file commit HEAD >basis &&
	sed "s/^\\(author .*>\\) [0-9]*/\\1 18446744073709551617/" \
		<basis >bad-timestamp &&
	new=$(shit hash-object --literally -t commit -w --stdin <bad-timestamp) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $new.*integer overflow" out
'

test_expect_success 'commit with NUL in header' '
	shit cat-file commit HEAD >basis &&
	sed "s/author ./author Q/" <basis | q_to_nul >commit-NUL-header &&
	new=$(shit hash-object --literally -t commit -w --stdin <commit-NUL-header) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $new.*unterminated header: NUL at offset" out
'

test_expect_success 'tree object with duplicate entries' '
	test_when_finished "for i in \$T; do remove_object \$i; done" &&
	T=$(
		shit_INDEX_FILE=test-index &&
		export shit_INDEX_FILE &&
		rm -f test-index &&
		>x &&
		shit add x &&
		shit rev-parse :x &&
		T=$(shit write-tree) &&
		echo $T &&
		(
			shit cat-file tree $T &&
			shit cat-file tree $T
		) |
		shit hash-object --literally -w -t tree --stdin
	) &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in tree .*contains duplicate file entries" out
'

check_duplicate_names () {
	expect=$1 &&
	shift &&
	names=$@ &&
	test_expect_$expect "tree object with duplicate names: $names" '
		test_when_finished "remove_object \$blob" &&
		test_when_finished "remove_object \$tree" &&
		test_when_finished "remove_object \$badtree" &&
		blob=$(echo blob | shit hash-object -w --stdin) &&
		printf "100644 blob %s\t%s\n" $blob x.2 >tree &&
		tree=$(shit mktree <tree) &&
		for name in $names
		do
			case "$name" in
			*/) printf "040000 tree %s\t%s\n" $tree "${name%/}" ;;
			*)  printf "100644 blob %s\t%s\n" $blob "$name" ;;
			esac
		done >badtree &&
		badtree=$(shit mktree <badtree) &&
		test_must_fail shit fsck 2>out &&
		test_grep "$badtree" out &&
		test_grep "error in tree .*contains duplicate file entries" out
	'
}

check_duplicate_names success x x.1 x/
check_duplicate_names success x x.1.2 x.1/ x/
check_duplicate_names success x x.1 x.1.2 x/

test_expect_success 'unparseable tree object' '
	test_oid_cache <<-\EOF &&
	junk sha1:twenty-bytes-of-junk
	junk sha256:twenty-bytes-of-junk-twelve-more
	EOF

	test_when_finished "shit update-ref -d refs/heads/wrong" &&
	test_when_finished "remove_object \$tree_sha1" &&
	test_when_finished "remove_object \$commit_sha1" &&
	junk=$(test_oid junk) &&
	tree_sha1=$(printf "100644 \0$junk" | shit hash-object -t tree --stdin -w --literally) &&
	commit_sha1=$(shit commit-tree $tree_sha1) &&
	shit update-ref refs/heads/wrong $commit_sha1 &&
	test_must_fail shit fsck 2>out &&
	test_grep "error: empty filename in tree entry" out &&
	test_grep "$tree_sha1" out &&
	test_grep ! "fatal: empty filename in tree entry" out
'

test_expect_success 'tree entry with type mismatch' '
	test_when_finished "remove_object \$blob" &&
	test_when_finished "remove_object \$tree" &&
	test_when_finished "remove_object \$commit" &&
	test_when_finished "shit update-ref -d refs/heads/type_mismatch" &&
	blob=$(echo blob | shit hash-object -w --stdin) &&
	blob_bin=$(echo $blob | hex2oct) &&
	tree=$(
		printf "40000 dir\0${blob_bin}100644 file\0${blob_bin}" |
		shit hash-object -t tree --stdin -w --literally
	) &&
	commit=$(shit commit-tree $tree) &&
	shit update-ref refs/heads/type_mismatch $commit &&
	test_must_fail shit fsck >out 2>&1 &&
	test_grep "is a blob, not a tree" out &&
	test_grep ! "dangling blob" out
'

test_expect_success 'tree entry with bogus mode' '
	test_when_finished "remove_object \$blob" &&
	test_when_finished "remove_object \$tree" &&
	blob=$(echo blob | shit hash-object -w --stdin) &&
	blob_oct=$(echo $blob | hex2oct) &&
	tree=$(printf "100000 foo\0${blob_oct}" |
	       shit hash-object -t tree --stdin -w --literally) &&
	shit fsck 2>err &&
	cat >expect <<-EOF &&
	warning in tree $tree: badFilemode: contains bad file modes
	EOF
	test_cmp expect err
'

test_expect_success 'tag pointing to nonexistent' '
	badoid=$(test_oid deadbeef) &&
	cat >invalid-tag <<-EOF &&
	object $badoid
	type commit
	tag invalid
	tagger T A Gger <tagger@example.com> 1234567890 -0000

	This is an invalid tag.
	EOF

	tag=$(shit hash-object -t tag -w --stdin <invalid-tag) &&
	test_when_finished "remove_object $tag" &&
	shit update-ref refs/tags/invalid $tag &&
	test_when_finished "shit update-ref -d refs/tags/invalid" &&
	test_must_fail shit fsck --tags >out &&
	test_grep "broken link" out
'

test_expect_success 'tag pointing to something else than its type' '
	sha=$(echo blob | shit hash-object -w --stdin) &&
	test_when_finished "remove_object $sha" &&
	cat >wrong-tag <<-EOF &&
	object $sha
	type commit
	tag wrong
	tagger T A Gger <tagger@example.com> 1234567890 -0000

	This is an invalid tag.
	EOF

	tag=$(shit hash-object -t tag -w --stdin <wrong-tag) &&
	test_when_finished "remove_object $tag" &&
	shit update-ref refs/tags/wrong $tag &&
	test_when_finished "shit update-ref -d refs/tags/wrong" &&
	test_must_fail shit fsck --tags
'

test_expect_success 'tag with incorrect tag name & missing tagger' '
	sha=$(shit rev-parse HEAD) &&
	cat >wrong-tag <<-EOF &&
	object $sha
	type commit
	tag wrong name format

	This is an invalid tag.
	EOF

	tag=$(shit hash-object --literally -t tag -w --stdin <wrong-tag) &&
	test_when_finished "remove_object $tag" &&
	shit update-ref refs/tags/wrong $tag &&
	test_when_finished "shit update-ref -d refs/tags/wrong" &&
	shit fsck --tags 2>out &&

	cat >expect <<-EOF &&
	warning in tag $tag: badTagName: invalid '\''tag'\'' name: wrong name format
	warning in tag $tag: missingTaggerEntry: invalid format - expected '\''tagger'\'' line
	EOF
	test_cmp expect out
'

test_expect_success 'tag with bad tagger' '
	sha=$(shit rev-parse HEAD) &&
	cat >wrong-tag <<-EOF &&
	object $sha
	type commit
	tag not-quite-wrong
	tagger Bad Tagger Name

	This is an invalid tag.
	EOF

	tag=$(shit hash-object --literally -t tag -w --stdin <wrong-tag) &&
	test_when_finished "remove_object $tag" &&
	shit update-ref refs/tags/wrong $tag &&
	test_when_finished "shit update-ref -d refs/tags/wrong" &&
	test_must_fail shit fsck --tags 2>out &&
	test_grep "error in tag .*: invalid author/committer" out
'

test_expect_success 'tag with NUL in header' '
	sha=$(shit rev-parse HEAD) &&
	q_to_nul >tag-NUL-header <<-EOF &&
	object $sha
	type commit
	tag contains-Q-in-header
	tagger T A Gger <tagger@example.com> 1234567890 -0000

	This is an invalid tag.
	EOF

	tag=$(shit hash-object --literally -t tag -w --stdin <tag-NUL-header) &&
	test_when_finished "remove_object $tag" &&
	shit update-ref refs/tags/wrong $tag &&
	test_when_finished "shit update-ref -d refs/tags/wrong" &&
	test_must_fail shit fsck --tags 2>out &&
	test_grep "error in tag $tag.*unterminated header: NUL at offset" out
'

test_expect_success 'cleaned up' '
	shit fsck >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_success 'rev-list --verify-objects' '
	shit rev-list --verify-objects --all >/dev/null 2>out &&
	test_must_be_empty out
'

test_expect_success 'rev-list --verify-objects with bad sha1' '
	sha=$(echo blob | shit hash-object -w --stdin) &&
	old=$(test_oid_to_path $sha) &&
	new=$(dirname $old)/$(test_oid ff_2) &&
	sha="$(dirname $new)$(basename $new)" &&
	mv .shit/objects/$old .shit/objects/$new &&
	test_when_finished "remove_object $sha" &&
	shit update-index --add --cacheinfo 100644 $sha foo &&
	test_when_finished "shit read-tree -u --reset HEAD" &&
	tree=$(shit write-tree) &&
	test_when_finished "remove_object $tree" &&
	cmt=$(echo bogus | shit commit-tree $tree) &&
	test_when_finished "remove_object $cmt" &&
	shit update-ref refs/heads/bogus $cmt &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&

	test_might_fail shit rev-list --verify-objects refs/heads/bogus >/dev/null 2>out &&
	test_grep -q "error: hash mismatch $(dirname $new)$(test_oid ff_2)" out
'

# An actual bit corruption is more likely than swapped commits, but
# this provides an easy way to have commits which don't match their purported
# hashes, but which aren't so broken we can't read them at all.
test_expect_success 'rev-list --verify-objects notices swapped commits' '
	shit init swapped-commits &&
	(
		cd swapped-commits &&
		test_commit one &&
		test_commit two &&
		one_oid=$(shit rev-parse HEAD) &&
		two_oid=$(shit rev-parse HEAD^) &&
		one=.shit/objects/$(test_oid_to_path $one_oid) &&
		two=.shit/objects/$(test_oid_to_path $two_oid) &&
		mv $one tmp &&
		mv $two $one &&
		mv tmp $two &&
		test_must_fail shit rev-list --verify-objects HEAD
	)
'

test_expect_success 'set up repository with commit-graph' '
	shit init corrupt-graph &&
	(
		cd corrupt-graph &&
		test_commit one &&
		test_commit two &&
		shit commit-graph write --reachable
	)
'

corrupt_graph_obj () {
	oid=$(shit -C corrupt-graph rev-parse "$1") &&
	obj=corrupt-graph/.shit/objects/$(test_oid_to_path $oid) &&
	test_when_finished 'mv backup $obj' &&
	mv $obj backup &&
	echo garbage >$obj
}

test_expect_success 'rev-list --verify-objects with commit graph (tip)' '
	corrupt_graph_obj HEAD &&
	test_must_fail shit -C corrupt-graph rev-list --verify-objects HEAD
'

test_expect_success 'rev-list --verify-objects with commit graph (parent)' '
	corrupt_graph_obj HEAD^ &&
	test_must_fail shit -C corrupt-graph rev-list --verify-objects HEAD
'

test_expect_success 'force fsck to ignore double author' '
	shit cat-file commit HEAD >basis &&
	sed "s/^author .*/&,&/" <basis | tr , \\n >multiple-authors &&
	new=$(shit hash-object --literally -t commit -w --stdin <multiple-authors) &&
	test_when_finished "remove_object $new" &&
	shit update-ref refs/heads/bogus "$new" &&
	test_when_finished "shit update-ref -d refs/heads/bogus" &&
	test_must_fail shit fsck &&
	shit -c fsck.multipleAuthors=ignore fsck
'

_bz='\0'
_bzoid=$(printf $ZERO_OID | sed -e 's/00/\\0/g')

test_expect_success 'fsck notices blob entry pointing to null sha1' '
	(shit init null-blob &&
	 cd null-blob &&
	 sha=$(printf "100644 file$_bz$_bzoid" |
	       shit hash-object --literally -w --stdin -t tree) &&
	  shit fsck 2>out &&
	  test_grep "warning.*null sha1" out
	)
'

test_expect_success 'fsck notices submodule entry pointing to null sha1' '
	(shit init null-commit &&
	 cd null-commit &&
	 sha=$(printf "160000 submodule$_bz$_bzoid" |
	       shit hash-object --literally -w --stdin -t tree) &&
	  shit fsck 2>out &&
	  test_grep "warning.*null sha1" out
	)
'

test_expect_success 'fsck notices excessively large tree entry name' '
	shit init large-name &&
	(
		cd large-name &&
		test_commit a-long-name &&
		shit -c fsck.largePathname=warn:10 fsck 2>out &&
		grep "warning.*large pathname" out
	)
'

while read name path pretty; do
	while read mode type; do
		: ${pretty:=$path}
		test_expect_success "fsck notices $pretty as $type" '
		(
			shit init $name-$type &&
			cd $name-$type &&
			shit config core.protectNTFS false &&
			echo content >file &&
			shit add file &&
			shit commit -m base &&
			blob=$(shit rev-parse :file) &&
			tree=$(shit rev-parse HEAD^{tree}) &&
			value=$(eval "echo \$$type") &&
			printf "$mode $type %s\t%s" "$value" "$path" >bad &&
			bad_tree=$(shit mktree <bad) &&
			shit fsck 2>out &&
			test_grep "warning.*tree $bad_tree" out
		)'
	done <<-\EOF
	100644 blob
	040000 tree
	EOF
done <<-EOF
dot .
dotdot ..
dotshit .shit
dotshit-case .shit
dotshit-unicode .gI${u200c}T .gI{u200c}T
dotshit-case2 .shit
shit-tilde1 shit~1
dotshitdot .shit.
dot-backslash-case .\\\\.shit\\\\foobar
dotshit-case-backslash .shit\\\\foobar
EOF

test_expect_success 'fsck allows .Ňit' '
	(
		shit init not-dotshit &&
		cd not-dotshit &&
		echo content >file &&
		shit add file &&
		shit commit -m base &&
		blob=$(shit rev-parse :file) &&
		printf "100644 blob $blob\t.\\305\\207it" >tree &&
		tree=$(shit mktree <tree) &&
		shit fsck 2>err &&
		test_line_count = 0 err
	)
'

test_expect_success 'NUL in commit' '
	rm -fr nul-in-commit &&
	shit init nul-in-commit &&
	(
		cd nul-in-commit &&
		shit commit --allow-empty -m "initial commitQNUL after message" &&
		shit cat-file commit HEAD >original &&
		q_to_nul <original >munged &&
		shit hash-object --literally -w -t commit --stdin <munged >name &&
		shit branch bad $(cat name) &&

		test_must_fail shit -c fsck.nulInCommit=error fsck 2>warn.1 &&
		test_grep nulInCommit warn.1 &&
		shit fsck 2>warn.2 &&
		test_grep nulInCommit warn.2
	)
'

# create a static test repo which is broken by omitting
# one particular object ($1, which is looked up via rev-parse
# in the new repository).
create_repo_missing () {
	rm -rf missing &&
	shit init missing &&
	(
		cd missing &&
		shit commit -m one --allow-empty &&
		mkdir subdir &&
		echo content >subdir/file &&
		shit add subdir/file &&
		shit commit -m two &&
		unrelated=$(echo unrelated | shit hash-object --stdin -w) &&
		shit tag -m foo tag $unrelated &&
		sha1=$(shit rev-parse --verify "$1") &&
		path=$(echo $sha1 | sed 's|..|&/|') &&
		rm .shit/objects/$path
	)
}

test_expect_success 'fsck notices missing blob' '
	create_repo_missing HEAD:subdir/file &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck notices missing subtree' '
	create_repo_missing HEAD:subdir &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck notices missing root tree' '
	create_repo_missing HEAD^{tree} &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck notices missing parent' '
	create_repo_missing HEAD^ &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck notices missing tagged object' '
	create_repo_missing tag^{blob} &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck notices ref pointing to missing commit' '
	create_repo_missing HEAD &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck notices ref pointing to missing tag' '
	create_repo_missing tag &&
	test_must_fail shit -C missing fsck
'

test_expect_success 'fsck --connectivity-only' '
	rm -rf connectivity-only &&
	shit init connectivity-only &&
	(
		cd connectivity-only &&
		touch empty &&
		shit add empty &&
		test_commit empty &&

		# Drop the index now; we want to be sure that we
		# recursively notice the broken objects
		# because they are reachable from refs, not because
		# they are in the index.
		rm -f .shit/index &&

		# corrupt the blob, but in a way that we can still identify
		# its type. That lets us see that --connectivity-only is
		# not actually looking at the contents, but leaves it
		# free to examine the type if it chooses.
		empty=.shit/objects/$(test_oid_to_path $EMPTY_BLOB) &&
		blob=$(echo unrelated | shit hash-object -w --stdin) &&
		mv -f $(sha1_file $blob) $empty &&

		test_must_fail shit fsck --strict &&
		shit fsck --strict --connectivity-only &&
		tree=$(shit rev-parse HEAD:) &&
		suffix=${tree#??} &&
		tree=.shit/objects/${tree%$suffix}/$suffix &&
		rm -f $tree &&
		echo invalid >$tree &&
		test_must_fail shit fsck --strict --connectivity-only
	)
'

test_expect_success 'fsck --connectivity-only with explicit head' '
	rm -rf connectivity-only &&
	shit init connectivity-only &&
	(
		cd connectivity-only &&
		test_commit foo &&
		rm -f .shit/index &&
		tree=$(shit rev-parse HEAD^{tree}) &&
		remove_object $(shit rev-parse HEAD:foo.t) &&
		test_must_fail shit fsck --connectivity-only $tree
	)
'

test_expect_success 'fsck --name-objects' '
	rm -rf name-objects &&
	shit init name-objects &&
	(
		cd name-objects &&
		shit config core.logAllRefUpdates false &&
		test_commit julius caesar.t &&
		test_commit augustus44 &&
		test_commit caesar  &&
		remove_object $(shit rev-parse julius:caesar.t) &&
		tree=$(shit rev-parse --verify julius:) &&
		shit tag -d julius &&
		test_must_fail shit fsck --name-objects >out &&
		test_grep "$tree (refs/tags/augustus44\\^:" out
	)
'

test_expect_success 'alternate objects are correctly blamed' '
	test_when_finished "rm -rf alt.shit .shit/objects/info/alternates" &&
	name=$(test_oid numeric) &&
	path=$(test_oid_to_path "$name") &&
	shit init --bare alt.shit &&
	echo "../../alt.shit/objects" >.shit/objects/info/alternates &&
	mkdir alt.shit/objects/$(dirname $path) &&
	>alt.shit/objects/$(dirname $path)/$(basename $path) &&
	test_must_fail shit fsck >out 2>&1 &&
	test_grep alt.shit out
'

test_expect_success 'fsck errors in packed objects' '
	shit cat-file commit HEAD >basis &&
	sed "s/</one/" basis >one &&
	sed "s/</foo/" basis >two &&
	one=$(shit hash-object --literally -t commit -w one) &&
	two=$(shit hash-object --literally -t commit -w two) &&
	pack=$(
		{
			echo $one &&
			echo $two
		} | shit pack-objects .shit/objects/pack/pack
	) &&
	test_when_finished "rm -f .shit/objects/pack/pack-$pack.*" &&
	remove_object $one &&
	remove_object $two &&
	test_must_fail shit fsck 2>out &&
	test_grep "error in commit $one.* - bad name" out &&
	test_grep "error in commit $two.* - bad name" out &&
	! grep corrupt out
'

test_expect_success 'fsck fails on corrupt packfile' '
	hsh=$(shit commit-tree -m mycommit HEAD^{tree}) &&
	pack=$(echo $hsh | shit pack-objects .shit/objects/pack/pack) &&

	# Corrupt the first byte of the first object. (It contains 3 type bits,
	# at least one of which is not zero, so setting the first byte to 0 is
	# sufficient.)
	chmod a+w .shit/objects/pack/pack-$pack.pack &&
	printf "\0" | dd of=.shit/objects/pack/pack-$pack.pack bs=1 conv=notrunc seek=12 &&

	test_when_finished "rm -f .shit/objects/pack/pack-$pack.*" &&
	remove_object $hsh &&
	test_must_fail shit fsck 2>out &&
	test_grep "checksum mismatch" out
'

test_expect_success 'fsck finds problems in duplicate loose objects' '
	rm -rf broken-duplicate &&
	shit init broken-duplicate &&
	(
		cd broken-duplicate &&
		test_commit duplicate &&
		# no "-d" here, so we end up with duplicates
		shit repack &&
		# now corrupt the loose copy
		oid="$(shit rev-parse HEAD)" &&
		file=$(sha1_file "$oid") &&
		rm "$file" &&
		echo broken >"$file" &&
		test_must_fail shit fsck 2>err &&

		cat >expect <<-EOF &&
		error: inflate: data stream error (incorrect header check)
		error: unable to unpack header of $file
		error: $oid: object corrupt or missing: $file
		EOF
		grep "^error: " err >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'fsck detects trailing loose garbage (commit)' '
	shit cat-file commit HEAD >basis &&
	echo bump-commit-sha1 >>basis &&
	commit=$(shit hash-object -w -t commit basis) &&
	file=$(sha1_file $commit) &&
	test_when_finished "remove_object $commit" &&
	chmod +w "$file" &&
	echo garbage >>"$file" &&
	test_must_fail shit fsck 2>out &&
	test_grep "garbage.*$commit" out
'

test_expect_success 'fsck detects trailing loose garbage (large blob)' '
	blob=$(echo trailing | shit hash-object -w --stdin) &&
	file=$(sha1_file $blob) &&
	test_when_finished "remove_object $blob" &&
	chmod +w "$file" &&
	echo garbage >>"$file" &&
	test_must_fail shit -c core.bigfilethreshold=5 fsck 2>out &&
	test_grep "garbage.*$blob" out
'

test_expect_success 'fsck detects truncated loose object' '
	# make it big enough that we know we will truncate in the data
	# portion, not the header
	test-tool genrandom truncate 4096 >file &&
	blob=$(shit hash-object -w file) &&
	file=$(sha1_file $blob) &&
	test_when_finished "remove_object $blob" &&
	test_copy_bytes 1024 <"$file" >tmp &&
	rm "$file" &&
	mv -f tmp "$file" &&

	# check both regular and streaming code paths
	test_must_fail shit fsck 2>out &&
	test_grep corrupt.*$blob out &&

	test_must_fail shit -c core.bigfilethreshold=128 fsck 2>out &&
	test_grep corrupt.*$blob out
'

# for each of type, we have one version which is referenced by another object
# (and so while unreachable, not dangling), and another variant which really is
# dangling.
test_expect_success 'create dangling-object repository' '
	shit init dangling &&
	(
		cd dangling &&
		blob=$(echo not-dangling | shit hash-object -w --stdin) &&
		dblob=$(echo dangling | shit hash-object -w --stdin) &&
		tree=$(printf "100644 blob %s\t%s\n" $blob one | shit mktree) &&
		dtree=$(printf "100644 blob %s\t%s\n" $blob two | shit mktree) &&
		commit=$(shit commit-tree $tree) &&
		dcommit=$(shit commit-tree -p $commit $tree) &&

		cat >expect <<-EOF
		dangling blob $dblob
		dangling commit $dcommit
		dangling tree $dtree
		EOF
	)
'

test_expect_success 'fsck notices dangling objects' '
	(
		cd dangling &&
		shit fsck >actual &&
		# the output order is non-deterministic, as it comes from a hash
		sort <actual >actual.sorted &&
		test_cmp expect actual.sorted
	)
'

test_expect_success 'fsck --connectivity-only notices dangling objects' '
	(
		cd dangling &&
		shit fsck --connectivity-only >actual &&
		# the output order is non-deterministic, as it comes from a hash
		sort <actual >actual.sorted &&
		test_cmp expect actual.sorted
	)
'

test_expect_success 'fsck $name notices bogus $name' '
	test_must_fail shit fsck bogus &&
	test_must_fail shit fsck $ZERO_OID
'

test_expect_success 'bogus head does not fallback to all heads' '
	# set up a case that will cause a reachability complaint
	echo to-be-deleted >foo &&
	shit add foo &&
	blob=$(shit rev-parse :foo) &&
	test_when_finished "shit rm --cached foo" &&
	remove_object $blob &&
	test_must_fail shit fsck $ZERO_OID >out 2>&1 &&
	! grep $blob out
'

# Corrupt the checksum on the index.
# Add 1 to the last byte in the SHA.
corrupt_index_checksum () {
    perl -w -e '
	use Fcntl ":seek";
	open my $fh, "+<", ".shit/index" or die "open: $!";
	binmode $fh;
	seek $fh, -1, SEEK_END or die "seek: $!";
	read $fh, my $in_byte, 1 or die "read: $!";

	$in_value = unpack("C", $in_byte);
	$out_value = ($in_value + 1) & 255;

	$out_byte = pack("C", $out_value);

	seek $fh, -1, SEEK_END or die "seek: $!";
	print $fh $out_byte;
	close $fh or die "close: $!";
    '
}

# Corrupt the checksum on the index and then
# verify that only fsck notices.
test_expect_success 'detect corrupt index file in fsck' '
	cp .shit/index .shit/index.backup &&
	test_when_finished "mv .shit/index.backup .shit/index" &&
	corrupt_index_checksum &&
	test_must_fail shit fsck --cache 2>errors &&
	test_grep "bad index file" errors
'

test_expect_success 'fsck error and recovery on invalid object type' '
	shit init --bare garbage-type &&
	(
		cd garbage-type &&

		garbage_blob=$(shit hash-object --stdin -w -t garbage --literally </dev/null) &&

		test_must_fail shit fsck 2>err &&
		grep -e "^error" -e "^fatal" err >errors &&
		test_line_count = 1 errors &&
		grep "$garbage_blob: object is of unknown type '"'"'garbage'"'"':" err
	)
'

test_expect_success 'fsck error on shitattributes with excessive line lengths' '
	blob=$(printf "pattern %02048d" 1 | shit hash-object -w --stdin) &&
	test_when_finished "remove_object $blob" &&
	tree=$(printf "100644 blob %s\t%s\n" $blob .shitattributes | shit mktree) &&
	test_when_finished "remove_object $tree" &&
	cat >expected <<-EOF &&
	error in blob $blob: shitattributesLineLength: .shitattributes has too long lines to parse
	EOF
	test_must_fail shit fsck --no-dangling >actual 2>&1 &&
	test_cmp expected actual
'

test_expect_success 'fsck error on shitattributes with excessive size' '
	blob=$(test-tool genzeros $((100 * 1024 * 1024 + 1)) | shit hash-object -w --stdin) &&
	test_when_finished "remove_object $blob" &&
	tree=$(printf "100644 blob %s\t%s\n" $blob .shitattributes | shit mktree) &&
	test_when_finished "remove_object $tree" &&
	cat >expected <<-EOF &&
	error in blob $blob: shitattributesLarge: .shitattributes too large to parse
	EOF
	test_must_fail shit fsck --no-dangling >actual 2>&1 &&
	test_cmp expected actual
'

test_expect_success 'fsck detects problems in worktree index' '
	test_when_finished "shit worktree remove -f wt" &&
	shit worktree add wt &&

	echo "this will be removed to break the worktree index" >wt/file &&
	shit -C wt add file &&
	blob=$(shit -C wt rev-parse :file) &&
	remove_object $blob &&

	test_must_fail shit fsck --name-objects >actual 2>&1 &&
	cat >expect <<-EOF &&
	missing blob $blob (.shit/worktrees/wt/index:file)
	EOF
	test_cmp expect actual
'

test_expect_success 'fsck reports problems in current worktree index without filename' '
	test_when_finished "rm -f .shit/index && shit read-tree HEAD" &&
	echo "this object will be removed to break current worktree index" >file &&
	shit add file &&
	blob=$(shit rev-parse :file) &&
	remove_object $blob &&

	test_must_fail shit fsck --name-objects >actual 2>&1 &&
	cat >expect <<-EOF &&
	missing blob $blob (:file)
	EOF
	test_cmp expect actual
'

test_expect_success 'fsck warning on symlink target with excessive length' '
	symlink_target=$(printf "pattern %032769d" 1 | shit hash-object -w --stdin) &&
	test_when_finished "remove_object $symlink_target" &&
	tree=$(printf "120000 blob %s\t%s\n" $symlink_target symlink | shit mktree) &&
	test_when_finished "remove_object $tree" &&
	cat >expected <<-EOF &&
	warning in blob $symlink_target: symlinkTargetLength: symlink target too long
	EOF
	shit fsck --no-dangling >actual 2>&1 &&
	test_cmp expected actual
'

test_expect_success 'fsck warning on symlink target pointing inside shit dir' '
	shitdir=$(printf ".shit" | shit hash-object -w --stdin) &&
	ntfs_shitdir=$(printf "shit~1" | shit hash-object -w --stdin) &&
	hfs_shitdir=$(printf ".${u200c}shit" | shit hash-object -w --stdin) &&
	inside_shitdir=$(printf "nested/.shit/config" | shit hash-object -w --stdin) &&
	benign_target=$(printf "leshit/config" | shit hash-object -w --stdin) &&
	tree=$(printf "120000 blob %s\t%s\n" \
		$benign_target benign_target \
		$shitdir shitdir \
		$hfs_shitdir hfs_shitdir \
		$inside_shitdir inside_shitdir \
		$ntfs_shitdir ntfs_shitdir |
		shit mktree) &&
	for o in $shitdir $ntfs_shitdir $hfs_shitdir $inside_shitdir $benign_target $tree
	do
		test_when_finished "remove_object $o" || return 1
	done &&
	printf "warning in blob %s: symlinkPointsToshitDir: symlink target points to shit dir\n" \
		$shitdir $hfs_shitdir $inside_shitdir $ntfs_shitdir |
	sort >expected &&
	shit fsck --no-dangling >actual 2>&1 &&
	sort actual >actual.sorted &&
	test_cmp expected actual.sorted
'

test_done
