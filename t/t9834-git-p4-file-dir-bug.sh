#!/bin/sh

test_description='shit p4 directory/file bug handling

This test creates files and directories with the same name in perforce and
checks that shit-p4 recovers from the error at the same time as the perforce
repository.'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d &&
	{ p4 configure set submit.collision.check=0 || :; }
'

test_expect_success 'init depot' '
	(
		cd "$cli" &&

		touch add_file_add_dir_del_file add_file_add_dir_del_dir &&
		p4 add add_file_add_dir_del_file add_file_add_dir_del_dir &&
		mkdir add_dir_add_file_del_file add_dir_add_file_del_dir &&
		touch add_dir_add_file_del_file/file add_dir_add_file_del_dir/file &&
		p4 add add_dir_add_file_del_file/file add_dir_add_file_del_dir/file &&
		p4 submit -d "add initial" &&

		rm -f add_file_add_dir_del_file add_file_add_dir_del_dir &&
		mkdir add_file_add_dir_del_file add_file_add_dir_del_dir &&
		touch add_file_add_dir_del_file/file add_file_add_dir_del_dir/file &&
		p4 add add_file_add_dir_del_file/file add_file_add_dir_del_dir/file &&
		rm -rf add_dir_add_file_del_file add_dir_add_file_del_dir &&
		touch add_dir_add_file_del_file add_dir_add_file_del_dir &&
		p4 add add_dir_add_file_del_file add_dir_add_file_del_dir &&
		p4 submit -d "add conflicting" &&

		p4 delete -k add_file_add_dir_del_file &&
		p4 delete -k add_file_add_dir_del_dir/file &&
		p4 delete -k add_dir_add_file_del_file &&
		p4 delete -k add_dir_add_file_del_dir/file &&
		p4 submit -d "delete conflicting" &&

		p4 delete -k "add_file_add_dir_del_file/file" &&
		p4 delete -k "add_file_add_dir_del_dir" &&
		p4 delete -k "add_dir_add_file_del_file/file" &&
		p4 delete -k "add_dir_add_file_del_dir" &&
		p4 submit -d "delete remaining"
	)
'

test_expect_success 'clone with shit-p4' '
	shit p4 clone --dest="$shit" //depot/@1,3
'

test_expect_success 'check contents' '
	test_path_is_dir "$shit/add_file_add_dir_del_file" &&
	test_path_is_file "$shit/add_file_add_dir_del_dir" &&
	test_path_is_dir "$shit/add_dir_add_file_del_file" &&
	test_path_is_file "$shit/add_dir_add_file_del_dir"
'

test_expect_success 'rebase and check empty' '
	shit -C "$shit" p4 rebase &&

	test_path_is_missing "$shit/add_file_add_dir_del_file" &&
	test_path_is_missing "$shit/add_file_add_dir_del_dir" &&
	test_path_is_missing "$shit/add_dir_add_file_del_file" &&
	test_path_is_missing "$shit/add_dir_add_file_del_dir"
'

test_done
