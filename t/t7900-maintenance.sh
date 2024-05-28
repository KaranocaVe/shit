#!/bin/sh

test_description='shit maintenance builtin'

. ./test-lib.sh

shit_TEST_COMMIT_GRAPH=0
shit_TEST_MULTI_PACK_INDEX=0

test_lazy_prereq XMLLINT '
	xmllint --version
'

test_xmllint () {
	if test_have_prereq XMLLINT
	then
		xmllint --noout "$@"
	else
		true
	fi
}

test_lazy_prereq SYSTEMD_ANALYZE '
	systemd-analyze verify /lib/systemd/system/basic.target
'

test_systemd_analyze_verify () {
	if test_have_prereq SYSTEMD_ANALYZE
	then
		systemd-analyze verify "$@"
	fi
}

test_expect_success 'help text' '
	test_expect_code 129 shit maintenance -h >actual &&
	test_grep "usage: shit maintenance <subcommand>" actual &&
	test_expect_code 129 shit maintenance barf 2>err &&
	test_grep "unknown subcommand: \`barf'\''" err &&
	test_grep "usage: shit maintenance" err &&
	test_expect_code 129 shit maintenance 2>err &&
	test_grep "error: need a subcommand" err &&
	test_grep "usage: shit maintenance" err
'

test_expect_success 'run [--auto|--quiet]' '
	shit_TRACE2_EVENT="$(pwd)/run-no-auto.txt" \
		shit maintenance run 2>/dev/null &&
	shit_TRACE2_EVENT="$(pwd)/run-auto.txt" \
		shit maintenance run --auto 2>/dev/null &&
	shit_TRACE2_EVENT="$(pwd)/run-no-quiet.txt" \
		shit maintenance run --no-quiet 2>/dev/null &&
	test_subcommand shit gc --quiet <run-no-auto.txt &&
	test_subcommand ! shit gc --auto --quiet <run-auto.txt &&
	test_subcommand shit gc --no-quiet <run-no-quiet.txt
'

test_expect_success 'maintenance.auto config option' '
	shit_TRACE2_EVENT="$(pwd)/default" shit commit --quiet --allow-empty -m 1 &&
	test_subcommand shit maintenance run --auto --quiet <default &&
	shit_TRACE2_EVENT="$(pwd)/true" \
		shit -c maintenance.auto=true \
		commit --quiet --allow-empty -m 2 &&
	test_subcommand shit maintenance run --auto --quiet  <true &&
	shit_TRACE2_EVENT="$(pwd)/false" \
		shit -c maintenance.auto=false \
		commit --quiet --allow-empty -m 3 &&
	test_subcommand ! shit maintenance run --auto --quiet  <false
'

test_expect_success 'register uses XDG_CONFIG_HOME config if it exists' '
	test_when_finished rm -r .config/shit/config &&
	(
		XDG_CONFIG_HOME=.config &&
		export XDG_CONFIG_HOME &&
		mkdir -p $XDG_CONFIG_HOME/shit &&
		>$XDG_CONFIG_HOME/shit/config &&
		shit maintenance register &&
		shit config --file=$XDG_CONFIG_HOME/shit/config --get maintenance.repo >actual &&
		pwd >expect &&
		test_cmp expect actual
	)
'

test_expect_success 'register does not need XDG_CONFIG_HOME config to exist' '
	test_when_finished shit maintenance unregister &&
	test_path_is_missing $XDG_CONFIG_HOME/shit/config &&
	shit maintenance register &&
	shit config --global --get maintenance.repo >actual &&
	pwd >expect &&
	test_cmp expect actual
'

test_expect_success 'unregister uses XDG_CONFIG_HOME config if it exists' '
	test_when_finished rm -r .config/shit/config &&
	(
		XDG_CONFIG_HOME=.config &&
		export XDG_CONFIG_HOME &&
		mkdir -p $XDG_CONFIG_HOME/shit &&
		>$XDG_CONFIG_HOME/shit/config &&
		shit maintenance register &&
		shit maintenance unregister &&
		test_must_fail shit config --file=$XDG_CONFIG_HOME/shit/config --get maintenance.repo >actual &&
		test_must_be_empty actual
	)
'

test_expect_success 'unregister does not need XDG_CONFIG_HOME config to exist' '
	test_path_is_missing $XDG_CONFIG_HOME/shit/config &&
	shit maintenance register &&
	shit maintenance unregister &&
	test_must_fail shit config --global --get maintenance.repo >actual &&
	test_must_be_empty actual
'

test_expect_success 'maintenance.<task>.enabled' '
	shit config maintenance.gc.enabled false &&
	shit config maintenance.commit-graph.enabled true &&
	shit_TRACE2_EVENT="$(pwd)/run-config.txt" shit maintenance run 2>err &&
	test_subcommand ! shit gc --quiet <run-config.txt &&
	test_subcommand shit commit-graph write --split --reachable --no-progress <run-config.txt
'

test_expect_success 'run --task=<task>' '
	shit_TRACE2_EVENT="$(pwd)/run-commit-graph.txt" \
		shit maintenance run --task=commit-graph 2>/dev/null &&
	shit_TRACE2_EVENT="$(pwd)/run-gc.txt" \
		shit maintenance run --task=gc 2>/dev/null &&
	shit_TRACE2_EVENT="$(pwd)/run-commit-graph.txt" \
		shit maintenance run --task=commit-graph 2>/dev/null &&
	shit_TRACE2_EVENT="$(pwd)/run-both.txt" \
		shit maintenance run --task=commit-graph --task=gc 2>/dev/null &&
	test_subcommand ! shit gc --quiet <run-commit-graph.txt &&
	test_subcommand shit gc --quiet <run-gc.txt &&
	test_subcommand shit gc --quiet <run-both.txt &&
	test_subcommand shit commit-graph write --split --reachable --no-progress <run-commit-graph.txt &&
	test_subcommand ! shit commit-graph write --split --reachable --no-progress <run-gc.txt &&
	test_subcommand shit commit-graph write --split --reachable --no-progress <run-both.txt
'

test_expect_success 'core.commitGraph=false prevents write process' '
	shit_TRACE2_EVENT="$(pwd)/no-commit-graph.txt" \
		shit -c core.commitGraph=false maintenance run \
		--task=commit-graph 2>/dev/null &&
	test_subcommand ! shit commit-graph write --split --reachable --no-progress \
		<no-commit-graph.txt
'

test_expect_success 'commit-graph auto condition' '
	COMMAND="maintenance run --task=commit-graph --auto --quiet" &&

	shit_TRACE2_EVENT="$(pwd)/cg-no.txt" \
		shit -c maintenance.commit-graph.auto=1 $COMMAND &&
	shit_TRACE2_EVENT="$(pwd)/cg-negative-means-yes.txt" \
		shit -c maintenance.commit-graph.auto="-1" $COMMAND &&

	test_commit first &&

	shit_TRACE2_EVENT="$(pwd)/cg-zero-means-no.txt" \
		shit -c maintenance.commit-graph.auto=0 $COMMAND &&
	shit_TRACE2_EVENT="$(pwd)/cg-one-satisfied.txt" \
		shit -c maintenance.commit-graph.auto=1 $COMMAND &&

	shit commit --allow-empty -m "second" &&
	shit commit --allow-empty -m "third" &&

	shit_TRACE2_EVENT="$(pwd)/cg-two-satisfied.txt" \
		shit -c maintenance.commit-graph.auto=2 $COMMAND &&

	COMMIT_GRAPH_WRITE="shit commit-graph write --split --reachable --no-progress" &&
	test_subcommand ! $COMMIT_GRAPH_WRITE <cg-no.txt &&
	test_subcommand $COMMIT_GRAPH_WRITE <cg-negative-means-yes.txt &&
	test_subcommand ! $COMMIT_GRAPH_WRITE <cg-zero-means-no.txt &&
	test_subcommand $COMMIT_GRAPH_WRITE <cg-one-satisfied.txt &&
	test_subcommand $COMMIT_GRAPH_WRITE <cg-two-satisfied.txt
'

test_expect_success 'run --task=bogus' '
	test_must_fail shit maintenance run --task=bogus 2>err &&
	test_grep "is not a valid task" err
'

test_expect_success 'run --task duplicate' '
	test_must_fail shit maintenance run --task=gc --task=gc 2>err &&
	test_grep "cannot be selected multiple times" err
'

test_expect_success 'run --task=prefetch with no remotes' '
	shit maintenance run --task=prefetch 2>err &&
	test_must_be_empty err
'

test_expect_success 'prefetch multiple remotes' '
	shit clone . clone1 &&
	shit clone . clone2 &&
	shit remote add remote1 "file://$(pwd)/clone1" &&
	shit remote add remote2 "file://$(pwd)/clone2" &&
	shit -C clone1 switch -c one &&
	shit -C clone2 switch -c two &&
	test_commit -C clone1 one &&
	test_commit -C clone2 two &&
	shit_TRACE2_EVENT="$(pwd)/run-prefetch.txt" shit maintenance run --task=prefetch 2>/dev/null &&
	fetchargs="--prefetch --prune --no-tags --no-write-fetch-head --recurse-submodules=no --quiet" &&
	test_subcommand shit fetch remote1 $fetchargs <run-prefetch.txt &&
	test_subcommand shit fetch remote2 $fetchargs <run-prefetch.txt &&
	shit for-each-ref refs/remotes >actual &&
	test_must_be_empty actual &&
	shit log prefetch/remotes/remote1/one &&
	shit log prefetch/remotes/remote2/two &&
	shit fetch --all &&
	test_cmp_rev refs/remotes/remote1/one refs/prefetch/remotes/remote1/one &&
	test_cmp_rev refs/remotes/remote2/two refs/prefetch/remotes/remote2/two &&

	shit log --oneline --decorate --all >log &&
	! grep "prefetch" log &&

	test_when_finished shit config --unset remote.remote1.skipFetchAll &&
	shit config remote.remote1.skipFetchAll true &&
	shit_TRACE2_EVENT="$(pwd)/skip-remote1.txt" shit maintenance run --task=prefetch 2>/dev/null &&
	test_subcommand ! shit fetch remote1 $fetchargs <skip-remote1.txt &&
	test_subcommand shit fetch remote2 $fetchargs <skip-remote1.txt
'

test_expect_success 'loose-objects task' '
	# Repack everything so we know the state of the object dir
	shit repack -adk &&

	# Hack to stop maintenance from running during "shit commit"
	echo in use >.shit/objects/maintenance.lock &&

	# Assuming that "shit commit" creates at least one loose object
	test_commit create-loose-object &&
	rm .shit/objects/maintenance.lock &&

	ls .shit/objects >obj-dir-before &&
	test_file_not_empty obj-dir-before &&
	ls .shit/objects/pack/*.pack >packs-before &&
	test_line_count = 1 packs-before &&

	# The first run creates a pack-file
	# but does not delete loose objects.
	shit maintenance run --task=loose-objects &&
	ls .shit/objects >obj-dir-between &&
	test_cmp obj-dir-before obj-dir-between &&
	ls .shit/objects/pack/*.pack >packs-between &&
	test_line_count = 2 packs-between &&
	ls .shit/objects/pack/loose-*.pack >loose-packs &&
	test_line_count = 1 loose-packs &&

	# The second run deletes loose objects
	# but does not create a pack-file.
	shit maintenance run --task=loose-objects &&
	ls .shit/objects >obj-dir-after &&
	cat >expect <<-\EOF &&
	info
	pack
	EOF
	test_cmp expect obj-dir-after &&
	ls .shit/objects/pack/*.pack >packs-after &&
	test_cmp packs-between packs-after
'

test_expect_success 'maintenance.loose-objects.auto' '
	shit repack -adk &&
	shit_TRACE2_EVENT="$(pwd)/trace-lo1.txt" \
		shit -c maintenance.loose-objects.auto=1 maintenance \
		run --auto --task=loose-objects 2>/dev/null &&
	test_subcommand ! shit prune-packed --quiet <trace-lo1.txt &&
	printf data-A | shit hash-object -t blob --stdin -w &&
	shit_TRACE2_EVENT="$(pwd)/trace-loA" \
		shit -c maintenance.loose-objects.auto=2 \
		maintenance run --auto --task=loose-objects 2>/dev/null &&
	test_subcommand ! shit prune-packed --quiet <trace-loA &&
	printf data-B | shit hash-object -t blob --stdin -w &&
	shit_TRACE2_EVENT="$(pwd)/trace-loB" \
		shit -c maintenance.loose-objects.auto=2 \
		maintenance run --auto --task=loose-objects 2>/dev/null &&
	test_subcommand shit prune-packed --quiet <trace-loB &&
	shit_TRACE2_EVENT="$(pwd)/trace-loC" \
		shit -c maintenance.loose-objects.auto=2 \
		maintenance run --auto --task=loose-objects 2>/dev/null &&
	test_subcommand shit prune-packed --quiet <trace-loC
'

test_expect_success 'incremental-repack task' '
	packDir=.shit/objects/pack &&
	for i in $(test_seq 1 5)
	do
		test_commit $i || return 1
	done &&

	# Create three disjoint pack-files with size BIG, small, small.
	echo HEAD~2 | shit pack-objects --revs $packDir/test-1 &&
	test_tick &&
	shit pack-objects --revs $packDir/test-2 <<-\EOF &&
	HEAD~1
	^HEAD~2
	EOF
	test_tick &&
	shit pack-objects --revs $packDir/test-3 <<-\EOF &&
	HEAD
	^HEAD~1
	EOF

	# Delete refs that have not been repacked in these packs.
	shit for-each-ref --format="delete %(refname)" \
		refs/prefetch refs/tags refs/remotes >refs &&
	shit update-ref --stdin <refs &&

	# Replace the object directory with this pack layout.
	rm -f $packDir/pack-* &&
	rm -f $packDir/loose-* &&
	ls $packDir/*.pack >packs-before &&
	test_line_count = 3 packs-before &&

	# make sure we do not have any broken refs that were
	# missed in the deletion above
	shit for-each-ref &&

	# the job repacks the two into a new pack, but does not
	# delete the old ones.
	shit maintenance run --task=incremental-repack &&
	ls $packDir/*.pack >packs-between &&
	test_line_count = 4 packs-between &&

	# the job deletes the two old packs, and does not write
	# a new one because the batch size is not high enough to
	# pack the largest pack-file.
	shit maintenance run --task=incremental-repack &&
	ls .shit/objects/pack/*.pack >packs-after &&
	test_line_count = 2 packs-after
'

test_expect_success EXPENSIVE 'incremental-repack 2g limit' '
	test_config core.compression 0 &&

	for i in $(test_seq 1 5)
	do
		test-tool genrandom foo$i $((512 * 1024 * 1024 + 1)) >>big ||
		return 1
	done &&
	shit add big &&
	shit commit -qm "Add big file (1)" &&

	# ensure any possible loose objects are in a pack-file
	shit maintenance run --task=loose-objects &&

	rm big &&
	for i in $(test_seq 6 10)
	do
		test-tool genrandom foo$i $((512 * 1024 * 1024 + 1)) >>big ||
		return 1
	done &&
	shit add big &&
	shit commit -qm "Add big file (2)" &&

	# ensure any possible loose objects are in a pack-file
	shit maintenance run --task=loose-objects &&

	# Now run the incremental-repack task and check the batch-size
	shit_TRACE2_EVENT="$(pwd)/run-2g.txt" shit maintenance run \
		--task=incremental-repack 2>/dev/null &&
	test_subcommand shit multi-pack-index repack \
		 --no-progress --batch-size=2147483647 <run-2g.txt
'

run_incremental_repack_and_verify () {
	test_commit A &&
	shit repack -adk &&
	shit multi-pack-index write &&
	shit_TRACE2_EVENT="$(pwd)/midx-init.txt" shit \
		-c maintenance.incremental-repack.auto=1 \
		maintenance run --auto --task=incremental-repack 2>/dev/null &&
	test_subcommand ! shit multi-pack-index write --no-progress <midx-init.txt &&
	test_commit B &&
	shit pack-objects --revs .shit/objects/pack/pack <<-\EOF &&
	HEAD
	^HEAD~1
	EOF
	shit_TRACE2_EVENT=$(pwd)/trace-A shit \
		-c maintenance.incremental-repack.auto=2 \
		maintenance run --auto --task=incremental-repack 2>/dev/null &&
	test_subcommand ! shit multi-pack-index write --no-progress <trace-A &&
	test_commit C &&
	shit pack-objects --revs .shit/objects/pack/pack <<-\EOF &&
	HEAD
	^HEAD~1
	EOF
	shit_TRACE2_EVENT=$(pwd)/trace-B shit \
		-c maintenance.incremental-repack.auto=2 \
		maintenance run --auto --task=incremental-repack 2>/dev/null &&
	test_subcommand shit multi-pack-index write --no-progress <trace-B
}

test_expect_success 'maintenance.incremental-repack.auto' '
	rm -rf incremental-repack-true &&
	shit init incremental-repack-true &&
	(
		cd incremental-repack-true &&
		shit config core.multiPackIndex true &&
		run_incremental_repack_and_verify
	)
'

test_expect_success 'maintenance.incremental-repack.auto (when config is unset)' '
	rm -rf incremental-repack-unset &&
	shit init incremental-repack-unset &&
	(
		cd incremental-repack-unset &&
		test_unconfig core.multiPackIndex &&
		run_incremental_repack_and_verify
	)
'

test_expect_success 'pack-refs task' '
	for n in $(test_seq 1 5)
	do
		shit branch -f to-pack/$n HEAD || return 1
	done &&
	shit_TRACE2_EVENT="$(pwd)/pack-refs.txt" \
		shit maintenance run --task=pack-refs &&
	test_subcommand shit pack-refs --all --prune <pack-refs.txt
'

test_expect_success '--auto and --schedule incompatible' '
	test_must_fail shit maintenance run --auto --schedule=daily 2>err &&
	test_grep "at most one" err
'

test_expect_success 'invalid --schedule value' '
	test_must_fail shit maintenance run --schedule=annually 2>err &&
	test_grep "unrecognized --schedule" err
'

test_expect_success '--schedule inheritance weekly -> daily -> hourly' '
	shit config maintenance.loose-objects.enabled true &&
	shit config maintenance.loose-objects.schedule hourly &&
	shit config maintenance.commit-graph.enabled true &&
	shit config maintenance.commit-graph.schedule daily &&
	shit config maintenance.incremental-repack.enabled true &&
	shit config maintenance.incremental-repack.schedule weekly &&

	shit_TRACE2_EVENT="$(pwd)/hourly.txt" \
		shit maintenance run --schedule=hourly 2>/dev/null &&
	test_subcommand shit prune-packed --quiet <hourly.txt &&
	test_subcommand ! shit commit-graph write --split --reachable \
		--no-progress <hourly.txt &&
	test_subcommand ! shit multi-pack-index write --no-progress <hourly.txt &&

	shit_TRACE2_EVENT="$(pwd)/daily.txt" \
		shit maintenance run --schedule=daily 2>/dev/null &&
	test_subcommand shit prune-packed --quiet <daily.txt &&
	test_subcommand shit commit-graph write --split --reachable \
		--no-progress <daily.txt &&
	test_subcommand ! shit multi-pack-index write --no-progress <daily.txt &&

	shit_TRACE2_EVENT="$(pwd)/weekly.txt" \
		shit maintenance run --schedule=weekly 2>/dev/null &&
	test_subcommand shit prune-packed --quiet <weekly.txt &&
	test_subcommand shit commit-graph write --split --reachable \
		--no-progress <weekly.txt &&
	test_subcommand shit multi-pack-index write --no-progress <weekly.txt
'

test_expect_success 'maintenance.strategy inheritance' '
	for task in commit-graph loose-objects incremental-repack
	do
		shit config --unset maintenance.$task.schedule || return 1
	done &&

	test_when_finished shit config --unset maintenance.strategy &&
	shit config maintenance.strategy incremental &&

	shit_TRACE2_EVENT="$(pwd)/incremental-hourly.txt" \
		shit maintenance run --schedule=hourly --quiet &&
	shit_TRACE2_EVENT="$(pwd)/incremental-daily.txt" \
		shit maintenance run --schedule=daily --quiet &&
	shit_TRACE2_EVENT="$(pwd)/incremental-weekly.txt" \
		shit maintenance run --schedule=weekly --quiet &&

	test_subcommand shit commit-graph write --split --reachable \
		--no-progress <incremental-hourly.txt &&
	test_subcommand ! shit prune-packed --quiet <incremental-hourly.txt &&
	test_subcommand ! shit multi-pack-index write --no-progress \
		<incremental-hourly.txt &&
	test_subcommand ! shit pack-refs --all --prune \
		<incremental-hourly.txt &&

	test_subcommand shit commit-graph write --split --reachable \
		--no-progress <incremental-daily.txt &&
	test_subcommand shit prune-packed --quiet <incremental-daily.txt &&
	test_subcommand shit multi-pack-index write --no-progress \
		<incremental-daily.txt &&
	test_subcommand ! shit pack-refs --all --prune \
		<incremental-daily.txt &&

	test_subcommand shit commit-graph write --split --reachable \
		--no-progress <incremental-weekly.txt &&
	test_subcommand shit prune-packed --quiet <incremental-weekly.txt &&
	test_subcommand shit multi-pack-index write --no-progress \
		<incremental-weekly.txt &&
	test_subcommand shit pack-refs --all --prune \
		<incremental-weekly.txt &&

	# Modify defaults
	shit config maintenance.commit-graph.schedule daily &&
	shit config maintenance.loose-objects.schedule hourly &&
	shit config maintenance.incremental-repack.enabled false &&

	shit_TRACE2_EVENT="$(pwd)/modified-hourly.txt" \
		shit maintenance run --schedule=hourly --quiet &&
	shit_TRACE2_EVENT="$(pwd)/modified-daily.txt" \
		shit maintenance run --schedule=daily --quiet &&

	test_subcommand ! shit commit-graph write --split --reachable \
		--no-progress <modified-hourly.txt &&
	test_subcommand shit prune-packed --quiet <modified-hourly.txt &&
	test_subcommand ! shit multi-pack-index write --no-progress \
		<modified-hourly.txt &&

	test_subcommand shit commit-graph write --split --reachable \
		--no-progress <modified-daily.txt &&
	test_subcommand shit prune-packed --quiet <modified-daily.txt &&
	test_subcommand ! shit multi-pack-index write --no-progress \
		<modified-daily.txt
'

test_expect_success 'register and unregister' '
	test_when_finished shit config --global --unset-all maintenance.repo &&

	test_must_fail shit maintenance unregister 2>err &&
	grep "is not registered" err &&
	shit maintenance unregister --force &&

	shit config --global --add maintenance.repo /existing1 &&
	shit config --global --add maintenance.repo /existing2 &&
	shit config --global --get-all maintenance.repo >before &&

	shit maintenance register &&
	test_cmp_config false maintenance.auto &&
	shit config --global --get-all maintenance.repo >between &&
	cp before expect &&
	pwd >>expect &&
	test_cmp expect between &&

	shit maintenance unregister &&
	shit config --global --get-all maintenance.repo >actual &&
	test_cmp before actual &&

	shit config --file ./other --add maintenance.repo /existing1 &&
	shit config --file ./other --add maintenance.repo /existing2 &&
	shit config --file ./other --get-all maintenance.repo >before &&

	shit maintenance register --config-file ./other &&
	test_cmp_config false maintenance.auto &&
	shit config --file ./other --get-all maintenance.repo >between &&
	cp before expect &&
	pwd >>expect &&
	test_cmp expect between &&

	shit maintenance unregister --config-file ./other &&
	shit config --file ./other --get-all maintenance.repo >actual &&
	test_cmp before actual &&

	test_must_fail shit maintenance unregister 2>err &&
	grep "is not registered" err &&
	shit maintenance unregister --force &&

	test_must_fail shit maintenance unregister --config-file ./other 2>err &&
	grep "is not registered" err &&
	shit maintenance unregister --config-file ./other --force
'

test_expect_success 'register with no value for maintenance.repo' '
	cp .shit/config .shit/config.orig &&
	test_when_finished mv .shit/config.orig .shit/config &&

	cat >>.shit/config <<-\EOF &&
	[maintenance]
		repo
	EOF
	cat >expect <<-\EOF &&
	error: missing value for '\''maintenance.repo'\''
	EOF
	shit maintenance register 2>actual &&
	test_cmp expect actual &&
	shit config maintenance.repo
'

test_expect_success 'unregister with no value for maintenance.repo' '
	cp .shit/config .shit/config.orig &&
	test_when_finished mv .shit/config.orig .shit/config &&

	cat >>.shit/config <<-\EOF &&
	[maintenance]
		repo
	EOF
	cat >expect <<-\EOF &&
	error: missing value for '\''maintenance.repo'\''
	EOF
	test_expect_code 128 shit maintenance unregister 2>actual.raw &&
	grep ^error actual.raw >actual &&
	test_cmp expect actual &&
	shit config maintenance.repo &&

	shit maintenance unregister --force 2>actual.raw &&
	grep ^error actual.raw >actual &&
	test_cmp expect actual &&
	shit config maintenance.repo
'

test_expect_success !MINGW 'register and unregister with regex metacharacters' '
	META="a+b*c" &&
	shit init "$META" &&
	shit -C "$META" maintenance register &&
	shit config --get-all --show-origin maintenance.repo &&
	shit config --get-all --global --fixed-value \
		maintenance.repo "$(pwd)/$META" &&
	shit -C "$META" maintenance unregister &&
	test_must_fail shit config --get-all --global --fixed-value \
		maintenance.repo "$(pwd)/$META"
'

test_expect_success 'start --scheduler=<scheduler>' '
	test_expect_code 129 shit maintenance start --scheduler=foo 2>err &&
	test_grep "unrecognized --scheduler argument" err &&

	test_expect_code 129 shit maintenance start --no-scheduler 2>err &&
	test_grep "unknown option" err &&

	test_expect_code 128 \
		env shit_TEST_MAINT_SCHEDULER="launchctl:true,schtasks:true" \
		shit maintenance start --scheduler=crontab 2>err &&
	test_grep "fatal: crontab scheduler is not available" err
'

test_expect_success 'start from empty cron table' '
	shit_TEST_MAINT_SCHEDULER="crontab:test-tool crontab cron.txt" shit maintenance start --scheduler=crontab &&

	# start registers the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	grep "for-each-repo --keep-going --config=maintenance.repo maintenance run --schedule=daily" cron.txt &&
	grep "for-each-repo --keep-going --config=maintenance.repo maintenance run --schedule=hourly" cron.txt &&
	grep "for-each-repo --keep-going --config=maintenance.repo maintenance run --schedule=weekly" cron.txt
'

test_expect_success 'stop from existing schedule' '
	shit_TEST_MAINT_SCHEDULER="crontab:test-tool crontab cron.txt" shit maintenance stop &&

	# stop does not unregister the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	# Operation is idempotent
	shit_TEST_MAINT_SCHEDULER="crontab:test-tool crontab cron.txt" shit maintenance stop &&
	test_must_be_empty cron.txt
'

test_expect_success 'start preserves existing schedule' '
	echo "Important information!" >cron.txt &&
	shit_TEST_MAINT_SCHEDULER="crontab:test-tool crontab cron.txt" shit maintenance start --scheduler=crontab &&
	grep "Important information!" cron.txt
'

test_expect_success 'magic markers are correct' '
	grep "shit MAINTENANCE SCHEDULE" cron.txt >actual &&
	cat >expect <<-\EOF &&
	# BEGIN shit MAINTENANCE SCHEDULE
	# END shit MAINTENANCE SCHEDULE
	EOF
	test_cmp actual expect
'

test_expect_success 'stop preserves surrounding schedule' '
	echo "Crucial information!" >>cron.txt &&
	shit_TEST_MAINT_SCHEDULER="crontab:test-tool crontab cron.txt" shit maintenance stop &&
	grep "Important information!" cron.txt &&
	grep "Crucial information!" cron.txt
'

test_expect_success 'start and stop macOS maintenance' '
	# ensure $HOME can be compared against hook arguments on all platforms
	pfx=$(cd "$HOME" && pwd) &&

	write_script print-args <<-\EOF &&
	echo $* | sed "s:gui/[0-9][0-9]*:gui/[UID]:" >>args
	EOF

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER=launchctl:./print-args shit maintenance start --scheduler=launchctl &&

	# start registers the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	ls "$HOME/Library/LaunchAgents" >actual &&
	cat >expect <<-\EOF &&
	org.shit-scm.shit.daily.plist
	org.shit-scm.shit.hourly.plist
	org.shit-scm.shit.weekly.plist
	EOF
	test_cmp expect actual &&

	rm -f expect &&
	for frequency in hourly daily weekly
	do
		PLIST="$pfx/Library/LaunchAgents/org.shit-scm.shit.$frequency.plist" &&
		test_xmllint "$PLIST" &&
		grep schedule=$frequency "$PLIST" &&
		echo "bootout gui/[UID] $PLIST" >>expect &&
		echo "bootstrap gui/[UID] $PLIST" >>expect || return 1
	done &&
	test_cmp expect args &&

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER=launchctl:./print-args shit maintenance stop &&

	# stop does not unregister the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	printf "bootout gui/[UID] $pfx/Library/LaunchAgents/org.shit-scm.shit.%s.plist\n" \
		hourly daily weekly >expect &&
	test_cmp expect args &&
	ls "$HOME/Library/LaunchAgents" >actual &&
	test_line_count = 0 actual
'

test_expect_success 'use launchctl list to prevent extra work' '
	# ensure we are registered
	shit_TEST_MAINT_SCHEDULER=launchctl:./print-args shit maintenance start --scheduler=launchctl &&

	# do it again on a fresh args file
	rm -f args &&
	shit_TEST_MAINT_SCHEDULER=launchctl:./print-args shit maintenance start --scheduler=launchctl &&

	ls "$HOME/Library/LaunchAgents" >actual &&
	cat >expect <<-\EOF &&
	list org.shit-scm.shit.hourly
	list org.shit-scm.shit.daily
	list org.shit-scm.shit.weekly
	EOF
	test_cmp expect args
'

test_expect_success 'start and stop Windows maintenance' '
	write_script print-args <<-\EOF &&
	echo $* >>args
	while test $# -gt 0
	do
		case "$1" in
		/xml) shift; xmlfile=$1; break ;;
		*) shift ;;
		esac
	done
	test -z "$xmlfile" || cp "$xmlfile" "$xmlfile.xml"
	EOF

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="schtasks:./print-args" shit maintenance start --scheduler=schtasks &&

	# start registers the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	for frequency in hourly daily weekly
	do
		grep "/create /tn shit Maintenance ($frequency) /f /xml" args &&
		file=$(ls .shit/schedule_${frequency}*.xml) &&
		test_xmllint "$file" || return 1
	done &&

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="schtasks:./print-args" shit maintenance stop &&

	# stop does not unregister the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	printf "/delete /tn shit Maintenance (%s) /f\n" \
		hourly daily weekly >expect &&
	test_cmp expect args
'

test_expect_success 'start and stop Linux/systemd maintenance' '
	write_script print-args <<-\EOF &&
	printf "%s\n" "$*" >>args
	EOF

	XDG_CONFIG_HOME="$PWD" &&
	export XDG_CONFIG_HOME &&
	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="systemctl:./print-args" shit maintenance start --scheduler=systemd-timer &&

	# start registers the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	for schedule in hourly daily weekly
	do
		test_path_is_file "systemd/user/shit-maintenance@$schedule.timer" || return 1
	done &&
	test_path_is_file "systemd/user/shit-maintenance@.service" &&

	test_systemd_analyze_verify "systemd/user/shit-maintenance@hourly.service" &&
	test_systemd_analyze_verify "systemd/user/shit-maintenance@daily.service" &&
	test_systemd_analyze_verify "systemd/user/shit-maintenance@weekly.service" &&

	printf -- "--user enable --now shit-maintenance@%s.timer\n" hourly daily weekly >expect &&
	test_cmp expect args &&

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="systemctl:./print-args" shit maintenance stop &&

	# stop does not unregister the repo
	shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&

	for schedule in hourly daily weekly
	do
		test_path_is_missing "systemd/user/shit-maintenance@$schedule.timer" || return 1
	done &&
	test_path_is_missing "systemd/user/shit-maintenance@.service" &&

	printf -- "--user disable --now shit-maintenance@%s.timer\n" hourly daily weekly >expect &&
	test_cmp expect args
'

test_expect_success 'start and stop when several schedulers are available' '
	write_script print-args <<-\EOF &&
	printf "%s\n" "$*" | sed "s:gui/[0-9][0-9]*:gui/[UID]:; s:\(schtasks /create .* /xml\).*:\1:;" >>args
	EOF

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="systemctl:./print-args systemctl,launchctl:./print-args launchctl,schtasks:./print-args schtasks" shit maintenance start --scheduler=systemd-timer &&
	printf "launchctl bootout gui/[UID] $pfx/Library/LaunchAgents/org.shit-scm.shit.%s.plist\n" \
		hourly daily weekly >expect &&
	printf "schtasks /delete /tn shit Maintenance (%s) /f\n" \
		hourly daily weekly >>expect &&
	printf -- "systemctl --user enable --now shit-maintenance@%s.timer\n" hourly daily weekly >>expect &&
	test_cmp expect args &&

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="systemctl:./print-args systemctl,launchctl:./print-args launchctl,schtasks:./print-args schtasks" shit maintenance start --scheduler=launchctl &&
	printf -- "systemctl --user disable --now shit-maintenance@%s.timer\n" hourly daily weekly >expect &&
	printf "schtasks /delete /tn shit Maintenance (%s) /f\n" \
		hourly daily weekly >>expect &&
	for frequency in hourly daily weekly
	do
		PLIST="$pfx/Library/LaunchAgents/org.shit-scm.shit.$frequency.plist" &&
		echo "launchctl bootout gui/[UID] $PLIST" >>expect &&
		echo "launchctl bootstrap gui/[UID] $PLIST" >>expect || return 1
	done &&
	test_cmp expect args &&

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="systemctl:./print-args systemctl,launchctl:./print-args launchctl,schtasks:./print-args schtasks" shit maintenance start --scheduler=schtasks &&
	printf -- "systemctl --user disable --now shit-maintenance@%s.timer\n" hourly daily weekly >expect &&
	printf "launchctl bootout gui/[UID] $pfx/Library/LaunchAgents/org.shit-scm.shit.%s.plist\n" \
		hourly daily weekly >>expect &&
	printf "schtasks /create /tn shit Maintenance (%s) /f /xml\n" \
		hourly daily weekly >>expect &&
	test_cmp expect args &&

	rm -f args &&
	shit_TEST_MAINT_SCHEDULER="systemctl:./print-args systemctl,launchctl:./print-args launchctl,schtasks:./print-args schtasks" shit maintenance stop &&
	printf -- "systemctl --user disable --now shit-maintenance@%s.timer\n" hourly daily weekly >expect &&
	printf "launchctl bootout gui/[UID] $pfx/Library/LaunchAgents/org.shit-scm.shit.%s.plist\n" \
		hourly daily weekly >>expect &&
	printf "schtasks /delete /tn shit Maintenance (%s) /f\n" \
		hourly daily weekly >>expect &&
	test_cmp expect args
'

test_expect_success 'register preserves existing strategy' '
	shit config maintenance.strategy none &&
	shit maintenance register &&
	test_config maintenance.strategy none &&
	shit config --unset maintenance.strategy &&
	shit maintenance register &&
	test_config maintenance.strategy incremental
'

test_expect_success 'fails when running outside of a repository' '
	nonshit test_must_fail shit maintenance run &&
	nonshit test_must_fail shit maintenance stop &&
	nonshit test_must_fail shit maintenance start &&
	nonshit test_must_fail shit maintenance register &&
	nonshit test_must_fail shit maintenance unregister
'

test_expect_success 'register and unregister bare repo' '
	test_when_finished "shit config --global --unset-all maintenance.repo || :" &&
	test_might_fail shit config --global --unset-all maintenance.repo &&
	shit init --bare barerepo &&
	(
		cd barerepo &&
		shit maintenance register &&
		shit config --get --global --fixed-value maintenance.repo "$(pwd)" &&
		shit maintenance unregister &&
		test_must_fail shit config --global --get-all maintenance.repo
	)
'

test_expect_success 'failed schedule prevents config change' '
	shit init --bare failcase &&

	for scheduler in crontab launchctl schtasks systemctl
	do
		shit_TEST_MAINT_SCHEDULER="$scheduler:false" &&
		export shit_TEST_MAINT_SCHEDULER &&
		test_must_fail \
			shit -C failcase maintenance start &&
		test_must_fail shit -C failcase config maintenance.auto || return 1
	done
'

test_done
