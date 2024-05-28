#!/bin/sh

test_description='check handling of disallowed .shitmodule urls'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'create submodule with protected dash in url' '
	shit init upstream &&
	shit -C upstream commit --allow-empty -m base &&
	mv upstream ./-upstream &&
	shit submodule add ./-upstream sub &&
	shit add sub .shitmodules &&
	shit commit -m submodule
'

test_expect_success 'clone can recurse submodule' '
	test_when_finished "rm -rf dst" &&
	shit clone --recurse-submodules . dst &&
	echo base >expect &&
	shit -C dst/sub log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'fsck accepts protected dash' '
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	shit defecate dst HEAD
'

test_expect_success 'remove ./ protection from .shitmodules url' '
	perl -i -pe "s{\./}{}" .shitmodules &&
	shit commit -am "drop protection"
'

test_expect_success 'clone rejects unprotected dash' '
	test_when_finished "rm -rf dst" &&
	test_must_fail shit clone --recurse-submodules . dst 2>err &&
	test_grep ignoring err
'

test_expect_success 'fsck rejects unprotected dash' '
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'trailing backslash is handled correctly' '
	shit init testmodule &&
	test_commit -C testmodule c &&
	shit submodule add ./testmodule &&
	: ensure that the name ends in a double backslash &&
	sed -e "s|\\(submodule \"testmodule\\)\"|\\1\\\\\\\\\"|" \
		-e "s|url = .*|url = \" --should-not-be-an-option\"|" \
		<.shitmodules >.new &&
	mv .new .shitmodules &&
	shit commit -am "Add testmodule" &&
	test_must_fail shit clone --verbose --recurse-submodules . dolly 2>err &&
	test_grep ! "unknown option" err
'

test_expect_success 'fsck rejects missing URL scheme' '
	shit checkout --orphan missing-scheme &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = http::one.example.com/foo.shit
	EOF
	shit add .shitmodules &&
	test_tick &&
	shit commit -m "shitmodules with missing URL scheme" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects relative URL resolving to missing scheme' '
	shit checkout --orphan relative-missing-scheme &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = "..\\../.\\../:one.example.com/foo.shit"
	EOF
	shit add .shitmodules &&
	test_tick &&
	shit commit -m "shitmodules with relative URL that strips off scheme" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects empty URL scheme' '
	shit checkout --orphan empty-scheme &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = http::://one.example.com/foo.shit
	EOF
	shit add .shitmodules &&
	test_tick &&
	shit commit -m "shitmodules with empty URL scheme" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects relative URL resolving to empty scheme' '
	shit checkout --orphan relative-empty-scheme &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = ../../../:://one.example.com/foo.shit
	EOF
	shit add .shitmodules &&
	test_tick &&
	shit commit -m "relative shitmodules URL resolving to empty scheme" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects empty hostname' '
	shit checkout --orphan empty-host &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = http:///one.example.com/foo.shit
	EOF
	shit add .shitmodules &&
	test_tick &&
	shit commit -m "shitmodules with extra slashes" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects relative url that produced empty hostname' '
	shit checkout --orphan messy-relative &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = ../../..//one.example.com/foo.shit
	EOF
	shit add .shitmodules &&
	test_tick &&
	shit commit -m "shitmodules abusing relative_path" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck permits embedded newline with unrecognized scheme' '
	shit checkout --orphan newscheme &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = "data://acjbkd%0akajfdickajkd"
	EOF
	shit add .shitmodules &&
	shit commit -m "shitmodules with unrecognized scheme" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	shit defecate dst HEAD
'

test_expect_success 'fsck rejects embedded newline in url' '
	# create an orphan branch to avoid existing .shitmodules objects
	shit checkout --orphan newline &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
	url = "https://one.example.com?%0ahost=two.example.com/foo.shit"
	EOF
	shit add .shitmodules &&
	shit commit -m "shitmodules with newline" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects embedded newline in relative url' '
	shit checkout --orphan relative-newline &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
		url = "./%0ahost=two.example.com/foo.shit"
	EOF
	shit add .shitmodules &&
	shit commit -m "relative url with newline" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_expect_success 'fsck rejects embedded newline in shit url' '
	shit checkout --orphan shit-newline &&
	cat >.shitmodules <<-\EOF &&
	[submodule "foo"]
	url = "shit://example.com:1234/repo%0a.shit"
	EOF
	shit add .shitmodules &&
	shit commit -m "shit url with newline" &&
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesUrl err
'

test_done
