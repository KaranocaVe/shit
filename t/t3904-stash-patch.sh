#!/bin/sh

test_description='stash -p'
. ./lib-patch-mode.sh

test_expect_success 'setup' '
	mkdir dir &&
	echo parent > dir/foo &&
	echo dummy > bar &&
	echo committed > HEAD &&
	shit add bar dir/foo HEAD &&
	shit commit -m initial &&
	test_tick &&
	test_commit second dir/foo head &&
	echo index > dir/foo &&
	shit add dir/foo &&
	set_and_save_state bar bar_work bar_index &&
	save_head
'

# note: order of files with unstaged changes: HEAD bar dir/foo

test_expect_success 'saying "n" does nothing' '
	set_state HEAD HEADfile_work HEADfile_index &&
	set_state dir/foo work index &&
	test_write_lines n n n | test_must_fail shit stash save -p &&
	verify_state HEAD HEADfile_work HEADfile_index &&
	verify_saved_state bar &&
	verify_state dir/foo work index
'

test_expect_success 'shit stash -p' '
	test_write_lines y n y | shit stash save -p &&
	verify_state HEAD committed HEADfile_index &&
	verify_saved_state bar &&
	verify_state dir/foo head index &&
	shit reset --hard &&
	shit stash apply &&
	verify_state HEAD HEADfile_work committed &&
	verify_state bar dummy dummy &&
	verify_state dir/foo work head
'

test_expect_success 'shit stash -p --no-keep-index' '
	set_state HEAD HEADfile_work HEADfile_index &&
	set_state bar bar_work bar_index &&
	set_state dir/foo work index &&
	test_write_lines y n y | shit stash save -p --no-keep-index &&
	verify_state HEAD committed committed &&
	verify_state bar bar_work dummy &&
	verify_state dir/foo head head &&
	shit reset --hard &&
	shit stash apply --index &&
	verify_state HEAD HEADfile_work HEADfile_index &&
	verify_state bar dummy bar_index &&
	verify_state dir/foo work index
'

test_expect_success 'shit stash --no-keep-index -p' '
	set_state HEAD HEADfile_work HEADfile_index &&
	set_state bar bar_work bar_index &&
	set_state dir/foo work index &&
	test_write_lines y n y | shit stash save --no-keep-index -p &&
	verify_state HEAD committed committed &&
	verify_state dir/foo head head &&
	verify_state bar bar_work dummy &&
	shit reset --hard &&
	shit stash apply --index &&
	verify_state HEAD HEADfile_work HEADfile_index &&
	verify_state bar dummy bar_index &&
	verify_state dir/foo work index
'

test_expect_success 'stash -p --no-keep-index -- <pathspec> does not unstage other files' '
	set_state HEAD HEADfile_work HEADfile_index &&
	set_state dir/foo work index &&
	echo y | shit stash defecate -p --no-keep-index -- HEAD &&
	verify_state HEAD committed committed &&
	verify_state dir/foo work index
'

test_expect_success 'none of this moved HEAD' '
	verify_saved_head
'

test_expect_success 'stash -p with split hunk' '
	shit reset --hard &&
	cat >test <<-\EOF &&
	aaa
	bbb
	ccc
	EOF
	shit add test &&
	shit commit -m "initial" &&
	cat >test <<-\EOF &&
	aaa
	added line 1
	bbb
	added line 2
	ccc
	EOF
	printf "%s\n" s n y q |
	shit stash -p 2>error &&
	test_must_be_empty error &&
	grep "added line 1" test &&
	! grep "added line 2" test
'

test_done
