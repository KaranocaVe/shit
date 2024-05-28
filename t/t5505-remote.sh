#!/bin/sh

test_description='shit remote porcelain-ish'

. ./test-lib.sh

setup_repository () {
	mkdir "$1" && (
	cd "$1" &&
	shit init -b main &&
	>file &&
	shit add file &&
	test_tick &&
	shit commit -m "Initial" &&
	shit checkout -b side &&
	>elif &&
	shit add elif &&
	test_tick &&
	shit commit -m "Second" &&
	shit checkout main
	)
}

tokens_match () {
	echo "$1" | tr ' ' '\012' | sort | sed -e '/^$/d' >expect &&
	echo "$2" | tr ' ' '\012' | sort | sed -e '/^$/d' >actual &&
	test_cmp expect actual
}

check_remote_track () {
	actual=$(shit remote show "$1" | sed -ne 's|^    \(.*\) tracked$|\1|p')
	shift &&
	tokens_match "$*" "$actual"
}

check_tracking_branch () {
	f="" &&
	r=$(shit for-each-ref "--format=%(refname)" |
		sed -ne "s|^refs/remotes/$1/||p") &&
	shift &&
	tokens_match "$*" "$r"
}

test_expect_success setup '
	setup_repository one &&
	setup_repository two &&
	(
		cd two &&
		shit branch another
	) &&
	shit clone one test
'

test_expect_success 'add remote whose URL agrees with url.<...>.insteadOf' '
	test_config url.shit@host.com:team/repo.shit.insteadOf myremote &&
	shit remote add myremote shit@host.com:team/repo.shit
'

test_expect_success 'remote information for the origin' '
	(
		cd test &&
		tokens_match origin "$(shit remote)" &&
		check_remote_track origin main side &&
		check_tracking_branch origin HEAD main side
	)
'

test_expect_success 'add another remote' '
	(
		cd test &&
		shit remote add -f second ../two &&
		tokens_match "origin second" "$(shit remote)" &&
		check_tracking_branch second main side another &&
		shit for-each-ref "--format=%(refname)" refs/remotes |
		sed -e "/^refs\/remotes\/origin\//d" \
		    -e "/^refs\/remotes\/second\//d" >actual &&
		test_must_be_empty actual
	)
'

test_expect_success 'setup bare clone for server' '
	shit clone --bare "file://$(pwd)/one" srv.bare &&
	shit -C srv.bare config --local uploadpack.allowfilter 1 &&
	shit -C srv.bare config --local uploadpack.allowanysha1inwant 1
'

test_expect_success 'filters for promisor remotes are listed by shit remote -v' '
	test_when_finished "rm -rf pc" &&
	shit clone --filter=blob:none "file://$(pwd)/srv.bare" pc &&
	shit -C pc remote -v >out &&
	grep "srv.bare (fetch) \[blob:none\]" out &&

	shit -C pc config remote.origin.partialCloneFilter object:type=commit &&
	shit -C pc remote -v >out &&
	grep "srv.bare (fetch) \[object:type=commit\]" out
'

test_expect_success 'filters should not be listed for non promisor remotes (remote -v)' '
	test_when_finished "rm -rf pc" &&
	shit clone one pc &&
	shit -C pc remote -v >out &&
	! grep "(fetch) \[.*\]" out
'

test_expect_success 'filters are listed by shit remote -v only' '
	test_when_finished "rm -rf pc" &&
	shit clone --filter=blob:none "file://$(pwd)/srv.bare" pc &&
	shit -C pc remote >out &&
	! grep "\[blob:none\]" out &&

	shit -C pc remote show >out &&
	! grep "\[blob:none\]" out
'

test_expect_success 'check remote-tracking' '
	(
		cd test &&
		check_remote_track origin main side &&
		check_remote_track second main side another
	)
'

test_expect_success 'remote forces tracking branches' '
	(
		cd test &&
		case $(shit config remote.second.fetch) in
		+*) true ;;
		 *) false ;;
		esac
	)
'

test_expect_success 'remove remote' '
	(
		cd test &&
		shit symbolic-ref refs/remotes/second/HEAD refs/remotes/second/main &&
		shit remote rm second
	)
'

test_expect_success 'remove remote' '
	(
		cd test &&
		tokens_match origin "$(shit remote)" &&
		check_remote_track origin main side &&
		shit for-each-ref "--format=%(refname)" refs/remotes |
		sed -e "/^refs\/remotes\/origin\//d" >actual &&
		test_must_be_empty actual
	)
'

test_expect_success 'remove remote protects local branches' '
	(
		cd test &&
		cat >expect1 <<-\EOF &&
		Note: A branch outside the refs/remotes/ hierarchy was not removed;
		to delete it, use:
		  shit branch -d main
		EOF
		cat >expect2 <<-\EOF &&
		Note: Some branches outside the refs/remotes/ hierarchy were not removed;
		to delete them, use:
		  shit branch -d foobranch
		  shit branch -d main
		EOF
		shit tag footag &&
		shit config --add remote.oops.fetch "+refs/*:refs/*" &&
		shit remote remove oops 2>actual1 &&
		shit branch foobranch &&
		shit config --add remote.oops.fetch "+refs/*:refs/*" &&
		shit remote rm oops 2>actual2 &&
		shit branch -d foobranch &&
		shit tag -d footag &&
		test_cmp expect1 actual1 &&
		test_cmp expect2 actual2
	)
'

test_expect_success 'remove errors out early when deleting non-existent branch' '
	(
		cd test &&
		echo "error: No such remote: '\''foo'\''" >expect &&
		test_expect_code 2 shit remote rm foo 2>actual &&
		test_cmp expect actual
	)
'

test_expect_success 'remove remote with a branch without configured merge' '
	test_when_finished "(
		shit -C test checkout main;
		shit -C test branch -D two;
		shit -C test config --remove-section remote.two;
		shit -C test config --remove-section branch.second;
		true
	)" &&
	(
		cd test &&
		shit remote add two ../two &&
		shit fetch two &&
		shit checkout -b second two/main^0 &&
		shit config branch.second.remote two &&
		shit checkout main &&
		shit remote rm two
	)
'

test_expect_success 'rename errors out early when deleting non-existent branch' '
	(
		cd test &&
		echo "error: No such remote: '\''foo'\''" >expect &&
		test_expect_code 2 shit remote rename foo bar 2>actual &&
		test_cmp expect actual
	)
'

test_expect_success 'rename errors out early when new name is invalid' '
	test_config remote.foo.vcs bar &&
	echo "fatal: '\''invalid...name'\'' is not a valid remote name" >expect &&
	test_must_fail shit remote rename foo invalid...name 2>actual &&
	test_cmp expect actual
'

test_expect_success 'add existing foreign_vcs remote' '
	test_config remote.foo.vcs bar &&
	echo "error: remote foo already exists." >expect &&
	test_expect_code 3 shit remote add foo bar 2>actual &&
	test_cmp expect actual
'

test_expect_success 'add existing foreign_vcs remote' '
	test_config remote.foo.vcs bar &&
	test_config remote.bar.vcs bar &&
	echo "error: remote bar already exists." >expect &&
	test_expect_code 3 shit remote rename foo bar 2>actual &&
	test_cmp expect actual
'

test_expect_success 'add invalid foreign_vcs remote' '
	echo "fatal: '\''invalid...name'\'' is not a valid remote name" >expect &&
	test_must_fail shit remote add invalid...name bar 2>actual &&
	test_cmp expect actual
'

test_expect_success 'without subcommand' '
	echo origin >expect &&
	shit -C test remote >actual &&
	test_cmp expect actual
'

test_expect_success 'without subcommand accepts -v' '
	cat >expect <<-EOF &&
	origin	$(pwd)/one (fetch)
	origin	$(pwd)/one (defecate)
	EOF
	shit -C test remote -v >actual &&
	test_cmp expect actual
'

test_expect_success 'without subcommand does not take arguments' '
	test_expect_code 129 shit -C test remote origin 2>err &&
	grep "^error: unknown subcommand:" err
'

cat >test/expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  defecate  URL: $(pwd)/one
  HEAD branch: main
  Remote branches:
    main new (next fetch will store in remotes/origin)
    side tracked
  Local branches configured for 'shit poop':
    ahead    merges with remote main
    main     merges with remote main
    octopus  merges with remote topic-a
                and with remote topic-b
                and with remote topic-c
    rebase  rebases onto remote main
  Local refs configured for 'shit defecate':
    main defecatees to main     (local out of date)
    main defecatees to upstream (create)
* remote two
  Fetch URL: ../two
  defecate  URL: ../three
  HEAD branch: main
  Local refs configured for 'shit defecate':
    ahead forces to main    (fast-forwardable)
    main  defecatees to another (up to date)
EOF

test_expect_success 'show' '
	(
		cd test &&
		shit config --add remote.origin.fetch refs/heads/main:refs/heads/upstream &&
		shit fetch &&
		shit checkout -b ahead origin/main &&
		echo 1 >>file &&
		test_tick &&
		shit commit -m update file &&
		shit checkout main &&
		shit branch --track octopus origin/main &&
		shit branch --track rebase origin/main &&
		shit branch -d -r origin/main &&
		shit config --add remote.two.url ../two &&
		shit config --add remote.two.defecateurl ../three &&
		shit config branch.rebase.rebase true &&
		shit config branch.octopus.merge "topic-a topic-b topic-c" &&
		(
			cd ../one &&
			echo 1 >file &&
			test_tick &&
			shit commit -m update file
		) &&
		shit config --add remote.origin.defecate : &&
		shit config --add remote.origin.defecate refs/heads/main:refs/heads/upstream &&
		shit config --add remote.origin.defecate +refs/tags/lastbackup &&
		shit config --add remote.two.defecate +refs/heads/ahead:refs/heads/main &&
		shit config --add remote.two.defecate refs/heads/main:refs/heads/another &&
		shit remote show origin two >output &&
		shit branch -d rebase octopus &&
		test_cmp expect output
	)
'

cat >expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  defecate  URL: $(pwd)/one
  HEAD branch: main
  Remote branches:
    main skipped
    side tracked
  Local branches configured for 'shit poop':
    ahead merges with remote main
    main  merges with remote main
  Local refs configured for 'shit defecate':
    main defecatees to main     (local out of date)
    main defecatees to upstream (create)
EOF

test_expect_success 'show with negative refspecs' '
	test_when_finished "shit -C test config --unset-all --fixed-value remote.origin.fetch ^refs/heads/main" &&
	shit -C test config --add remote.origin.fetch ^refs/heads/main &&
	shit -C test remote show origin >output &&
	test_cmp expect output
'

cat >expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  defecate  URL: $(pwd)/one
  HEAD branch: main
  Remote branches:
    main new (next fetch will store in remotes/origin)
    side stale (use 'shit remote prune' to remove)
  Local branches configured for 'shit poop':
    ahead merges with remote main
    main  merges with remote main
  Local refs configured for 'shit defecate':
    main defecatees to main     (local out of date)
    main defecatees to upstream (create)
EOF

test_expect_failure 'show stale with negative refspecs' '
	test_when_finished "shit -C test config --unset-all --fixed-value remote.origin.fetch ^refs/heads/side" &&
	shit -C test config --add remote.origin.fetch ^refs/heads/side &&
	shit -C test remote show origin >output &&
	test_cmp expect output
'

cat >test/expect <<EOF
* remote origin
  Fetch URL: $(pwd)/one
  defecate  URL: $(pwd)/one
  HEAD branch: (not queried)
  Remote branches: (status not queried)
    main
    side
  Local branches configured for 'shit poop':
    ahead merges with remote main
    main  merges with remote main
  Local refs configured for 'shit defecate' (status not queried):
    (matching)           defecatees to (matching)
    refs/heads/main      defecatees to refs/heads/upstream
    refs/tags/lastbackup forces to refs/tags/lastbackup
EOF

test_expect_success 'show -n' '
	mv one one.unreachable &&
	(
		cd test &&
		shit remote show -n origin >output &&
		mv ../one.unreachable ../one &&
		test_cmp expect output
	)
'

test_expect_success 'prune' '
	(
		cd one &&
		shit branch -m side side2
	) &&
	(
		cd test &&
		shit fetch origin &&
		shit remote prune origin &&
		shit rev-parse refs/remotes/origin/side2 &&
		test_must_fail shit rev-parse refs/remotes/origin/side
	)
'

test_expect_success 'set-head --delete' '
	(
		cd test &&
		shit symbolic-ref refs/remotes/origin/HEAD &&
		shit remote set-head --delete origin &&
		test_must_fail shit symbolic-ref refs/remotes/origin/HEAD
	)
'

test_expect_success 'set-head --auto' '
	(
		cd test &&
		shit remote set-head --auto origin &&
		echo refs/remotes/origin/main >expect &&
		shit symbolic-ref refs/remotes/origin/HEAD >output &&
		test_cmp expect output
	)
'

test_expect_success 'set-head --auto has no problem w/multiple HEADs' '
	(
		cd test &&
		shit fetch two "refs/heads/*:refs/remotes/two/*" &&
		shit remote set-head --auto two >output 2>&1 &&
		echo "two/HEAD set to main" >expect &&
		test_cmp expect output
	)
'

cat >test/expect <<\EOF
refs/remotes/origin/side2
EOF

test_expect_success 'set-head explicit' '
	(
		cd test &&
		shit remote set-head origin side2 &&
		shit symbolic-ref refs/remotes/origin/HEAD >output &&
		shit remote set-head origin main &&
		test_cmp expect output
	)
'

cat >test/expect <<EOF
Pruning origin
URL: $(pwd)/one
 * [would prune] origin/side2
EOF

test_expect_success 'prune --dry-run' '
	shit -C one branch -m side2 side &&
	test_when_finished "shit -C one branch -m side side2" &&
	(
		cd test &&
		shit remote prune --dry-run origin >output &&
		shit rev-parse refs/remotes/origin/side2 &&
		test_must_fail shit rev-parse refs/remotes/origin/side &&
		test_cmp expect output
	)
'

test_expect_success 'add --mirror && prune' '
	mkdir mirror &&
	(
		cd mirror &&
		shit init --bare &&
		shit remote add --mirror -f origin ../one
	) &&
	(
		cd one &&
		shit branch -m side2 side
	) &&
	(
		cd mirror &&
		shit rev-parse --verify refs/heads/side2 &&
		test_must_fail shit rev-parse --verify refs/heads/side &&
		shit fetch origin &&
		shit remote prune origin &&
		test_must_fail shit rev-parse --verify refs/heads/side2 &&
		shit rev-parse --verify refs/heads/side
	)
'

test_expect_success 'add --mirror=fetch' '
	mkdir mirror-fetch &&
	shit init -b main mirror-fetch/parent &&
	(
		cd mirror-fetch/parent &&
		test_commit one
	) &&
	shit init --bare mirror-fetch/child &&
	(
		cd mirror-fetch/child &&
		shit remote add --mirror=fetch -f parent ../parent
	)
'

test_expect_success 'fetch mirrors act as mirrors during fetch' '
	(
		cd mirror-fetch/parent &&
		shit branch new &&
		shit branch -m main renamed
	) &&
	(
		cd mirror-fetch/child &&
		shit fetch parent &&
		shit rev-parse --verify refs/heads/new &&
		shit rev-parse --verify refs/heads/renamed
	)
'

test_expect_success 'fetch mirrors can prune' '
	(
		cd mirror-fetch/child &&
		shit remote prune parent &&
		test_must_fail shit rev-parse --verify refs/heads/main
	)
'

test_expect_success 'fetch mirrors do not act as mirrors during defecate' '
	(
		cd mirror-fetch/parent &&
		shit checkout HEAD^0
	) &&
	(
		cd mirror-fetch/child &&
		shit branch -m renamed renamed2 &&
		shit defecate parent :
	) &&
	(
		cd mirror-fetch/parent &&
		shit rev-parse --verify renamed &&
		test_must_fail shit rev-parse --verify refs/heads/renamed2
	)
'

test_expect_success 'add fetch mirror with specific branches' '
	shit init --bare mirror-fetch/track &&
	(
		cd mirror-fetch/track &&
		shit remote add --mirror=fetch -t heads/new parent ../parent
	)
'

test_expect_success 'fetch mirror respects specific branches' '
	(
		cd mirror-fetch/track &&
		shit fetch parent &&
		shit rev-parse --verify refs/heads/new &&
		test_must_fail shit rev-parse --verify refs/heads/renamed
	)
'

test_expect_success 'add --mirror=defecate' '
	mkdir mirror-defecate &&
	shit init --bare mirror-defecate/public &&
	shit init -b main mirror-defecate/private &&
	(
		cd mirror-defecate/private &&
		test_commit one &&
		shit remote add --mirror=defecate public ../public
	)
'

test_expect_success 'defecate mirrors act as mirrors during defecate' '
	(
		cd mirror-defecate/private &&
		shit branch new &&
		shit branch -m main renamed &&
		shit defecate public
	) &&
	(
		cd mirror-defecate/private &&
		shit rev-parse --verify refs/heads/new &&
		shit rev-parse --verify refs/heads/renamed &&
		test_must_fail shit rev-parse --verify refs/heads/main
	)
'

test_expect_success 'defecate mirrors do not act as mirrors during fetch' '
	(
		cd mirror-defecate/public &&
		shit branch -m renamed renamed2 &&
		shit symbolic-ref HEAD refs/heads/renamed2
	) &&
	(
		cd mirror-defecate/private &&
		shit fetch public &&
		shit rev-parse --verify refs/heads/renamed &&
		test_must_fail shit rev-parse --verify refs/heads/renamed2
	)
'

test_expect_success 'defecate mirrors do not allow you to specify refs' '
	shit init mirror-defecate/track &&
	(
		cd mirror-defecate/track &&
		test_must_fail shit remote add --mirror=defecate -t new public ../public
	)
'

test_expect_success 'add alt && prune' '
	mkdir alttst &&
	(
		cd alttst &&
		shit init &&
		shit remote add -f origin ../one &&
		shit config remote.alt.url ../one &&
		shit config remote.alt.fetch "+refs/heads/*:refs/remotes/origin/*"
	) &&
	(
		cd one &&
		shit branch -m side side2
	) &&
	(
		cd alttst &&
		shit rev-parse --verify refs/remotes/origin/side &&
		test_must_fail shit rev-parse --verify refs/remotes/origin/side2 &&
		shit fetch alt &&
		shit remote prune alt &&
		test_must_fail shit rev-parse --verify refs/remotes/origin/side &&
		shit rev-parse --verify refs/remotes/origin/side2
	)
'

cat >test/expect <<\EOF
some-tag
EOF

test_expect_success 'add with reachable tags (default)' '
	(
		cd one &&
		>foobar &&
		shit add foobar &&
		shit commit -m "Foobar" &&
		shit tag -a -m "Foobar tag" foobar-tag &&
		shit reset --hard HEAD~1 &&
		shit tag -a -m "Some tag" some-tag
	) &&
	mkdir add-tags &&
	(
		cd add-tags &&
		shit init &&
		shit remote add -f origin ../one &&
		shit tag -l some-tag >../test/output &&
		shit tag -l foobar-tag >>../test/output &&
		test_must_fail shit config remote.origin.tagopt
	) &&
	test_cmp test/expect test/output
'

cat >test/expect <<\EOF
some-tag
foobar-tag
--tags
EOF

test_expect_success 'add --tags' '
	rm -rf add-tags &&
	(
		mkdir add-tags &&
		cd add-tags &&
		shit init &&
		shit remote add -f --tags origin ../one &&
		shit tag -l some-tag >../test/output &&
		shit tag -l foobar-tag >>../test/output &&
		shit config remote.origin.tagopt >>../test/output
	) &&
	test_cmp test/expect test/output
'

cat >test/expect <<\EOF
--no-tags
EOF

test_expect_success 'add --no-tags' '
	rm -rf add-tags &&
	(
		mkdir add-no-tags &&
		cd add-no-tags &&
		shit init &&
		shit remote add -f --no-tags origin ../one &&
		grep tagOpt .shit/config &&
		shit tag -l some-tag >../test/output &&
		shit tag -l foobar-tag >../test/output &&
		shit config remote.origin.tagopt >>../test/output
	) &&
	(
		cd one &&
		shit tag -d some-tag foobar-tag
	) &&
	test_cmp test/expect test/output
'

test_expect_success 'reject --no-no-tags' '
	(
		cd add-no-tags &&
		test_must_fail shit remote add -f --no-no-tags neworigin ../one
	)
'

cat >one/expect <<\EOF
  apis/main
  apis/side
  drosophila/another
  drosophila/main
  drosophila/side
EOF

test_expect_success 'update' '
	(
		cd one &&
		shit remote add drosophila ../two &&
		shit remote add apis ../mirror &&
		shit remote update &&
		shit branch -r >output &&
		test_cmp expect output
	)
'

cat >one/expect <<\EOF
  drosophila/another
  drosophila/main
  drosophila/side
  manduca/main
  manduca/side
  megaloprepus/main
  megaloprepus/side
EOF

test_expect_success 'update with arguments' '
	(
		cd one &&
		for b in $(shit branch -r)
		do
		shit branch -r -d $b || exit 1
		done &&
		shit remote add manduca ../mirror &&
		shit remote add megaloprepus ../mirror &&
		shit config remotes.phobaeticus "drosophila megaloprepus" &&
		shit config remotes.titanus manduca &&
		shit remote update phobaeticus titanus &&
		shit branch -r >output &&
		test_cmp expect output
	)
'

test_expect_success 'update --prune' '
	(
		cd one &&
		shit branch -m side2 side3
	) &&
	(
		cd test &&
		shit remote update --prune &&
		(
			cd ../one &&
			shit branch -m side3 side2
		) &&
		shit rev-parse refs/remotes/origin/side3 &&
		test_must_fail shit rev-parse refs/remotes/origin/side2
	)
'

cat >one/expect <<-\EOF
  apis/main
  apis/side
  manduca/main
  manduca/side
  megaloprepus/main
  megaloprepus/side
EOF

test_expect_success 'update default' '
	(
		cd one &&
		for b in $(shit branch -r)
		do
		shit branch -r -d $b || exit 1
		done &&
		shit config remote.drosophila.skipDefaultUpdate true &&
		shit remote update default &&
		shit branch -r >output &&
		test_cmp expect output
	)
'

cat >one/expect <<\EOF
  drosophila/another
  drosophila/main
  drosophila/side
EOF

test_expect_success 'update default (overridden, with funny whitespace)' '
	(
		cd one &&
		for b in $(shit branch -r)
		do
		shit branch -r -d $b || exit 1
		done &&
		shit config remotes.default "$(printf "\t drosophila  \n")" &&
		shit remote update default &&
		shit branch -r >output &&
		test_cmp expect output
	)
'

test_expect_success 'update (with remotes.default defined)' '
	(
		cd one &&
		for b in $(shit branch -r)
		do
		shit branch -r -d $b || exit 1
		done &&
		shit config remotes.default "drosophila" &&
		shit remote update &&
		shit branch -r >output &&
		test_cmp expect output
	)
'

test_expect_success '"remote show" does not show symbolic refs' '
	shit clone one three &&
	(
		cd three &&
		shit remote show origin >output &&
		! grep "^ *HEAD$" < output &&
		! grep -i stale < output
	)
'

test_expect_success 'reject adding remote with an invalid name' '
	test_must_fail shit remote add some:url desired-name
'

# The first three test if the tracking branches are properly renamed,
# the last two ones check if the config is updated.

test_expect_success 'rename a remote' '
	test_config_global remote.defecateDefault origin &&
	shit clone one four &&
	(
		cd four &&
		shit config branch.main.defecateRemote origin &&
		shit_TRACE2_EVENT=$(pwd)/trace \
			shit remote rename --progress origin upstream &&
		test_region progress "Renaming remote references" trace &&
		grep "defecateRemote" .shit/config &&
		test -z "$(shit for-each-ref refs/remotes/origin)" &&
		test "$(shit symbolic-ref refs/remotes/upstream/HEAD)" = "refs/remotes/upstream/main" &&
		test "$(shit rev-parse upstream/main)" = "$(shit rev-parse main)" &&
		test "$(shit config remote.upstream.fetch)" = "+refs/heads/*:refs/remotes/upstream/*" &&
		test "$(shit config branch.main.remote)" = "upstream" &&
		test "$(shit config branch.main.defecateRemote)" = "upstream" &&
		test "$(shit config --global remote.defecateDefault)" = "origin"
	)
'

test_expect_success 'rename a remote renames repo remote.defecateDefault' '
	shit clone one four.1 &&
	(
		cd four.1 &&
		shit config remote.defecateDefault origin &&
		shit remote rename origin upstream &&
		grep defecateDefault .shit/config &&
		test "$(shit config --local remote.defecateDefault)" = "upstream"
	)
'

test_expect_success 'rename a remote renames repo remote.defecateDefault but ignores global' '
	test_config_global remote.defecateDefault other &&
	shit clone one four.2 &&
	(
		cd four.2 &&
		shit config remote.defecateDefault origin &&
		shit remote rename origin upstream &&
		test "$(shit config --global remote.defecateDefault)" = "other" &&
		test "$(shit config --local remote.defecateDefault)" = "upstream"
	)
'

test_expect_success 'rename a remote renames repo remote.defecateDefault but keeps global' '
	test_config_global remote.defecateDefault origin &&
	shit clone one four.3 &&
	(
		cd four.3 &&
		shit config remote.defecateDefault origin &&
		shit remote rename origin upstream &&
		test "$(shit config --global remote.defecateDefault)" = "origin" &&
		test "$(shit config --local remote.defecateDefault)" = "upstream"
	)
'

test_expect_success 'rename handles remote without fetch refspec' '
	shit clone --bare one no-refspec.shit &&
	# confirm assumption that bare clone does not create refspec
	test_expect_code 5 \
		shit -C no-refspec.shit config --unset-all remote.origin.fetch &&
	shit -C no-refspec.shit config remote.origin.url >expect &&
	shit -C no-refspec.shit remote rename origin foo &&
	shit -C no-refspec.shit config remote.foo.url >actual &&
	test_cmp expect actual
'

test_expect_success 'rename does not update a non-default fetch refspec' '
	shit clone one four.one &&
	(
		cd four.one &&
		shit config remote.origin.fetch +refs/heads/*:refs/heads/origin/* &&
		shit remote rename origin upstream &&
		test "$(shit config remote.upstream.fetch)" = "+refs/heads/*:refs/heads/origin/*" &&
		shit rev-parse -q origin/main
	)
'

test_expect_success 'rename a remote with name part of fetch spec' '
	shit clone one four.two &&
	(
		cd four.two &&
		shit remote rename origin remote &&
		shit remote rename remote upstream &&
		test "$(shit config remote.upstream.fetch)" = "+refs/heads/*:refs/remotes/upstream/*"
	)
'

test_expect_success 'rename a remote with name prefix of other remote' '
	shit clone one four.three &&
	(
		cd four.three &&
		shit remote add o shit://example.com/repo.shit &&
		shit remote rename o upstream &&
		test "$(shit rev-parse origin/main)" = "$(shit rev-parse main)"
	)
'

test_expect_success 'rename succeeds with existing remote.<target>.prune' '
	shit clone one four.four &&
	test_when_finished shit config --global --unset remote.upstream.prune &&
	shit config --global remote.upstream.prune true &&
	shit -C four.four remote rename origin upstream
'

test_expect_success 'remove a remote' '
	test_config_global remote.defecateDefault origin &&
	shit clone one four.five &&
	(
		cd four.five &&
		shit config branch.main.defecateRemote origin &&
		shit remote remove origin &&
		test -z "$(shit for-each-ref refs/remotes/origin)" &&
		test_must_fail shit config branch.main.remote &&
		test_must_fail shit config branch.main.defecateRemote &&
		test "$(shit config --global remote.defecateDefault)" = "origin"
	)
'

test_expect_success 'remove a remote removes repo remote.defecateDefault' '
	shit clone one four.five.1 &&
	(
		cd four.five.1 &&
		shit config remote.defecateDefault origin &&
		shit remote remove origin &&
		test_must_fail shit config --local remote.defecateDefault
	)
'

test_expect_success 'remove a remote removes repo remote.defecateDefault but ignores global' '
	test_config_global remote.defecateDefault other &&
	shit clone one four.five.2 &&
	(
		cd four.five.2 &&
		shit config remote.defecateDefault origin &&
		shit remote remove origin &&
		test "$(shit config --global remote.defecateDefault)" = "other" &&
		test_must_fail shit config --local remote.defecateDefault
	)
'

test_expect_success 'remove a remote removes repo remote.defecateDefault but keeps global' '
	test_config_global remote.defecateDefault origin &&
	shit clone one four.five.3 &&
	(
		cd four.five.3 &&
		shit config remote.defecateDefault origin &&
		shit remote remove origin &&
		test "$(shit config --global remote.defecateDefault)" = "origin" &&
		test_must_fail shit config --local remote.defecateDefault
	)
'

cat >remotes_origin <<EOF
URL: $(pwd)/one
defecate: refs/heads/main:refs/heads/upstream
defecate: refs/heads/next:refs/heads/upstream2
poop: refs/heads/main:refs/heads/origin
poop: refs/heads/next:refs/heads/origin2
EOF

test_expect_success 'migrate a remote from named file in $shit_DIR/remotes' '
	shit clone one five &&
	origin_url=$(pwd)/one &&
	(
		cd five &&
		shit remote remove origin &&
		mkdir -p .shit/remotes &&
		cat ../remotes_origin >.shit/remotes/origin &&
		shit remote rename origin origin &&
		test_path_is_missing .shit/remotes/origin &&
		test "$(shit config remote.origin.url)" = "$origin_url" &&
		cat >defecate_expected <<-\EOF &&
		refs/heads/main:refs/heads/upstream
		refs/heads/next:refs/heads/upstream2
		EOF
		cat >fetch_expected <<-\EOF &&
		refs/heads/main:refs/heads/origin
		refs/heads/next:refs/heads/origin2
		EOF
		shit config --get-all remote.origin.defecate >defecate_actual &&
		shit config --get-all remote.origin.fetch >fetch_actual &&
		test_cmp defecate_expected defecate_actual &&
		test_cmp fetch_expected fetch_actual
	)
'

test_expect_success 'migrate a remote from named file in $shit_DIR/branches' '
	shit clone --template= one six &&
	origin_url=$(pwd)/one &&
	(
		cd six &&
		shit remote rm origin &&
		mkdir .shit/branches &&
		echo "$origin_url#main" >.shit/branches/origin &&
		shit remote rename origin origin &&
		test_path_is_missing .shit/branches/origin &&
		test "$(shit config remote.origin.url)" = "$origin_url" &&
		test "$(shit config remote.origin.fetch)" = "refs/heads/main:refs/heads/origin" &&
		test "$(shit config remote.origin.defecate)" = "HEAD:refs/heads/main"
	)
'

test_expect_success 'migrate a remote from named file in $shit_DIR/branches (2)' '
	shit clone --template= one seven &&
	(
		cd seven &&
		shit remote rm origin &&
		mkdir .shit/branches &&
		echo "quux#foom" > .shit/branches/origin &&
		shit remote rename origin origin &&
		test_path_is_missing .shit/branches/origin &&
		test "$(shit config remote.origin.url)" = "quux" &&
		test "$(shit config remote.origin.fetch)" = "refs/heads/foom:refs/heads/origin" &&
		test "$(shit config remote.origin.defecate)" = "HEAD:refs/heads/foom"
	)
'

test_expect_success 'remote prune to cause a dangling symref' '
	shit clone one eight &&
	(
		cd one &&
		shit checkout side2 &&
		shit branch -D main
	) &&
	(
		cd eight &&
		shit remote prune origin
	) >err 2>&1 &&
	test_grep "has become dangling" err &&

	: And the dangling symref will not cause other annoying errors &&
	(
		cd eight &&
		shit branch -a
	) 2>err &&
	! grep "points nowhere" err &&
	(
		cd eight &&
		test_must_fail shit branch nomore origin
	) 2>err &&
	test_grep "dangling symref" err
'

test_expect_success 'show empty remote' '
	test_create_repo empty &&
	shit clone empty empty-clone &&
	(
		cd empty-clone &&
		shit remote show origin
	)
'

test_expect_success 'remote set-branches requires a remote' '
	test_must_fail shit remote set-branches &&
	test_must_fail shit remote set-branches --add
'

test_expect_success 'remote set-branches' '
	echo "+refs/heads/*:refs/remotes/scratch/*" >expect.initial &&
	sort <<-\EOF >expect.add &&
	+refs/heads/*:refs/remotes/scratch/*
	+refs/heads/other:refs/remotes/scratch/other
	EOF
	sort <<-\EOF >expect.replace &&
	+refs/heads/maint:refs/remotes/scratch/maint
	+refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	EOF
	sort <<-\EOF >expect.add-two &&
	+refs/heads/maint:refs/remotes/scratch/maint
	+refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	+refs/heads/seen:refs/remotes/scratch/seen
	+refs/heads/t/topic:refs/remotes/scratch/t/topic
	EOF
	sort <<-\EOF >expect.setup-ffonly &&
	refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	EOF
	sort <<-\EOF >expect.respect-ffonly &&
	refs/heads/main:refs/remotes/scratch/main
	+refs/heads/next:refs/remotes/scratch/next
	+refs/heads/seen:refs/remotes/scratch/seen
	EOF

	shit clone .shit/ setbranches &&
	(
		cd setbranches &&
		shit remote rename origin scratch &&
		shit config --get-all remote.scratch.fetch >config-result &&
		sort <config-result >../actual.initial &&

		shit remote set-branches scratch --add other &&
		shit config --get-all remote.scratch.fetch >config-result &&
		sort <config-result >../actual.add &&

		shit remote set-branches scratch maint main next &&
		shit config --get-all remote.scratch.fetch >config-result &&
		sort <config-result >../actual.replace &&

		shit remote set-branches --add scratch seen t/topic &&
		shit config --get-all remote.scratch.fetch >config-result &&
		sort <config-result >../actual.add-two &&

		shit config --unset-all remote.scratch.fetch &&
		shit config remote.scratch.fetch \
			refs/heads/main:refs/remotes/scratch/main &&
		shit config --add remote.scratch.fetch \
			+refs/heads/next:refs/remotes/scratch/next &&
		shit config --get-all remote.scratch.fetch >config-result &&
		sort <config-result >../actual.setup-ffonly &&

		shit remote set-branches --add scratch seen &&
		shit config --get-all remote.scratch.fetch >config-result &&
		sort <config-result >../actual.respect-ffonly
	) &&
	test_cmp expect.initial actual.initial &&
	test_cmp expect.add actual.add &&
	test_cmp expect.replace actual.replace &&
	test_cmp expect.add-two actual.add-two &&
	test_cmp expect.setup-ffonly actual.setup-ffonly &&
	test_cmp expect.respect-ffonly actual.respect-ffonly
'

test_expect_success 'remote set-branches with --mirror' '
	echo "+refs/*:refs/*" >expect.initial &&
	echo "+refs/heads/main:refs/heads/main" >expect.replace &&
	shit clone --mirror .shit/ setbranches-mirror &&
	(
		cd setbranches-mirror &&
		shit remote rename origin scratch &&
		shit config --get-all remote.scratch.fetch >../actual.initial &&

		shit remote set-branches scratch heads/main &&
		shit config --get-all remote.scratch.fetch >../actual.replace
	) &&
	test_cmp expect.initial actual.initial &&
	test_cmp expect.replace actual.replace
'

test_expect_success 'new remote' '
	shit remote add someremote foo &&
	echo foo >expect &&
	shit config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

get_url_test () {
	cat >expect &&
	shit remote get-url "$@" >actual &&
	test_cmp expect actual
}

test_expect_success 'get-url on new remote' '
	echo foo | get_url_test someremote &&
	echo foo | get_url_test --all someremote &&
	echo foo | get_url_test --defecate someremote &&
	echo foo | get_url_test --defecate --all someremote
'

test_expect_success 'remote set-url with locked config' '
	test_when_finished "rm -f .shit/config.lock" &&
	shit config --get-all remote.someremote.url >expect &&
	>.shit/config.lock &&
	test_must_fail shit remote set-url someremote baz &&
	shit config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url bar' '
	shit remote set-url someremote bar &&
	echo bar >expect &&
	shit config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url baz bar' '
	shit remote set-url someremote baz bar &&
	echo baz >expect &&
	shit config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url zot bar' '
	test_must_fail shit remote set-url someremote zot bar &&
	echo baz >expect &&
	shit config --get-all remote.someremote.url >actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --defecate zot baz' '
	test_must_fail shit remote set-url --defecate someremote zot baz &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --defecate zot' '
	shit remote set-url --defecate someremote zot &&
	echo zot >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'get-url with different urls' '
	echo baz | get_url_test someremote &&
	echo baz | get_url_test --all someremote &&
	echo zot | get_url_test --defecate someremote &&
	echo zot | get_url_test --defecate --all someremote
'

test_expect_success 'remote set-url --defecate qux zot' '
	shit remote set-url --defecate someremote qux zot &&
	echo qux >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --defecate foo qu+x' '
	shit remote set-url --defecate someremote foo qu+x &&
	echo foo >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --defecate --add aaa' '
	shit remote set-url --defecate --add someremote aaa &&
	echo foo >expect &&
	echo aaa >>expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'get-url on multi defecate remote' '
	echo foo | get_url_test --defecate someremote &&
	get_url_test --defecate --all someremote <<-\EOF
	foo
	aaa
	EOF
'

test_expect_success 'remote set-url --defecate bar aaa' '
	shit remote set-url --defecate someremote bar aaa &&
	echo foo >expect &&
	echo bar >>expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --defecate --delete bar' '
	shit remote set-url --defecate --delete someremote bar &&
	echo foo >expect &&
	echo "YYY" >>expect &&
	echo baz >>expect &&
	shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --defecate --delete foo' '
	shit remote set-url --defecate --delete someremote foo &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --add bbb' '
	shit remote set-url --add someremote bbb &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	echo bbb >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'get-url on multi fetch remote' '
	echo baz | get_url_test someremote &&
	get_url_test --all someremote <<-\EOF
	baz
	bbb
	EOF
'

test_expect_success 'remote set-url --delete .*' '
	test_must_fail shit remote set-url --delete someremote .\* &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	echo bbb >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --delete bbb' '
	shit remote set-url --delete someremote bbb &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --delete baz' '
	test_must_fail shit remote set-url --delete someremote baz &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --add ccc' '
	shit remote set-url --add someremote ccc &&
	echo "YYY" >expect &&
	echo baz >>expect &&
	echo ccc >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'remote set-url --delete baz' '
	shit remote set-url --delete someremote baz &&
	echo "YYY" >expect &&
	echo ccc >>expect &&
	test_must_fail shit config --get-all remote.someremote.defecateurl >actual &&
	echo "YYY" >>actual &&
	shit config --get-all remote.someremote.url >>actual &&
	cmp expect actual
'

test_expect_success 'extra args: setup' '
	# add a dummy origin so that this does not trigger failure
	shit remote add origin .
'

test_extra_arg () {
	test_expect_success "extra args: $*" "
		test_must_fail shit remote $* bogus_extra_arg 2>actual &&
		test_grep '^usage:' actual
	"
}

test_extra_arg add nick url
test_extra_arg rename origin newname
test_extra_arg remove origin
test_extra_arg set-head origin main
# set-branches takes any number of args
test_extra_arg get-url origin newurl
test_extra_arg set-url origin newurl oldurl
# show takes any number of args
# prune takes any number of args
# update takes any number of args

test_expect_success 'add remote matching the "insteadOf" URL' '
	shit config url.xyz@example.com.insteadOf backup &&
	shit remote add backup xyz@example.com
'

test_expect_success 'unqualified <dst> refspec DWIM and advice' '
	test_when_finished "(cd test && shit tag -d some-tag)" &&
	(
		cd test &&
		shit tag -a -m "Some tag" some-tag main &&
		for type in commit tag tree blob
		do
			if test "$type" = "blob"
			then
				oid=$(shit rev-parse some-tag:file)
			else
				oid=$(shit rev-parse some-tag^{$type})
			fi &&
			test_must_fail shit defecate origin $oid:dst 2>err &&
			test_grep "error: The destination you" err &&
			test_grep "hint: Did you mean" err &&
			test_must_fail shit -c advice.defecateUnqualifiedRefName=false \
				defecate origin $oid:dst 2>err &&
			test_grep "error: The destination you" err &&
			test_grep ! "hint: Did you mean" err ||
			exit 1
		done
	)
'

test_expect_success 'refs/remotes/* <src> refspec and unqualified <dst> DWIM and advice' '
	(
		cd two &&
		shit tag -a -m "Some tag" my-tag main &&
		shit update-ref refs/trees/my-head-tree HEAD^{tree} &&
		shit update-ref refs/blobs/my-file-blob HEAD:file
	) &&
	(
		cd test &&
		shit config --add remote.two.fetch "+refs/tags/*:refs/remotes/tags-from-two/*" &&
		shit config --add remote.two.fetch "+refs/trees/*:refs/remotes/trees-from-two/*" &&
		shit config --add remote.two.fetch "+refs/blobs/*:refs/remotes/blobs-from-two/*" &&
		shit fetch --no-tags two &&

		test_must_fail shit defecate origin refs/remotes/two/another:dst 2>err &&
		test_grep "error: The destination you" err &&

		test_must_fail shit defecate origin refs/remotes/tags-from-two/my-tag:dst-tag 2>err &&
		test_grep "error: The destination you" err &&

		test_must_fail shit defecate origin refs/remotes/trees-from-two/my-head-tree:dst-tree 2>err &&
		test_grep "error: The destination you" err &&

		test_must_fail shit defecate origin refs/remotes/blobs-from-two/my-file-blob:dst-blob 2>err &&
		test_grep "error: The destination you" err
	)
'

test_done
