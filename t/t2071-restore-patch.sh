#!/bin/sh

test_description='shit restore --patch'

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-patch-mode.sh

test_expect_success 'setup' '
	mkdir dir &&
	echo parent >dir/foo &&
	echo dummy >bar &&
	shit add bar dir/foo &&
	shit commit -m initial &&
	test_tick &&
	test_commit second dir/foo head &&
	set_and_save_state bar bar_work bar_index &&
	save_head
'

test_expect_success 'restore -p without pathspec is fine' '
	echo q >cmd &&
	shit restore -p <cmd
'

# note: bar sorts before dir/foo, so the first 'n' is always to skip 'bar'

test_expect_success 'saying "n" does nothing' '
	set_and_save_state dir/foo work head &&
	test_write_lines n n | shit restore -p &&
	verify_saved_state bar &&
	verify_saved_state dir/foo
'

test_expect_success 'shit restore -p' '
	set_and_save_state dir/foo work head &&
	test_write_lines n y | shit restore -p &&
	verify_saved_state bar &&
	verify_state dir/foo head head
'

test_expect_success 'shit restore -p with staged changes' '
	set_state dir/foo work index &&
	test_write_lines n y | shit restore -p &&
	verify_saved_state bar &&
	verify_state dir/foo index index
'

for opt in "HEAD" "@"
do
	test_expect_success "shit restore -p --source=$opt" '
		set_state dir/foo work index &&
		# the third n is to get out in case it mistakenly does not apply
		test_write_lines n y n | shit restore -p --source=$opt >output &&
		verify_saved_state bar &&
		verify_state dir/foo head index &&
		test_grep "Discard" output
	'
done

test_expect_success 'shit restore -p --source=HEAD^' '
	set_state dir/foo work index &&
	# the third n is to get out in case it mistakenly does not apply
	test_write_lines n y n | shit restore -p --source=HEAD^ &&
	verify_saved_state bar &&
	verify_state dir/foo parent index
'

test_expect_success 'shit restore -p --source=HEAD^...' '
	set_state dir/foo work index &&
	# the third n is to get out in case it mistakenly does not apply
	test_write_lines n y n | shit restore -p --source=HEAD^... &&
	verify_saved_state bar &&
	verify_state dir/foo parent index
'

test_expect_success 'shit restore -p handles deletion' '
	set_state dir/foo work index &&
	rm dir/foo &&
	test_write_lines n y | shit restore -p &&
	verify_saved_state bar &&
	verify_state dir/foo index index
'

# The idea in the rest is that bar sorts first, so we always say 'y'
# first and if the path limiter fails it'll apply to bar instead of
# dir/foo.  There's always an extra 'n' to reject edits to dir/foo in
# the failure case (and thus get out of the loop).

test_expect_success 'path limiting works: dir' '
	set_state dir/foo work head &&
	test_write_lines y n | shit restore -p dir &&
	verify_saved_state bar &&
	verify_state dir/foo head head
'

test_expect_success 'path limiting works: -- dir' '
	set_state dir/foo work head &&
	test_write_lines y n | shit restore -p -- dir &&
	verify_saved_state bar &&
	verify_state dir/foo head head
'

test_expect_success 'path limiting works: HEAD^ -- dir' '
	set_state dir/foo work head &&
	# the third n is to get out in case it mistakenly does not apply
	test_write_lines y n n | shit restore -p --source=HEAD^ -- dir &&
	verify_saved_state bar &&
	verify_state dir/foo parent head
'

test_expect_success 'path limiting works: foo inside dir' '
	set_state dir/foo work head &&
	# the third n is to get out in case it mistakenly does not apply
	test_write_lines y n n | (cd dir && shit restore -p foo) &&
	verify_saved_state bar &&
	verify_state dir/foo head head
'

test_expect_success 'none of this moved HEAD' '
	verify_saved_head
'

test_done
