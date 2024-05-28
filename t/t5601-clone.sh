#!/bin/sh

test_description=clone

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

X=
test_have_prereq !MINGW || X=.exe

test_expect_success setup '

	rm -fr .shit &&
	test_create_repo src &&
	(
		cd src &&
		>file &&
		shit add file &&
		shit commit -m initial &&
		echo 1 >file &&
		shit add file &&
		shit commit -m updated
	)

'

test_expect_success 'clone with excess parameters (1)' '

	rm -fr dst &&
	test_must_fail shit clone -n src dst junk

'

test_expect_success 'clone with excess parameters (2)' '

	rm -fr dst &&
	test_must_fail shit clone -n "file://$(pwd)/src" dst junk

'

test_expect_success 'output from clone' '
	rm -fr dst &&
	shit clone -n "file://$(pwd)/src" dst >output 2>&1 &&
	test $(grep Clon output | wc -l) = 1
'

test_expect_success 'clone does not keep pack' '

	rm -fr dst &&
	shit clone -n "file://$(pwd)/src" dst &&
	! test -f dst/file &&
	! (echo dst/.shit/objects/pack/pack-* | grep "\.keep")

'

test_expect_success 'clone checks out files' '

	rm -fr dst &&
	shit clone src dst &&
	test -f dst/file

'

test_expect_success 'clone respects shit_WORK_TREE' '

	shit_WORK_TREE=worktree shit clone src bare &&
	test -f bare/config &&
	test -f worktree/file

'

test_expect_success 'clone from hooks' '

	test_create_repo r0 &&
	cd r0 &&
	test_commit initial &&
	cd .. &&
	shit init r1 &&
	cd r1 &&
	test_hook pre-commit <<-\EOF &&
	shit clone ../r0 ../r2
	exit 1
	EOF
	: >file &&
	shit add file &&
	test_must_fail shit commit -m invoke-hook &&
	cd .. &&
	test_cmp r0/.shit/HEAD r2/.shit/HEAD &&
	test_cmp r0/initial.t r2/initial.t

'

test_expect_success 'clone creates intermediate directories' '

	shit clone src long/path/to/dst &&
	test -f long/path/to/dst/file

'

test_expect_success 'clone creates intermediate directories for bare repo' '

	shit clone --bare src long/path/to/bare/dst &&
	test -f long/path/to/bare/dst/config

'

test_expect_success 'clone --mirror' '

	shit clone --mirror src mirror &&
	test -f mirror/HEAD &&
	test ! -f mirror/file &&
	FETCH="$(cd mirror && shit config remote.origin.fetch)" &&
	test "+refs/*:refs/*" = "$FETCH" &&
	MIRROR="$(cd mirror && shit config --bool remote.origin.mirror)" &&
	test "$MIRROR" = true

'

test_expect_success 'clone --mirror with detached HEAD' '

	( cd src && shit checkout HEAD^ && shit rev-parse HEAD >../expected ) &&
	shit clone --mirror src mirror.detached &&
	( cd src && shit checkout - ) &&
	shit_DIR=mirror.detached shit rev-parse HEAD >actual &&
	test_cmp expected actual

'

test_expect_success 'clone --bare with detached HEAD' '

	( cd src && shit checkout HEAD^ && shit rev-parse HEAD >../expected ) &&
	shit clone --bare src bare.detached &&
	( cd src && shit checkout - ) &&
	shit_DIR=bare.detached shit rev-parse HEAD >actual &&
	test_cmp expected actual

'

test_expect_success 'clone --bare names the local repository <name>.shit' '

	shit clone --bare src &&
	test -d src.shit

'

test_expect_success 'clone --mirror does not repeat tags' '

	(cd src &&
	 shit tag some-tag HEAD) &&
	shit clone --mirror src mirror2 &&
	(cd mirror2 &&
	 shit show-ref 2> clone.err > clone.out) &&
	! grep Duplicate mirror2/clone.err &&
	grep some-tag mirror2/clone.out

'

test_expect_success 'clone with files ref format' '
	test_when_finished "rm -rf ref-storage" &&
	shit clone --ref-format=files --mirror src ref-storage &&
	echo files >expect &&
	shit -C ref-storage rev-parse --show-ref-format >actual &&
	test_cmp expect actual
'

test_expect_success 'clone with garbage ref format' '
	cat >expect <<-EOF &&
	fatal: unknown ref storage format ${SQ}garbage${SQ}
	EOF
	test_must_fail shit clone --ref-format=garbage --mirror src ref-storage 2>err &&
	test_cmp expect err &&
	test_path_is_missing ref-storage
'

test_expect_success 'clone to destination with trailing /' '

	shit clone src target-1/ &&
	T=$( cd target-1 && shit rev-parse HEAD ) &&
	S=$( cd src && shit rev-parse HEAD ) &&
	test "$T" = "$S"

'

test_expect_success 'clone to destination with extra trailing /' '

	shit clone src target-2/// &&
	T=$( cd target-2 && shit rev-parse HEAD ) &&
	S=$( cd src && shit rev-parse HEAD ) &&
	test "$T" = "$S"

'

test_expect_success 'clone to an existing empty directory' '
	mkdir target-3 &&
	shit clone src target-3 &&
	T=$( cd target-3 && shit rev-parse HEAD ) &&
	S=$( cd src && shit rev-parse HEAD ) &&
	test "$T" = "$S"
'

test_expect_success 'clone to an existing non-empty directory' '
	mkdir target-4 &&
	>target-4/Fakefile &&
	test_must_fail shit clone src target-4
'

test_expect_success 'clone to an existing path' '
	>target-5 &&
	test_must_fail shit clone src target-5
'

test_expect_success 'clone a void' '
	mkdir src-0 &&
	(
		cd src-0 && shit init
	) &&
	shit clone "file://$(pwd)/src-0" target-6 2>err-6 &&
	! grep "fatal:" err-6 &&
	(
		cd src-0 && test_commit A
	) &&
	shit clone "file://$(pwd)/src-0" target-7 2>err-7 &&
	! grep "fatal:" err-7 &&
	# There is no reason to insist they are bit-for-bit
	# identical, but this test should suffice for now.
	test_cmp target-6/.shit/config target-7/.shit/config
'

test_expect_success 'clone respects global branch.autosetuprebase' '
	(
		test_config="$HOME/.shitconfig" &&
		shit config -f "$test_config" branch.autosetuprebase remote &&
		rm -fr dst &&
		shit clone src dst &&
		cd dst &&
		actual="z$(shit config branch.main.rebase)" &&
		test ztrue = $actual
	)
'

test_expect_success 'respect url-encoding of file://' '
	shit init x+y &&
	shit clone "file://$PWD/x+y" xy-url-1 &&
	shit clone "file://$PWD/x%2By" xy-url-2
'

test_expect_success 'do not query-string-decode + in URLs' '
	rm -rf x+y &&
	shit init "x y" &&
	test_must_fail shit clone "file://$PWD/x+y" xy-no-plus
'

test_expect_success 'do not respect url-encoding of non-url path' '
	shit init x+y &&
	test_must_fail shit clone x%2By xy-regular &&
	shit clone x+y xy-regular
'

test_expect_success 'clone separate shitdir' '
	rm -rf dst &&
	shit clone --separate-shit-dir realshitdir src dst &&
	test -d realshitdir/refs
'

test_expect_success 'clone separate shitdir: output' '
	echo "shitdir: $(pwd)/realshitdir" >expected &&
	test_cmp expected dst/.shit
'

test_expect_success 'clone from .shit file' '
	shit clone dst/.shit dst2
'

test_expect_success 'fetch from .shit shitfile' '
	(
		cd dst2 &&
		shit fetch ../dst/.shit
	)
'

test_expect_success 'fetch from shitfile parent' '
	(
		cd dst2 &&
		shit fetch ../dst
	)
'

test_expect_success 'clone separate shitdir where target already exists' '
	rm -rf dst &&
	echo foo=bar >>realshitdir/config &&
	test_must_fail shit clone --separate-shit-dir realshitdir src dst &&
	grep foo=bar realshitdir/config
'

test_expect_success 'clone --reference from original' '
	shit clone --shared --bare src src-1 &&
	shit clone --bare src src-2 &&
	shit clone --reference=src-2 --bare src-1 target-8 &&
	grep /src-2/ target-8/objects/info/alternates
'

test_expect_success 'clone with more than one --reference' '
	shit clone --bare src src-3 &&
	shit clone --bare src src-4 &&
	shit clone --reference=src-3 --reference=src-4 src target-9 &&
	grep /src-3/ target-9/.shit/objects/info/alternates &&
	grep /src-4/ target-9/.shit/objects/info/alternates
'

test_expect_success 'clone from original with relative alternate' '
	mkdir nest &&
	shit clone --bare src nest/src-5 &&
	echo ../../../src/.shit/objects >nest/src-5/objects/info/alternates &&
	shit clone --bare nest/src-5 target-10 &&
	grep /src/\\.shit/objects target-10/objects/info/alternates
'

test_expect_success 'clone checking out a tag' '
	shit clone --branch=some-tag src dst.tag &&
	shit_DIR=src/.shit shit rev-parse some-tag >expected &&
	shit_DIR=dst.tag/.shit shit rev-parse HEAD >actual &&
	test_cmp expected actual &&
	shit_DIR=dst.tag/.shit shit config remote.origin.fetch >fetch.actual &&
	echo "+refs/heads/*:refs/remotes/origin/*" >fetch.expected &&
	test_cmp fetch.expected fetch.actual
'

test_expect_success 'set up ssh wrapper' '
	cp "$shit_BUILD_DIR/t/helper/test-fake-ssh$X" \
		"$TRASH_DIRECTORY/ssh$X" &&
	shit_SSH="$TRASH_DIRECTORY/ssh$X" &&
	export shit_SSH &&
	export TRASH_DIRECTORY &&
	>"$TRASH_DIRECTORY"/ssh-output
'

copy_ssh_wrapper_as () {
	rm -f "${1%$X}$X" &&
	cp "$TRASH_DIRECTORY/ssh$X" "${1%$X}$X" &&
	test_when_finished "rm $(shit rev-parse --sq-quote "${1%$X}$X")" &&
	shit_SSH="${1%$X}$X" &&
	test_when_finished "shit_SSH=\"\$TRASH_DIRECTORY/ssh\$X\""
}

expect_ssh () {
	test_when_finished '
		(cd "$TRASH_DIRECTORY" && rm -f ssh-expect && >ssh-output)
	' &&
	{
		case "$#" in
		1)
			;;
		2)
			echo "ssh: $1 shit-upload-pack '$2'"
			;;
		3)
			echo "ssh: $1 $2 shit-upload-pack '$3'"
			;;
		*)
			echo "ssh: $1 $2 shit-upload-pack '$3' $4"
		esac
	} >"$TRASH_DIRECTORY/ssh-expect" &&
	(cd "$TRASH_DIRECTORY" && test_cmp ssh-expect ssh-output)
}

test_expect_success 'clone myhost:src uses ssh' '
	shit_TEST_PROTOCOL_VERSION=0 shit clone myhost:src ssh-clone &&
	expect_ssh myhost src
'

test_expect_success !MINGW,!CYGWIN 'clone local path foo:bar' '
	cp -R src "foo:bar" &&
	shit clone "foo:bar" foobar &&
	expect_ssh none
'

test_expect_success 'bracketed hostnames are still ssh' '
	shit_TEST_PROTOCOL_VERSION=0 shit clone "[myhost:123]:src" ssh-bracket-clone &&
	expect_ssh "-p 123" myhost src
'

test_expect_success 'OpenSSH variant passes -4' '
	shit_TEST_PROTOCOL_VERSION=0 shit clone -4 "[myhost:123]:src" ssh-ipv4-clone &&
	expect_ssh "-4 -p 123" myhost src
'

test_expect_success 'variant can be overridden' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/putty" &&
	shit -c ssh.variant=putty clone -4 "[myhost:123]:src" ssh-putty-clone &&
	expect_ssh "-4 -P 123" myhost src
'

test_expect_success 'variant=auto picks based on basename' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink" &&
	shit -c ssh.variant=auto clone -4 "[myhost:123]:src" ssh-auto-clone &&
	expect_ssh "-4 -P 123" myhost src
'

test_expect_success 'simple does not support -4/-6' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/simple" &&
	test_must_fail shit clone -4 "myhost:src" ssh-4-clone-simple
'

test_expect_success 'simple does not support port' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/simple" &&
	test_must_fail shit clone "[myhost:123]:src" ssh-bracket-clone-simple
'

test_expect_success 'uplink is treated as simple' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/uplink" &&
	test_must_fail shit clone "[myhost:123]:src" ssh-bracket-clone-uplink &&
	shit clone "myhost:src" ssh-clone-uplink &&
	expect_ssh myhost src
'

test_expect_success 'OpenSSH-like uplink is treated as ssh' '
	write_script "$TRASH_DIRECTORY/uplink" <<-EOF &&
	if test "\$1" = "-G"
	then
		exit 0
	fi &&
	exec "\$TRASH_DIRECTORY/ssh$X" "\$@"
	EOF
	test_when_finished "rm -f \"\$TRASH_DIRECTORY/uplink\"" &&
	shit_SSH="$TRASH_DIRECTORY/uplink" &&
	test_when_finished "shit_SSH=\"\$TRASH_DIRECTORY/ssh\$X\"" &&
	shit_TEST_PROTOCOL_VERSION=0 shit clone "[myhost:123]:src" ssh-bracket-clone-sshlike-uplink &&
	expect_ssh "-p 123" myhost src
'

test_expect_success 'plink is treated specially (as putty)' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink" &&
	shit clone "[myhost:123]:src" ssh-bracket-clone-plink-0 &&
	expect_ssh "-P 123" myhost src
'

test_expect_success 'plink.exe is treated specially (as putty)' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink.exe" &&
	shit clone "[myhost:123]:src" ssh-bracket-clone-plink-1 &&
	expect_ssh "-P 123" myhost src
'

test_expect_success 'tortoiseplink is like putty, with extra arguments' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/tortoiseplink" &&
	shit clone "[myhost:123]:src" ssh-bracket-clone-plink-2 &&
	expect_ssh "-batch -P 123" myhost src
'

test_expect_success 'double quoted plink.exe in shit_SSH_COMMAND' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink.exe" &&
	shit_SSH_COMMAND="\"$TRASH_DIRECTORY/plink.exe\" -v" \
		shit clone "[myhost:123]:src" ssh-bracket-clone-plink-3 &&
	expect_ssh "-v -P 123" myhost src
'

test_expect_success 'single quoted plink.exe in shit_SSH_COMMAND' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink.exe" &&
	shit_SSH_COMMAND="$SQ$TRASH_DIRECTORY/plink.exe$SQ -v" \
		shit clone "[myhost:123]:src" ssh-bracket-clone-plink-4 &&
	expect_ssh "-v -P 123" myhost src
'

test_expect_success 'shit_SSH_VARIANT overrides plink detection' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink" &&
	shit_TEST_PROTOCOL_VERSION=0 shit_SSH_VARIANT=ssh \
		shit clone "[myhost:123]:src" ssh-bracket-clone-variant-1 &&
	expect_ssh "-p 123" myhost src
'

test_expect_success 'ssh.variant overrides plink detection' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink" &&
	shit_TEST_PROTOCOL_VERSION=0 shit -c ssh.variant=ssh \
		clone "[myhost:123]:src" ssh-bracket-clone-variant-2 &&
	expect_ssh "-p 123" myhost src
'

test_expect_success 'shit_SSH_VARIANT overrides plink detection to plink' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink" &&
	shit_SSH_VARIANT=plink \
	shit clone "[myhost:123]:src" ssh-bracket-clone-variant-3 &&
	expect_ssh "-P 123" myhost src
'

test_expect_success 'shit_SSH_VARIANT overrides plink to tortoiseplink' '
	copy_ssh_wrapper_as "$TRASH_DIRECTORY/plink" &&
	shit_SSH_VARIANT=tortoiseplink \
	shit clone "[myhost:123]:src" ssh-bracket-clone-variant-4 &&
	expect_ssh "-batch -P 123" myhost src
'

test_expect_success 'clean failure on broken quoting' '
	test_must_fail \
		env shit_SSH_COMMAND="${SQ}plink.exe -v" \
		shit clone "[myhost:123]:src" sq-failure
'

counter=0
# $1 url
# $2 none|host
# $3 path
test_clone_url () {
	counter=$(($counter + 1))
	test_might_fail env shit_TEST_PROTOCOL_VERSION=0 shit clone "$1" tmp$counter &&
	shift &&
	expect_ssh "$@"
}

test_expect_success !MINGW,!CYGWIN 'clone c:temp is ssl' '
	test_clone_url c:temp c temp
'

test_expect_success MINGW 'clone c:temp is dos drive' '
	test_clone_url c:temp none
'

#ip v4
for repo in rep rep/home/project 123
do
	test_expect_success "clone host:$repo" '
		test_clone_url host:$repo host $repo
	'
done

#ipv6
for repo in rep rep/home/project 123
do
	test_expect_success "clone [::1]:$repo" '
		test_clone_url [::1]:$repo ::1 "$repo"
	'
done
#home directory
test_expect_success "clone host:/~repo" '
	test_clone_url host:/~repo host "~repo"
'

test_expect_success "clone [::1]:/~repo" '
	test_clone_url [::1]:/~repo ::1 "~repo"
'

# Corner cases
for url in foo/bar:baz [foo]bar/baz:qux [foo/bar]:baz
do
	test_expect_success "clone $url is not ssh" '
		test_clone_url $url none
	'
done

#with ssh:// scheme
#ignore trailing colon
for tcol in "" :
do
	test_expect_success "clone ssh://host.xz$tcol/home/user/repo" '
		test_clone_url "ssh://host.xz$tcol/home/user/repo" host.xz /home/user/repo
	'
	# from home directory
	test_expect_success "clone ssh://host.xz$tcol/~repo" '
	test_clone_url "ssh://host.xz$tcol/~repo" host.xz "~repo"
'
done

# with port number
test_expect_success 'clone ssh://host.xz:22/home/user/repo' '
	test_clone_url "ssh://host.xz:22/home/user/repo" "-p 22 host.xz" "/home/user/repo"
'

# from home directory with port number
test_expect_success 'clone ssh://host.xz:22/~repo' '
	test_clone_url "ssh://host.xz:22/~repo" "-p 22 host.xz" "~repo"
'

#IPv6
for tuah in ::1 [::1] [::1]: user@::1 user@[::1] user@[::1]: [user@::1] [user@::1]:
do
	ehost=$(echo $tuah | sed -e "s/1]:/1]/" | tr -d "[]")
	test_expect_success "clone ssh://$tuah/home/user/repo" "
	  test_clone_url ssh://$tuah/home/user/repo $ehost /home/user/repo
	"
done

#IPv6 from home directory
for tuah in ::1 [::1] user@::1 user@[::1] [user@::1]
do
	euah=$(echo $tuah | tr -d "[]")
	test_expect_success "clone ssh://$tuah/~repo" "
	  test_clone_url ssh://$tuah/~repo $euah '~repo'
	"
done

#IPv6 with port number
for tuah in [::1] user@[::1] [user@::1]
do
	euah=$(echo $tuah | tr -d "[]")
	test_expect_success "clone ssh://$tuah:22/home/user/repo" "
	  test_clone_url ssh://$tuah:22/home/user/repo '-p 22' $euah /home/user/repo
	"
done

#IPv6 from home directory with port number
for tuah in [::1] user@[::1] [user@::1]
do
	euah=$(echo $tuah | tr -d "[]")
	test_expect_success "clone ssh://$tuah:22/~repo" "
	  test_clone_url ssh://$tuah:22/~repo '-p 22' $euah '~repo'
	"
done

test_expect_success 'clone from a repository with two identical branches' '

	(
		cd src &&
		shit checkout -b another main
	) &&
	shit clone src target-11 &&
	test "z$( cd target-11 && shit symbolic-ref HEAD )" = zrefs/heads/another

'

test_expect_success 'shallow clone locally' '
	shit clone --depth=1 --no-local src ssrrcc &&
	shit clone ssrrcc ddsstt &&
	test_cmp ssrrcc/.shit/shallow ddsstt/.shit/shallow &&
	( cd ddsstt && shit fsck )
'

test_expect_success 'shit_TRACE_PACKFILE produces a usable pack' '
	rm -rf dst.shit &&
	shit_TRACE_PACKFILE=$PWD/tmp.pack shit clone --no-local --bare src dst.shit &&
	shit init --bare replay.shit &&
	shit -C replay.shit index-pack -v --stdin <tmp.pack
'

test_expect_success 'clone on case-insensitive fs' '
	shit init icasefs &&
	(
		cd icasefs &&
		o=$(shit hash-object -w --stdin </dev/null | hex2oct) &&
		t=$(printf "100644 X\0${o}100644 x\0${o}" |
			shit hash-object -w -t tree --stdin) &&
		c=$(shit commit-tree -m bogus $t) &&
		shit update-ref refs/heads/bogus $c &&
		shit clone -b bogus . bogus 2>warning
	)
'

test_expect_success CASE_INSENSITIVE_FS 'colliding file detection' '
	grep X icasefs/warning &&
	grep x icasefs/warning &&
	test_grep "the following paths have collided" icasefs/warning
'

test_expect_success CASE_INSENSITIVE_FS,SYMLINKS \
		'colliding symlink/directory keeps directory' '
	shit init icasefs-colliding-symlink &&
	(
		cd icasefs-colliding-symlink &&
		a=$(printf a | shit hash-object -w --stdin) &&
		printf "100644 %s 0\tA/dir/b\n120000 %s 0\ta\n" $a $a >idx &&
		shit update-index --index-info <idx &&
		test_tick &&
		shit commit -m initial
	) &&
	shit clone icasefs-colliding-symlink icasefs-colliding-symlink-clone &&
	test_file_not_empty icasefs-colliding-symlink-clone/A/dir/b
'

test_expect_success 'clone with shit_DEFAULT_HASH' '
	(
		sane_unset shit_DEFAULT_HASH &&
		shit init --object-format=sha1 test-sha1 &&
		shit init --object-format=sha256 test-sha256
	) &&
	test_commit -C test-sha1 foo &&
	test_commit -C test-sha256 foo &&
	shit_DEFAULT_HASH=sha1 shit clone test-sha256 test-clone-sha256 &&
	shit_DEFAULT_HASH=sha256 shit clone test-sha1 test-clone-sha1 &&
	shit -C test-clone-sha1 status &&
	shit -C test-clone-sha256 status
'

partial_clone_server () {
	       SERVER="$1" &&

	rm -rf "$SERVER" client &&
	test_create_repo "$SERVER" &&
	test_commit -C "$SERVER" one &&
	HASH1=$(shit -C "$SERVER" hash-object one.t) &&
	shit -C "$SERVER" revert HEAD &&
	test_commit -C "$SERVER" two &&
	HASH2=$(shit -C "$SERVER" hash-object two.t) &&
	test_config -C "$SERVER" uploadpack.allowfilter 1 &&
	test_config -C "$SERVER" uploadpack.allowanysha1inwant 1
}

partial_clone () {
	       SERVER="$1" &&
	       URL="$2" &&

	partial_clone_server "${SERVER}" &&
	shit clone --filter=blob:limit=0 "$URL" client &&

	shit -C client fsck &&

	# Ensure that unneeded blobs are not inadvertently fetched.
	test_config -C client remote.origin.promisor "false" &&
	shit -C client config --unset remote.origin.partialclonefilter &&
	test_must_fail shit -C client cat-file -e "$HASH1" &&

	# But this blob was fetched, because clone performs an initial checkout
	shit -C client cat-file -e "$HASH2"
}

test_expect_success 'partial clone' '
	partial_clone server "file://$(pwd)/server"
'

test_expect_success 'partial clone with -o' '
	partial_clone_server server &&
	shit clone -o blah --filter=blob:limit=0 "file://$(pwd)/server" client &&
	test_cmp_config -C client "blob:limit=0" --get-all remote.blah.partialclonefilter
'

test_expect_success 'partial clone: warn if server does not support object filtering' '
	rm -rf server client &&
	test_create_repo server &&
	test_commit -C server one &&

	shit clone --filter=blob:limit=0 "file://$(pwd)/server" client 2> err &&

	test_grep "filtering not recognized by server" err
'

test_expect_success 'batch missing blob request during checkout' '
	rm -rf server client &&

	test_create_repo server &&
	echo a >server/a &&
	echo b >server/b &&
	shit -C server add a b &&

	shit -C server commit -m x &&
	echo aa >server/a &&
	echo bb >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&

	shit clone --filter=blob:limit=0 "file://$(pwd)/server" client &&

	# Ensure that there is only one negotiation by checking that there is
	# only "done" line sent. ("done" marks the end of negotiation.)
	shit_TRACE_PACKET="$(pwd)/trace" \
		shit_TRACE2_EVENT="$(pwd)/trace2_event" \
		shit -C client -c trace2.eventNesting=5 checkout HEAD^ &&
	grep \"key\":\"total_rounds\",\"value\":\"1\" trace2_event >trace_lines &&
	test_line_count = 1 trace_lines &&
	grep "fetch> done" trace >done_lines &&
	test_line_count = 1 done_lines
'

test_expect_success 'batch missing blob request does not inadvertently try to fetch shitlinks' '
	rm -rf server client &&

	test_create_repo repo_for_submodule &&
	test_commit -C repo_for_submodule x &&

	test_create_repo server &&
	echo a >server/a &&
	echo b >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&

	echo aa >server/a &&
	echo bb >server/b &&
	# Also add a shitlink pointing to an arbitrary repository
	test_config_global protocol.file.allow always &&
	shit -C server submodule add "$(pwd)/repo_for_submodule" c &&
	shit -C server add a b c &&
	shit -C server commit -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&

	# Make sure that it succeeds
	shit clone --filter=blob:limit=0 "file://$(pwd)/server" client
'

test_expect_success 'clone with init.templatedir runs hooks' '
	shit init tmpl/hooks &&
	write_script tmpl/hooks/post-checkout <<-EOF &&
	echo HOOK-RUN >&2
	echo I was here >hook.run
	EOF
	shit -C tmpl/hooks add . &&
	test_tick &&
	shit -C tmpl/hooks commit -m post-checkout &&

	test_when_finished "shit config --global --unset init.templateDir || :" &&
	test_when_finished "shit config --unset init.templateDir || :" &&
	(
		sane_unset shit_TEMPLATE_DIR &&
		NO_SET_shit_TEMPLATE_DIR=t &&
		export NO_SET_shit_TEMPLATE_DIR &&

		shit -c core.hooksPath="$(pwd)/tmpl/hooks" \
			clone tmpl/hooks hook-run-hookspath 2>err &&
		test_grep ! "active .* hook found" err &&
		test_path_is_file hook-run-hookspath/hook.run &&

		shit -c init.templateDir="$(pwd)/tmpl" \
			clone tmpl/hooks hook-run-config 2>err &&
		test_grep ! "active .* hook found" err &&
		test_path_is_file hook-run-config/hook.run &&

		shit clone --template=tmpl tmpl/hooks hook-run-option 2>err &&
		test_grep ! "active .* hook found" err &&
		test_path_is_file hook-run-option/hook.run &&

		shit config --global init.templateDir "$(pwd)/tmpl" &&
		shit clone tmpl/hooks hook-run-global-config 2>err &&
		shit config --global --unset init.templateDir &&
		test_grep ! "active .* hook found" err &&
		test_path_is_file hook-run-global-config/hook.run &&

		# clone ignores local `init.templateDir`; need to create
		# a new repository because we deleted `.shit/` in the
		# `setup` test case above
		shit init local-clone &&
		cd local-clone &&

		shit config init.templateDir "$(pwd)/../tmpl" &&
		shit clone ../tmpl/hooks hook-run-local-config 2>err &&
		shit config --unset init.templateDir &&
		test_grep ! "active .* hook found" err &&
		test_path_is_missing hook-run-local-config/hook.run
	)
'

. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

test_expect_success 'clone with includeIf' '
	test_when_finished "rm -rf repo \"$HTTPD_DOCUMENT_ROOT_PATH/repo.shit\"" &&
	shit clone --bare --no-local src "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&

	test_when_finished "rm \"$HOME\"/.shitconfig" &&
	cat >"$HOME"/.shitconfig <<-EOF &&
	[includeIf "onbranch:something"]
		path = /does/not/exist.inc
	EOF
	shit clone $HTTPD_URL/smart/repo.shit repo
'

test_expect_success 'partial clone using HTTP' '
	partial_clone "$HTTPD_DOCUMENT_ROOT_PATH/server" "$HTTPD_URL/smart/server"
'

test_expect_success 'reject cloning shallow repository using HTTP' '
	test_when_finished "rm -rf repo" &&
	shit clone --bare --no-local --depth=1 src "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	test_must_fail shit -c protocol.version=2 clone --reject-shallow $HTTPD_URL/smart/repo.shit repo 2>err &&
	test_grep -e "source repository is shallow, reject to clone." err &&

	shit clone --no-reject-shallow $HTTPD_URL/smart/repo.shit repo
'

test_expect_success 'auto-discover bundle URI from HTTP clone' '
	test_when_finished rm -rf trace.txt repo2 "$HTTPD_DOCUMENT_ROOT_PATH/repo2.shit" &&
	shit -C src bundle create "$HTTPD_DOCUMENT_ROOT_PATH/everything.bundle" --all &&
	shit clone --bare --no-local src "$HTTPD_DOCUMENT_ROOT_PATH/repo2.shit" &&

	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo2.shit" config \
		uploadpack.advertiseBundleURIs true &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo2.shit" config \
		bundle.version 1 &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo2.shit" config \
		bundle.mode all &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo2.shit" config \
		bundle.everything.uri "$HTTPD_URL/everything.bundle" &&

	shit_TRACE2_EVENT="$(pwd)/trace.txt" \
		shit -c protocol.version=2 \
		    -c transfer.bundleURI=true clone \
		$HTTPD_URL/smart/repo2.shit repo2 &&
	cat >pattern <<-EOF &&
	"event":"child_start".*"argv":\["shit-remote-https","$HTTPD_URL/everything.bundle"\]
	EOF
	grep -f pattern trace.txt
'

test_expect_success 'auto-discover multiple bundles from HTTP clone' '
	test_when_finished rm -rf trace.txt repo3 "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" &&

	test_commit -C src new &&
	shit -C src bundle create "$HTTPD_DOCUMENT_ROOT_PATH/new.bundle" HEAD~1..HEAD &&
	shit clone --bare --no-local src "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" &&

	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" config \
		uploadpack.advertiseBundleURIs true &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" config \
		bundle.version 1 &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" config \
		bundle.mode all &&

	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" config \
		bundle.everything.uri "$HTTPD_URL/everything.bundle" &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo3.shit" config \
		bundle.new.uri "$HTTPD_URL/new.bundle" &&

	shit_TRACE2_EVENT="$(pwd)/trace.txt" \
		shit -c protocol.version=2 \
		    -c transfer.bundleURI=true clone \
		$HTTPD_URL/smart/repo3.shit repo3 &&

	# We should fetch _both_ bundles
	cat >pattern <<-EOF &&
	"event":"child_start".*"argv":\["shit-remote-https","$HTTPD_URL/everything.bundle"\]
	EOF
	grep -f pattern trace.txt &&
	cat >pattern <<-EOF &&
	"event":"child_start".*"argv":\["shit-remote-https","$HTTPD_URL/new.bundle"\]
	EOF
	grep -f pattern trace.txt
'

test_expect_success 'auto-discover multiple bundles from HTTP clone: creationToken heuristic' '
	test_when_finished rm -rf "$HTTPD_DOCUMENT_ROOT_PATH/repo4.shit" &&
	test_when_finished rm -rf clone-heuristic trace*.txt &&

	test_commit -C src newest &&
	shit -C src bundle create "$HTTPD_DOCUMENT_ROOT_PATH/newest.bundle" HEAD~1..HEAD &&
	shit clone --bare --no-local src "$HTTPD_DOCUMENT_ROOT_PATH/repo4.shit" &&

	cat >>"$HTTPD_DOCUMENT_ROOT_PATH/repo4.shit/config" <<-EOF &&
	[uploadPack]
		advertiseBundleURIs = true

	[bundle]
		version = 1
		mode = all
		heuristic = creationToken

	[bundle "everything"]
		uri = $HTTPD_URL/everything.bundle
		creationtoken = 1

	[bundle "new"]
		uri = $HTTPD_URL/new.bundle
		creationtoken = 2

	[bundle "newest"]
		uri = $HTTPD_URL/newest.bundle
		creationtoken = 3
	EOF

	shit_TRACE2_EVENT="$(pwd)/trace-clone.txt" \
		shit -c protocol.version=2 \
		    -c transfer.bundleURI=true clone \
		"$HTTPD_URL/smart/repo4.shit" clone-heuristic &&

	cat >expect <<-EOF &&
	$HTTPD_URL/newest.bundle
	$HTTPD_URL/new.bundle
	$HTTPD_URL/everything.bundle
	EOF

	# We should fetch all bundles in the expected order.
	test_remote_https_urls <trace-clone.txt >actual &&
	test_cmp expect actual
'

# DO NOT add non-httpd-specific tests here, because the last part of this
# test script is only executed when httpd is available and enabled.

test_done
