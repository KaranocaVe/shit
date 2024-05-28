#!/bin/sh

setup_basic_ls_tree_data () {
	mkdir dir &&
	test_commit dir/sub-file &&
	test_commit top-file &&
	shit clone . submodule &&
	shit submodule add ./submodule &&
	shit commit -m"add submodule"
}
