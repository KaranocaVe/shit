#!/bin/sh

test_description='shit p4 relative chdir'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'init depot' '
	(
		cd "$cli" &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "change 1"
	)
'

# P4 reads from P4CONFIG file to find its server params, if the
# environment variable is set
test_expect_success 'P4CONFIG and absolute dir clone' '
	printf "P4PORT=$P4PORT\nP4CLIENT=$P4CLIENT\n" >p4config &&
	test_when_finished "rm p4config" &&
	test_when_finished cleanup_shit &&
	(
		P4CONFIG=p4config && export P4CONFIG &&
		sane_unset P4PORT P4CLIENT &&
		shit p4 clone --verbose --dest="$shit" //depot
	)
'

# same thing, but with relative directory name, note missing $ on --dest
test_expect_success 'P4CONFIG and relative dir clone' '
	printf "P4PORT=$P4PORT\nP4CLIENT=$P4CLIENT\n" >p4config &&
	test_when_finished "rm p4config" &&
	test_when_finished cleanup_shit &&
	(
		P4CONFIG=p4config && export P4CONFIG &&
		sane_unset P4PORT P4CLIENT &&
		shit p4 clone --verbose --dest="shit" //depot
	)
'

# Common setup using .p4config to set P4CLIENT and P4PORT breaks
# if clone destination is relative.  Make sure that chdir() expands
# the relative path in --dest to absolute.
test_expect_success 'p4 client root would be relative due to clone --dest' '
	test_when_finished cleanup_shit &&
	(
		echo P4PORT=$P4PORT >shit/.p4config &&
		P4CONFIG=.p4config &&
		export P4CONFIG &&
		unset P4PORT &&
		shit p4 clone --dest="shit" //depot
	)
'

# When the p4 client Root is a symlink, make sure chdir() does not use
# getcwd() to convert it to a physical path.
test_expect_success SYMLINKS 'p4 client root symlink should stay symbolic' '
	physical="$TRASH_DIRECTORY/physical" &&
	symbolic="$TRASH_DIRECTORY/symbolic" &&
	test_when_finished "rm -rf \"$physical\"" &&
	test_when_finished "rm \"$symbolic\"" &&
	mkdir -p "$physical" &&
	ln -s "$physical" "$symbolic" &&
	test_when_finished cleanup_shit &&
	(
		P4CLIENT=client-sym &&
		p4 client -i <<-EOF &&
		Client: $P4CLIENT
		Description: $P4CLIENT
		Root: $symbolic
		LineEnd: unix
		View: //depot/... //$P4CLIENT/...
		EOF
		shit p4 clone --dest="$shit" //depot &&
		cd "$shit" &&
		test_commit file2 &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	)
'

test_done
