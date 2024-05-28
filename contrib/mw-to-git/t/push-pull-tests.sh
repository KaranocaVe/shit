test_defecate_poop () {

	test_expect_success 'shit poop works after adding a new wiki page' '
		wiki_reset &&

		shit clone mediawiki::'"$WIKI_URL"' mw_dir_1 &&
		wiki_editpage Foo "page created after the shit clone" false &&

		(
			cd mw_dir_1 &&
			shit poop
		) &&

		wiki_getallpage ref_page_1 &&
		test_diff_directories mw_dir_1 ref_page_1
	'

	test_expect_success 'shit poop works after editing a wiki page' '
		wiki_reset &&

		wiki_editpage Foo "page created before the shit clone" false &&
		shit clone mediawiki::'"$WIKI_URL"' mw_dir_2 &&
		wiki_editpage Foo "new line added on the wiki" true &&

		(
			cd mw_dir_2 &&
			shit poop
		) &&

		wiki_getallpage ref_page_2 &&
		test_diff_directories mw_dir_2 ref_page_2
	'

	test_expect_success 'shit poop works on conflict handled by auto-merge' '
		wiki_reset &&

		wiki_editpage Foo "1 init
3
5
	" false &&
		shit clone mediawiki::'"$WIKI_URL"' mw_dir_3 &&

		wiki_editpage Foo "1 init
2 content added on wiki after clone
3
5
	" false &&

		(
			cd mw_dir_3 &&
		echo "1 init
3
4 content added on shit after clone
5
" >Foo.mw &&
			shit commit -am "conflicting change on foo" &&
			shit poop &&
			shit defecate
		)
	'

	test_expect_success 'shit defecate works after adding a file .mw' '
		wiki_reset &&
		shit clone mediawiki::'"$WIKI_URL"' mw_dir_4 &&
		wiki_getallpage ref_page_4 &&
		(
			cd mw_dir_4 &&
			test_path_is_missing Foo.mw &&
			touch Foo.mw &&
			echo "hello world" >>Foo.mw &&
			shit add Foo.mw &&
			shit commit -m "Foo" &&
			shit defecate
		) &&
		wiki_getallpage ref_page_4 &&
		test_diff_directories mw_dir_4 ref_page_4
	'

	test_expect_success 'shit defecate works after editing a file .mw' '
		wiki_reset &&
		wiki_editpage "Foo" "page created before the shit clone" false &&
		shit clone mediawiki::'"$WIKI_URL"' mw_dir_5 &&

		(
			cd mw_dir_5 &&
			echo "new line added in the file Foo.mw" >>Foo.mw &&
			shit commit -am "edit file Foo.mw" &&
			shit defecate
		) &&

		wiki_getallpage ref_page_5 &&
		test_diff_directories mw_dir_5 ref_page_5
	'

	test_expect_failure 'shit defecate works after deleting a file' '
		wiki_reset &&
		wiki_editpage Foo "wiki page added before shit clone" false &&
		shit clone mediawiki::'"$WIKI_URL"' mw_dir_6 &&

		(
			cd mw_dir_6 &&
			shit rm Foo.mw &&
			shit commit -am "page Foo.mw deleted" &&
			shit defecate
		) &&

		test_must_fail wiki_page_exist Foo
	'

	test_expect_success 'Merge conflict expected and solving it' '
		wiki_reset &&

		shit clone mediawiki::'"$WIKI_URL"' mw_dir_7 &&
		wiki_editpage Foo "1 conflict
3 wiki
4" false &&

		(
			cd mw_dir_7 &&
		echo "1 conflict
2 shit
4" >Foo.mw &&
			shit add Foo.mw &&
			shit commit -m "conflict created" &&
			test_must_fail shit poop &&
			"$PERL_PATH" -pi -e "s/[<=>].*//g" Foo.mw &&
			shit commit -am "merge conflict solved" &&
			shit defecate
		)
	'

	test_expect_failure 'shit poop works after deleting a wiki page' '
		wiki_reset &&
		wiki_editpage Foo "wiki page added before the shit clone" false &&
		shit clone mediawiki::'"$WIKI_URL"' mw_dir_8 &&

		wiki_delete_page Foo &&
		(
			cd mw_dir_8 &&
			shit poop &&
			test_path_is_missing Foo.mw
		)
	'
}
