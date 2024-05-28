#!/bin/sh

test_description='check broken or malicious patterns in .shit* files

Such as:

  - presence of .. in submodule names;
    Exercise the name-checking function on a variety of names, and then give a
    real-world setup that confirms we catch this in practice.

  - nested submodule names

  - symlinked .shitmodules, etc
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-pack.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'check names' '
	cat >expect <<-\EOF &&
	valid
	valid/with/paths
	EOF

	test-tool submodule check-name >actual <<-\EOF &&
	valid
	valid/with/paths

	../foo
	/../foo
	..\foo
	\..\foo
	foo/..
	foo/../
	foo\..
	foo\..\
	foo/../bar
	EOF

	test_cmp expect actual
'

test_expect_success 'check urls' '
	cat >expect <<-\EOF &&
	./bar/baz/foo.shit
	https://example.com/foo.shit
	http://example.com:80/deeper/foo.shit
	EOF

	test-tool submodule check-url >actual <<-\EOF &&
	./bar/baz/foo.shit
	https://example.com/foo.shit
	http://example.com:80/deeper/foo.shit
	-a./foo
	../../..//test/foo.shit
	../../../../../:localhost:8080/foo.shit
	..\../.\../:example.com/foo.shit
	./%0ahost=example.com/foo.shit
	https://one.example.com/evil?%0ahost=two.example.com
	https:///example.com/foo.shit
	http://example.com:test/foo.shit
	https::example.com/foo.shit
	http:::example.com/foo.shit
	EOF

	test_cmp expect actual
'

test_expect_success 'create innocent subrepo' '
	shit init innocent &&
	shit -C innocent commit --allow-empty -m foo
'

test_expect_success 'submodule add refuses invalid names' '
	test_must_fail \
		shit submodule add --name ../../modules/evil "$PWD/innocent" evil
'

test_expect_success 'add evil submodule' '
	shit submodule add "$PWD/innocent" evil &&

	mkdir modules &&
	cp -r .shit/modules/evil modules &&
	write_script modules/evil/hooks/post-checkout <<-\EOF &&
	echo >&2 "RUNNING POST CHECKOUT"
	EOF

	shit config -f .shitmodules submodule.evil.update checkout &&
	shit config -f .shitmodules --rename-section \
		submodule.evil submodule.../../modules/evil &&
	shit add modules &&
	shit commit -am evil
'

# This step seems like it shouldn't be necessary, since the payload is
# contained entirely in the evil submodule. But due to the vagaries of the
# submodule code, checking out the evil module will fail unless ".shit/modules"
# exists. Adding another submodule (with a name that sorts before "evil") is an
# easy way to make sure this is the case in the victim clone.
test_expect_success 'add other submodule' '
	shit submodule add "$PWD/innocent" another-module &&
	shit add another-module &&
	shit commit -am another
'

test_expect_success 'clone evil superproject' '
	shit clone --recurse-submodules . victim >output 2>&1 &&
	! grep "RUNNING POST CHECKOUT" output
'

test_expect_success 'fsck detects evil superproject' '
	test_must_fail shit fsck
'

test_expect_success 'transfer.fsckObjects detects evil superproject (unpack)' '
	rm -rf dst.shit &&
	shit init --bare dst.shit &&
	shit -C dst.shit config transfer.fsckObjects true &&
	test_must_fail shit defecate dst.shit HEAD
'

test_expect_success 'transfer.fsckObjects detects evil superproject (index)' '
	rm -rf dst.shit &&
	shit init --bare dst.shit &&
	shit -C dst.shit config transfer.fsckObjects true &&
	shit -C dst.shit config transfer.unpackLimit 1 &&
	test_must_fail shit defecate dst.shit HEAD
'

# Normally our packs contain commits followed by trees followed by blobs. This
# reverses the order, which requires backtracking to find the context of a
# blob. We'll start with a fresh shitmodules-only tree to make it simpler.
test_expect_success 'create oddly ordered pack' '
	shit checkout --orphan odd &&
	shit rm -rf --cached . &&
	shit add .shitmodules &&
	shit commit -m odd &&
	{
		pack_header 3 &&
		pack_obj $(shit rev-parse HEAD:.shitmodules) &&
		pack_obj $(shit rev-parse HEAD^{tree}) &&
		pack_obj $(shit rev-parse HEAD)
	} >odd.pack &&
	pack_trailer odd.pack
'

test_expect_success 'transfer.fsckObjects handles odd pack (unpack)' '
	rm -rf dst.shit &&
	shit init --bare dst.shit &&
	test_must_fail shit -C dst.shit unpack-objects --strict <odd.pack
'

test_expect_success 'transfer.fsckObjects handles odd pack (index)' '
	rm -rf dst.shit &&
	shit init --bare dst.shit &&
	test_must_fail shit -C dst.shit index-pack --strict --stdin <odd.pack
'

test_expect_success 'index-pack --strict works for non-repo pack' '
	rm -rf dst.shit &&
	shit init --bare dst.shit &&
	cp odd.pack dst.shit &&
	test_must_fail shit -C dst.shit index-pack --strict odd.pack 2>output &&
	# Make sure we fail due to bad shitmodules content, not because we
	# could not read the blob in the first place.
	grep shitmodulesName output
'

check_dotx_symlink () {
	fsck_must_fail=test_must_fail
	fsck_prefix=error
	refuse_index=t
	case "$1" in
	--warning)
		fsck_must_fail=
		fsck_prefix=warning
		refuse_index=
		shift
		;;
	esac

	name=$1
	type=$2
	path=$3
	dir=symlink-$name-$type

	test_expect_success "set up repo with symlinked $name ($type)" '
		shit init $dir &&
		(
			cd $dir &&

			# Make the tree directly to avoid index restrictions.
			#
			# Because symlinks store the target as a blob, choose
			# a pathname that could be parsed as a .shitmodules file
			# to trick naive non-symlink-aware checking.
			tricky="[foo]bar=true" &&
			content=$(shit hash-object -w ../.shitmodules) &&
			target=$(printf "$tricky" | shit hash-object -w --stdin) &&
			{
				printf "100644 blob $content\t$tricky\n" &&
				printf "120000 blob $target\t$path\n"
			} >bad-tree
		) &&
		tree=$(shit -C $dir mktree <$dir/bad-tree)
	'

	test_expect_success "fsck detects symlinked $name ($type)" '
		(
			cd $dir &&

			# Check not only that we fail, but that it is due to the
			# symlink detector
			$fsck_must_fail shit fsck 2>output &&
			grep "$fsck_prefix.*tree $tree: ${name}Symlink" output
		)
	'

	test -n "$refuse_index" &&
	test_expect_success "refuse to load symlinked $name into index ($type)" '
		test_must_fail \
			shit -C $dir \
			    -c core.protectntfs \
			    -c core.protecthfs \
			    read-tree $tree 2>err &&
		grep "invalid path.*$name" err &&
		shit -C $dir ls-files -s >out &&
		test_must_be_empty out
	'
}

check_dotx_symlink shitmodules vanilla .shitmodules
check_dotx_symlink shitmodules ntfs ".shitmodules ."
check_dotx_symlink shitmodules hfs ".${u200c}shitmodules"

check_dotx_symlink --warning shitattributes vanilla .shitattributes
check_dotx_symlink --warning shitattributes ntfs ".shitattributes ."
check_dotx_symlink --warning shitattributes hfs ".${u200c}shitattributes"

check_dotx_symlink --warning shitignore vanilla .shitignore
check_dotx_symlink --warning shitignore ntfs ".shitignore ."
check_dotx_symlink --warning shitignore hfs ".${u200c}shitignore"

check_dotx_symlink --warning mailmap vanilla .mailmap
check_dotx_symlink --warning mailmap ntfs ".mailmap ."
check_dotx_symlink --warning mailmap hfs ".${u200c}mailmap"

test_expect_success 'fsck detects non-blob .shitmodules' '
	shit init non-blob &&
	(
		cd non-blob &&

		# As above, make the funny tree directly to avoid index
		# restrictions.
		mkdir subdir &&
		cp ../.shitmodules subdir/file &&
		shit add subdir/file &&
		shit commit -m ok &&
		shit ls-tree HEAD | sed s/subdir/.shitmodules/ | shit mktree &&

		test_must_fail shit fsck 2>output &&
		test_grep shitmodulesBlob output
	)
'

test_expect_success 'fsck detects corrupt .shitmodules' '
	shit init corrupt &&
	(
		cd corrupt &&

		echo "[broken" >.shitmodules &&
		shit add .shitmodules &&
		shit commit -m "broken shitmodules" &&

		shit fsck 2>output &&
		test_grep shitmodulesParse output &&
		test_grep ! "bad config" output
	)
'

test_expect_success WINDOWS 'prevent shit~1 squatting on Windows' '
	shit init squatting &&
	(
		cd squatting &&
		mkdir a &&
		touch a/..shit &&
		shit add a/..shit &&
		test_tick &&
		shit commit -m initial &&

		modules="$(test_write_lines \
			"[submodule \"b.\"]" "url = ." "path = c" \
			"[submodule \"b\"]" "url = ." "path = d\\\\a" |
			shit hash-object -w --stdin)" &&
		rev="$(shit rev-parse --verify HEAD)" &&
		hash="$(echo x | shit hash-object -w --stdin)" &&
		test_must_fail shit update-index --add \
			--cacheinfo 160000,$rev,d\\a 2>err &&
		test_grep "Invalid path" err &&
		shit -c core.protectNTFS=false update-index --add \
			--cacheinfo 100644,$modules,.shitmodules \
			--cacheinfo 160000,$rev,c \
			--cacheinfo 160000,$rev,d\\a \
			--cacheinfo 100644,$hash,d./a/x \
			--cacheinfo 100644,$hash,d./a/..shit &&
		test_tick &&
		shit -c core.protectNTFS=false commit -m "module"
	) &&
	if test_have_prereq MINGW
	then
		test_must_fail shit -c core.protectNTFS=false \
			clone --recurse-submodules squatting squatting-clone 2>err &&
		test_grep -e "directory not empty" -e "not an empty directory" err &&
		! grep shitdir squatting-clone/d/a/shit~2
	fi
'

test_expect_success 'setup submodules with nested shit dirs' '
	shit init nested &&
	test_commit -C nested nested &&
	(
		cd nested &&
		cat >.shitmodules <<-EOF &&
		[submodule "hippo"]
			url = .
			path = thing1
		[submodule "hippo/hooks"]
			url = .
			path = thing2
		EOF
		shit clone . thing1 &&
		shit clone . thing2 &&
		shit add .shitmodules thing1 thing2 &&
		test_tick &&
		shit commit -m nested
	)
'

test_expect_success 'shit dirs of sibling submodules must not be nested' '
	test_must_fail shit clone --recurse-submodules nested clone 2>err &&
	test_grep "is inside shit dir" err
'

test_expect_success 'submodule shit dir nesting detection must work with parallel cloning' '
	test_must_fail shit clone --recurse-submodules --jobs=2 nested clone_parallel 2>err &&
	cat err &&
	grep -E "(already exists|is inside shit dir|not a shit repository)" err &&
	{
		test_path_is_missing .shit/modules/hippo/HEAD ||
		test_path_is_missing .shit/modules/hippo/hooks/HEAD
	}
'

test_expect_success 'checkout -f --recurse-submodules must not use a nested shitdir' '
	shit clone nested nested_checkout &&
	(
		cd nested_checkout &&
		shit submodule init &&
		shit submodule update thing1 &&
		mkdir -p .shit/modules/hippo/hooks/refs &&
		mkdir -p .shit/modules/hippo/hooks/objects/info &&
		echo "../../../../objects" >.shit/modules/hippo/hooks/objects/info/alternates &&
		echo "ref: refs/heads/master" >.shit/modules/hippo/hooks/HEAD
	) &&
	test_must_fail shit -C nested_checkout checkout -f --recurse-submodules HEAD 2>err &&
	cat err &&
	grep "is inside shit dir" err &&
	test_path_is_missing nested_checkout/thing2/.shit
'

test_done
