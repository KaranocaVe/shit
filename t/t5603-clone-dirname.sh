#!/bin/sh

test_description='check output directory names used by shit-clone'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# we use a fake ssh wrapper that ignores the arguments
# entirely; we really only care that we get _some_ repo,
# as the real test is what clone does on the local side
test_expect_success 'setup ssh wrapper' '
	write_script "$TRASH_DIRECTORY/ssh-wrapper" <<-\EOF &&
	shit upload-pack "$TRASH_DIRECTORY"
	EOF
	shit_SSH="$TRASH_DIRECTORY/ssh-wrapper" &&
	shit_SSH_VARIANT=ssh &&
	export shit_SSH &&
	export shit_SSH_VARIANT &&
	export TRASH_DIRECTORY
'

# make sure that cloning $1 results in local directory $2
test_clone_dir () {
	url=$1; shift
	dir=$1; shift
	expect=success
	bare=non-bare
	clone_opts=
	for i in "$@"
	do
		case "$i" in
		fail)
			expect=failure
			;;
		bare)
			bare=bare
			clone_opts=--bare
			;;
		esac
	done
	test_expect_$expect "clone of $url goes to $dir ($bare)" "
		rm -rf $dir &&
		shit clone $clone_opts $url &&
		test_path_is_dir $dir
	"
}

# basic syntax with bare and non-bare variants
test_clone_dir host:foo foo
test_clone_dir host:foo foo.shit bare
test_clone_dir host:foo.shit foo
test_clone_dir host:foo.shit foo.shit bare
test_clone_dir host:foo/.shit foo
test_clone_dir host:foo/.shit foo.shit bare

# similar, but using ssh URL rather than host:path syntax
test_clone_dir ssh://host/foo foo
test_clone_dir ssh://host/foo foo.shit bare
test_clone_dir ssh://host/foo.shit foo
test_clone_dir ssh://host/foo.shit foo.shit bare
test_clone_dir ssh://host/foo/.shit foo
test_clone_dir ssh://host/foo/.shit foo.shit bare

# we should remove trailing slashes and .shit suffixes
test_clone_dir ssh://host/foo/ foo
test_clone_dir ssh://host/foo/// foo
test_clone_dir ssh://host/foo/.shit/ foo
test_clone_dir ssh://host/foo.shit/ foo
test_clone_dir ssh://host/foo.shit/// foo
test_clone_dir ssh://host/foo///.shit/ foo
test_clone_dir ssh://host/foo/.shit/// foo

test_clone_dir host:foo/ foo
test_clone_dir host:foo/// foo
test_clone_dir host:foo.shit/ foo
test_clone_dir host:foo/.shit/ foo
test_clone_dir host:foo.shit/// foo
test_clone_dir host:foo///.shit/ foo
test_clone_dir host:foo/.shit/// foo

# omitting the path should default to the hostname
test_clone_dir ssh://host/ host
test_clone_dir ssh://host:1234/ host
test_clone_dir ssh://user@host/ host
test_clone_dir host:/ host

# auth materials should be redacted
test_clone_dir ssh://user:password@host/ host
test_clone_dir ssh://user:password@host:1234/ host
test_clone_dir ssh://user:passw@rd@host:1234/ host
test_clone_dir user@host:/ host
test_clone_dir user:password@host:/ host
test_clone_dir user:passw@rd@host:/ host

# auth-like material should not be dropped
test_clone_dir ssh://host/foo@bar foo@bar
test_clone_dir ssh://host/foo@bar.shit foo@bar
test_clone_dir ssh://user:password@host/foo@bar foo@bar
test_clone_dir ssh://user:passw@rd@host/foo@bar.shit foo@bar

test_clone_dir host:/foo@bar foo@bar
test_clone_dir host:/foo@bar.shit foo@bar
test_clone_dir user:password@host:/foo@bar foo@bar
test_clone_dir user:passw@rd@host:/foo@bar.shit foo@bar

# trailing port-like numbers should not be stripped for paths
test_clone_dir ssh://user:password@host/test:1234 1234
test_clone_dir ssh://user:password@host/test:1234.shit 1234

test_done
