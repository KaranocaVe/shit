#!/bin/sh

test_description='test untracked cache'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# On some filesystems (e.g. FreeBSD's ext2 and ufs) directory mtime
# is updated lazily after contents in the directory changes, which
# forces the untracked cache code to take the slow path.  A test
# that wants to make sure that the fast path works correctly should
# call this helper to make mtime of the containing directory in sync
# with the reality before checking the fast path behaviour.
#
# See <20160803174522.5571-1-pclouds@gmail.com> if you want to know
# more.

shit_FORCE_UNTRACKED_CACHE=true
export shit_FORCE_UNTRACKED_CACHE

sync_mtime () {
	find . -type d -exec ls -ld {} + >/dev/null
}

avoid_racy() {
	sleep 1
}

status_is_clean() {
	shit status --porcelain >../status.actual &&
	test_must_be_empty ../status.actual
}

# Ignore_Untracked_Cache, abbreviated to 3 letters because then people can
# compare commands side-by-side, e.g.
#    iuc status --porcelain >expect &&
#    shit status --porcelain >actual &&
#    test_cmp expect actual
iuc () {
	shit ls-files -s >../current-index-entries
	shit ls-files -t | sed -ne s/^S.//p >../current-sparse-entries

	shit_INDEX_FILE=.shit/tmp_index
	export shit_INDEX_FILE
	shit update-index --index-info <../current-index-entries
	shit update-index --skip-worktree $(cat ../current-sparse-entries)

	shit -c core.untrackedCache=false "$@"
	ret=$?

	rm ../current-index-entries
	rm $shit_INDEX_FILE
	unset shit_INDEX_FILE

	return $ret
}

get_relevant_traces () {
	# From the shit_TRACE2_PERF data of the form
	#    $TIME $FILE:$LINE | d0 | main | data | r1 | ? | ? | read_directo | $RELEVANT_STAT
	# extract the $RELEVANT_STAT fields.  We don't care about region_enter
	# or region_leave, or stats for things outside read_directory.
	INPUT_FILE=$1
	OUTPUT_FILE=$2
	grep data.*read_directo $INPUT_FILE |
	    cut -d "|" -f 9 |
	    grep -v visited \
	    >"$OUTPUT_FILE"
}


test_lazy_prereq UNTRACKED_CACHE '
	{ shit update-index --test-untracked-cache; ret=$?; } &&
	test $ret -ne 1
'

if ! test_have_prereq UNTRACKED_CACHE; then
	skip_all='This system does not support untracked cache'
	test_done
fi

test_expect_success 'core.untrackedCache is unset' '
	test_must_fail shit config --get core.untrackedCache
'

test_expect_success 'setup' '
	shit init --template= worktree &&
	cd worktree &&
	mkdir done dtwo dthree &&
	touch one two three done/one dtwo/two dthree/three &&
	test-tool chmtime =-300 one two three done/one dtwo/two dthree/three &&
	test-tool chmtime =-300 done dtwo dthree &&
	test-tool chmtime =-300 . &&
	shit add one two done/one &&
	mkdir .shit/info &&
	: >.shit/info/exclude &&
	shit update-index --untracked-cache &&
	test_oid_cache <<-EOF
	root sha1:e6fcc8f2ee31bae321d66afd183fcb7237afae6e
	root sha256:b90c672088c015b9c83876e919da311bad4cd39639fb139f988af6a11493b974

	exclude sha1:13263c0978fb9fad16b2d580fb800b6d811c3ff0
	exclude sha256:fe4aaa1bbbbce4cb8f73426748a14c5ad6026b26f90505a0bf2494b165a5b76c

	done sha1:1946f0437f90c5005533cbe1736a6451ca301714
	done sha256:7f079501d79f665b3acc50f5e0e9e94509084d5032ac20113a37dd5029b757cc
	EOF
'

test_expect_success 'untracked cache is empty' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect-empty <<EOF &&
info/exclude $ZERO_OID
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
EOF
	test_cmp ../expect-empty ../actual
'

cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? dthree/
?? dtwo/
?? three
EOF

cat >../dump.expect <<EOF &&
info/exclude $EMPTY_BLOB
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $ZERO_OID recurse valid
dthree/
dtwo/
three
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
three
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF

test_expect_success 'status first time (empty cache)' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:3
 ....shitignore-invalidation:1
 ....directory-invalidation:0
 ....opendir:4
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'untracked cache after first status' '
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../dump.expect ../actual
'

test_expect_success 'status second time (fully populated cache)' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:0
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'untracked cache after second status' '
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../dump.expect ../actual
'

cat >../status_uall.expect <<EOF &&
A  done/one
A  one
A  two
?? dthree/three
?? dtwo/two
?? three
EOF

# Bypassing the untracked cache here is not desirable from an
# end-user perspective, but is expected in the current design.
# The untracked cache data stored for a -unormal run cannot be
# correctly used in a -uall run - it would yield incorrect output.
test_expect_success 'untracked cache is bypassed with -uall' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status -uall --porcelain >../actual &&
	iuc status -uall --porcelain >../status.iuc &&
	test_cmp ../status_uall.expect ../status.iuc &&
	test_cmp ../status_uall.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'untracked cache remains after bypass' '
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../dump.expect ../actual
'

test_expect_success 'if -uall is configured, untracked cache gets populated by default' '
	test_config status.showuntrackedfiles all &&
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	test_cmp ../status_uall.expect ../status.iuc &&
	test_cmp ../status_uall.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:3
 ....shitignore-invalidation:1
 ....directory-invalidation:0
 ....opendir:4
EOF
	test_cmp ../trace.expect ../trace.relevant
'

cat >../dump_uall.expect <<EOF &&
info/exclude $EMPTY_BLOB
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000000
/ $ZERO_OID recurse valid
three
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse valid
three
/dtwo/ $ZERO_OID recurse valid
two
EOF

test_expect_success 'if -uall was configured, untracked cache is populated' '
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../dump_uall.expect ../actual
'

test_expect_success 'if -uall is configured, untracked cache is used by default' '
	test_config status.showuntrackedfiles all &&
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	test_cmp ../status_uall.expect ../status.iuc &&
	test_cmp ../status_uall.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:0
EOF
	test_cmp ../trace.expect ../trace.relevant
'

# Bypassing the untracked cache here is not desirable from an
# end-user perspective, but is expected in the current design.
# The untracked cache data stored for a -all run cannot be
# correctly used in a -unormal run - it would yield incorrect
# output.
test_expect_success 'if -uall is configured, untracked cache is bypassed with -unormal' '
	test_config status.showuntrackedfiles all &&
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status -unormal --porcelain >../actual &&
	iuc status -unormal --porcelain >../status.iuc &&
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'repopulate untracked cache for -unormal' '
	shit status --porcelain
'

test_expect_success 'modify in root directory, one dir invalidation' '
	: >four &&
	test-tool chmtime =-240 four &&
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? dthree/
?? dtwo/
?? four
?? three
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:1
 ....opendir:1
EOF
	test_cmp ../trace.expect ../trace.relevant

'

test_expect_success 'verify untracked cache dump' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $EMPTY_BLOB
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $ZERO_OID recurse valid
dthree/
dtwo/
four
three
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
three
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'new .shitignore invalidates recursively' '
	echo four >.shitignore &&
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? .shitignore
?? dthree/
?? dtwo/
?? three
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:1
 ....directory-invalidation:1
 ....opendir:4
EOF
	test_cmp ../trace.expect ../trace.relevant

'

test_expect_success 'verify untracked cache dump' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $EMPTY_BLOB
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dthree/
dtwo/
three
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
three
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'new info/exclude invalidates everything' '
	echo three >>.shit/info/exclude &&
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? .shitignore
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:1
 ....directory-invalidation:0
 ....opendir:4
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'verify untracked cache dump' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dtwo/
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'move two from tracked to untracked' '
	shit rm --cached two &&
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'status after the move' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
?? .shitignore
?? dtwo/
?? two
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:1
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'verify untracked cache dump' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dtwo/
two
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'move two from untracked to tracked' '
	shit add two &&
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'status after the move' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? .shitignore
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:1
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'verify untracked cache dump' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dtwo/
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'set up for sparse checkout testing' '
	echo two >done/.shitignore &&
	echo three >>done/.shitignore &&
	echo two >done/two &&
	shit add -f done/two done/.shitignore &&
	shit commit -m "first commit"
'

test_expect_success 'status after commit' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
?? .shitignore
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:2
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'untracked cache correct after commit' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dtwo/
/done/ $ZERO_OID recurse valid
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'set up sparse checkout' '
	echo "done/[a-z]*" >.shit/info/sparse-checkout &&
	test_config core.sparsecheckout true &&
	shit checkout main &&
	shit update-index --force-untracked-cache &&
	shit status --porcelain >/dev/null && # prime the cache
	test_path_is_missing done/.shitignore &&
	test_path_is_file done/one
'

test_expect_success 'create/modify files, some of which are shitignored' '
	echo two bis >done/two &&
	echo three >done/three && # three is shitignored
	echo four >done/four && # four is shitignored at a higher level
	echo five >done/five && # five is not shitignored
	test-tool chmtime =-180 done/two done/three done/four done/five done &&
	# we need to ensure that the root dir is touched (in the past);
	test-tool chmtime =-180 . &&
	sync_mtime
'

test_expect_success 'test sparse status with untracked cache' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../status.actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
 M done/two
?? .shitignore
?? done/five
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../status.actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:1
 ....directory-invalidation:2
 ....opendir:2
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'untracked cache correct after status' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dtwo/
/done/ $(test_oid done) recurse valid
five
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'test sparse status again with untracked cache' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../status.actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
 M done/two
?? .shitignore
?? done/five
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../status.actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:0
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'set up for test of subdir and sparse checkouts' '
	mkdir done/sub &&
	mkdir done/sub/sub &&
	echo "sub" > done/sub/sub/file &&
	test-tool chmtime =-120 done/sub/sub/file done/sub/sub done/sub done
'

test_expect_success 'test sparse status with untracked cache and subdir' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../status.actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
 M done/two
?? .shitignore
?? done/five
?? done/sub/
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../status.actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:2
 ....shitignore-invalidation:0
 ....directory-invalidation:1
 ....opendir:3
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'verify untracked cache dump (sparse/subdirs)' '
	test-tool dump-untracked-cache >../actual &&
	cat >../expect-from-test-dump <<EOF &&
info/exclude $(test_oid exclude)
core.excludesfile $ZERO_OID
exclude_per_dir .shitignore
flags 00000006
/ $(test_oid root) recurse valid
.shitignore
dtwo/
/done/ $(test_oid done) recurse valid
five
sub/
/done/sub/ $ZERO_OID recurse check_only valid
sub/
/done/sub/sub/ $ZERO_OID recurse check_only valid
file
/dthree/ $ZERO_OID recurse check_only valid
/dtwo/ $ZERO_OID recurse check_only valid
two
EOF
	test_cmp ../expect-from-test-dump ../actual
'

test_expect_success 'test sparse status again with untracked cache and subdir' '
	: >../trace.output &&
	shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
	shit status --porcelain >../status.actual &&
	iuc status --porcelain >../status.iuc &&
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../status.actual &&
	get_relevant_traces ../trace.output ../trace.relevant &&
	cat >../trace.expect <<EOF &&
 ....path:
 ....node-creation:0
 ....shitignore-invalidation:0
 ....directory-invalidation:0
 ....opendir:0
EOF
	test_cmp ../trace.expect ../trace.relevant
'

test_expect_success 'move entry in subdir from untracked to cached' '
	shit add dtwo/two &&
	shit status --porcelain >../status.actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
 M done/two
A  dtwo/two
?? .shitignore
?? done/five
?? done/sub/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../status.actual
'

test_expect_success 'move entry in subdir from cached to untracked' '
	shit rm --cached dtwo/two &&
	shit status --porcelain >../status.actual &&
	iuc status --porcelain >../status.iuc &&
	cat >../status.expect <<EOF &&
 M done/two
?? .shitignore
?? done/five
?? done/sub/
?? dtwo/
EOF
	test_cmp ../status.expect ../status.iuc &&
	test_cmp ../status.expect ../status.actual
'

test_expect_success '--no-untracked-cache removes the cache' '
	shit update-index --no-untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	echo "no untracked cache" >../expect-no-uc &&
	test_cmp ../expect-no-uc ../actual
'

test_expect_success 'shit status does not change anything' '
	shit status &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-no-uc ../actual
'

test_expect_success 'setting core.untrackedCache to true and using shit status creates the cache' '
	shit config core.untrackedCache true &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-no-uc ../actual &&
	shit status &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-from-test-dump ../actual
'

test_expect_success 'using --no-untracked-cache does not fail when core.untrackedCache is true' '
	shit update-index --no-untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-no-uc ../actual &&
	shit update-index --untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-empty ../actual
'

test_expect_success 'setting core.untrackedCache to false and using shit status removes the cache' '
	shit config core.untrackedCache false &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-empty ../actual &&
	shit status &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-no-uc ../actual
'

test_expect_success 'using --untracked-cache does not fail when core.untrackedCache is false' '
	shit update-index --untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-empty ../actual
'

test_expect_success 'setting core.untrackedCache to keep' '
	shit config core.untrackedCache keep &&
	shit update-index --untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-empty ../actual &&
	shit status &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-from-test-dump ../actual &&
	shit update-index --no-untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-no-uc ../actual &&
	shit update-index --force-untracked-cache &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-empty ../actual &&
	shit status &&
	test-tool dump-untracked-cache >../actual &&
	test_cmp ../expect-from-test-dump ../actual
'

test_expect_success 'test ident field is working' '
	mkdir ../other_worktree &&
	cp -R done dthree dtwo four three ../other_worktree &&
	shit_WORK_TREE=../other_worktree shit status 2>../err &&
	echo "warning: untracked cache is disabled on this system or location" >../expect &&
	test_cmp ../expect ../err
'

test_expect_success 'untracked cache survives a checkout' '
	shit commit --allow-empty -m empty &&
	test-tool dump-untracked-cache >../before &&
	test_when_finished  "shit checkout main" &&
	shit checkout -b other_branch &&
	test-tool dump-untracked-cache >../after &&
	test_cmp ../before ../after &&
	test_commit test &&
	test-tool dump-untracked-cache >../before &&
	shit checkout main &&
	test-tool dump-untracked-cache >../after &&
	test_cmp ../before ../after
'

test_expect_success 'untracked cache survives a commit' '
	test-tool dump-untracked-cache >../before &&
	shit add done/two &&
	shit commit -m commit &&
	test-tool dump-untracked-cache >../after &&
	test_cmp ../before ../after
'

test_expect_success 'teardown worktree' '
	cd ..
'

test_expect_success SYMLINKS 'setup worktree for symlink test' '
	shit init worktree-symlink &&
	cd worktree-symlink &&
	shit config core.untrackedCache true &&
	mkdir one two &&
	touch one/file two/file &&
	shit add one/file two/file &&
	shit commit -m"first commit" &&
	shit rm -rf one &&
	ln -s two one &&
	shit add one &&
	shit commit -m"second commit"
'

test_expect_success SYMLINKS '"status" after symlink replacement should be clean with UC=true' '
	shit checkout HEAD~ &&
	status_is_clean &&
	status_is_clean &&
	shit checkout main &&
	avoid_racy &&
	status_is_clean &&
	status_is_clean
'

test_expect_success SYMLINKS '"status" after symlink replacement should be clean with UC=false' '
	shit config core.untrackedCache false &&
	shit checkout HEAD~ &&
	status_is_clean &&
	status_is_clean &&
	shit checkout main &&
	avoid_racy &&
	status_is_clean &&
	status_is_clean
'

test_expect_success 'setup worktree for non-symlink test' '
	shit init worktree-non-symlink &&
	cd worktree-non-symlink &&
	shit config core.untrackedCache true &&
	mkdir one two &&
	touch one/file two/file &&
	shit add one/file two/file &&
	shit commit -m"first commit" &&
	shit rm -rf one &&
	cp two/file one &&
	shit add one &&
	shit commit -m"second commit"
'

test_expect_success '"status" after file replacement should be clean with UC=true' '
	shit checkout HEAD~ &&
	status_is_clean &&
	status_is_clean &&
	shit checkout main &&
	avoid_racy &&
	status_is_clean &&
	test-tool dump-untracked-cache >../actual &&
	grep -F "recurse valid" ../actual >../actual.grep &&
	cat >../expect.grep <<EOF &&
/ $ZERO_OID recurse valid
/two/ $ZERO_OID recurse valid
EOF
	status_is_clean &&
	test_cmp ../expect.grep ../actual.grep
'

test_expect_success '"status" after file replacement should be clean with UC=false' '
	shit config core.untrackedCache false &&
	shit checkout HEAD~ &&
	status_is_clean &&
	status_is_clean &&
	shit checkout main &&
	avoid_racy &&
	status_is_clean &&
	status_is_clean
'

test_expect_success 'empty repo (no index) and core.untrackedCache' '
	shit init emptyrepo &&
	shit -C emptyrepo -c core.untrackedCache=true write-tree
'

test_done
