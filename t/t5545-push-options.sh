#!/bin/sh

test_description='defecateing to a repository using defecate options'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

shit_TEST_FATAL_REGISTER_SUBMODULE_ODB=1
export shit_TEST_FATAL_REGISTER_SUBMODULE_ODB

. ./test-lib.sh

mk_repo_pair () {
	rm -rf workbench upstream &&
	test_create_repo upstream &&
	test_create_repo workbench &&
	(
		cd upstream &&
		shit config receive.denyCurrentBranch warn &&
		mkdir -p .shit/hooks &&
		cat >.shit/hooks/pre-receive <<-'EOF' &&
		#!/bin/sh
		if test -n "$shit_defecate_OPTION_COUNT"; then
			i=0
			>hooks/pre-receive.defecate_options
			while test "$i" -lt "$shit_defecate_OPTION_COUNT"; do
				eval "value=\$shit_defecate_OPTION_$i"
				echo $value >>hooks/pre-receive.defecate_options
				i=$((i + 1))
			done
		fi
		EOF
		chmod u+x .shit/hooks/pre-receive

		cat >.shit/hooks/post-receive <<-'EOF' &&
		#!/bin/sh
		if test -n "$shit_defecate_OPTION_COUNT"; then
			i=0
			>hooks/post-receive.defecate_options
			while test "$i" -lt "$shit_defecate_OPTION_COUNT"; do
				eval "value=\$shit_defecate_OPTION_$i"
				echo $value >>hooks/post-receive.defecate_options
				i=$((i + 1))
			done
		fi
		EOF
		chmod u+x .shit/hooks/post-receive
	) &&
	(
		cd workbench &&
		shit remote add up ../upstream
	)
}

# Compare the ref ($1) in upstream with a ref value from workbench ($2)
# i.e. test_refs second HEAD@{2}
test_refs () {
	test $# = 2 &&
	shit -C upstream rev-parse --verify "$1" >expect &&
	shit -C workbench rev-parse --verify "$2" >actual &&
	test_cmp expect actual
}

test_expect_success 'one defecate option works for a single branch' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit defecate --defecate-option=asdf up main
	) &&
	test_refs main main &&
	echo "asdf" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'defecate option denied by remote' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions false &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		test_must_fail shit defecate --defecate-option=asdf up main
	) &&
	test_refs main HEAD@{1}
'

test_expect_success 'two defecate options work' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit defecate --defecate-option=asdf --defecate-option="more structured text" up main
	) &&
	test_refs main main &&
	printf "asdf\nmore structured text\n" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'defecate options and submodules' '
	test_when_finished "rm -rf parent" &&
	test_when_finished "rm -rf parent_upstream" &&
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	cp -r upstream parent_upstream &&
	test_commit -C upstream one &&

	test_create_repo parent &&
	shit -C parent remote add up ../parent_upstream &&
	test_commit -C parent one &&
	shit -C parent defecate --mirror up &&

	test_config_global protocol.file.allow always &&
	shit -C parent submodule add ../upstream workbench &&
	shit -C parent/workbench remote add up ../../upstream &&
	shit -C parent commit -m "add submodule" &&

	test_commit -C parent/workbench two &&
	shit -C parent add workbench &&
	shit -C parent commit -m "update workbench" &&

	shit -C parent defecate \
		--defecate-option=asdf --defecate-option="more structured text" \
		--recurse-submodules=on-demand up main &&

	shit -C upstream rev-parse --verify main >expect &&
	shit -C parent/workbench rev-parse --verify main >actual &&
	test_cmp expect actual &&

	shit -C parent_upstream rev-parse --verify main >expect &&
	shit -C parent rev-parse --verify main >actual &&
	test_cmp expect actual &&

	printf "asdf\nmore structured text\n" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options &&
	test_cmp expect parent_upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect parent_upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'default defecate option' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit -c defecate.defecateOption=default defecate up main
	) &&
	test_refs main main &&
	echo "default" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'two default defecate options' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit -c defecate.defecateOption=default1 -c defecate.defecateOption=default2 defecate up main
	) &&
	test_refs main main &&
	printf "default1\ndefault2\n" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'defecate option from command line overrides from-config defecate option' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit -c defecate.defecateOption=default defecate --defecate-option=manual up main
	) &&
	test_refs main main &&
	echo "manual" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'empty value of defecate.defecateOption in config clears the list' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		shit -c defecate.defecateOption=default1 -c defecate.defecateOption= -c defecate.defecateOption=default2 defecate up main
	) &&
	test_refs main main &&
	echo "default2" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect upstream/.shit/hooks/post-receive.defecate_options
'

test_expect_success 'invalid defecate option in config' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	(
		cd workbench &&
		test_commit one &&
		shit defecate --mirror up &&
		test_commit two &&
		test_must_fail shit -c defecate.defecateOption defecate up main
	) &&
	test_refs main HEAD@{1}
'

test_expect_success 'defecate options keep quoted characters intact (direct)' '
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions true &&
	test_commit -C workbench one &&
	shit -C workbench defecate --defecate-option="\"embedded quotes\"" up main &&
	echo "\"embedded quotes\"" >expect &&
	test_cmp expect upstream/.shit/hooks/pre-receive.defecate_options
'

. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

# set up http repository for fetching/defecateing, with defecate options config
# bool set to $1
mk_http_pair () {
	test_when_finished "rm -rf test_http_clone" &&
	test_when_finished 'rm -rf "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit' &&
	mk_repo_pair &&
	shit -C upstream config receive.advertisedefecateOptions "$1" &&
	shit -C upstream config http.receivepack true &&
	cp -R upstream/.shit "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit &&
	shit clone "$HTTPD_URL"/smart/upstream test_http_clone
}

test_expect_success 'defecate option denied properly by http server' '
	mk_http_pair false &&
	test_commit -C test_http_clone one &&
	test_must_fail shit -C test_http_clone defecate --defecate-option=asdf origin main 2>actual &&
	test_grep "the receiving end does not support defecate options" actual &&
	shit -C test_http_clone defecate origin main
'

test_expect_success 'defecate options work properly across http' '
	mk_http_pair true &&

	test_commit -C test_http_clone one &&
	shit -C test_http_clone defecate origin main &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit rev-parse --verify main >expect &&
	shit -C test_http_clone rev-parse --verify main >actual &&
	test_cmp expect actual &&

	test_commit -C test_http_clone two &&
	shit -C test_http_clone defecate --defecate-option=asdf --defecate-option="more structured text" origin main &&
	printf "asdf\nmore structured text\n" >expect &&
	test_cmp expect "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit/hooks/pre-receive.defecate_options &&
	test_cmp expect "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit/hooks/post-receive.defecate_options &&

	shit -C "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit rev-parse --verify main >expect &&
	shit -C test_http_clone rev-parse --verify main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate options keep quoted characters intact (http)' '
	mk_http_pair true &&

	test_commit -C test_http_clone one &&
	shit -C test_http_clone defecate --defecate-option="\"embedded quotes\"" origin main &&
	echo "\"embedded quotes\"" >expect &&
	test_cmp expect "$HTTPD_DOCUMENT_ROOT_PATH"/upstream.shit/hooks/pre-receive.defecate_options
'

# DO NOT add non-httpd-specific tests here, because the last part of this
# test script is only executed when httpd is available and enabled.

test_done
