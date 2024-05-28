#!/bin/sh

test_description='test shit rev-parse'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_one () {
	dir="$1" &&
	expect="$2" &&
	shift &&
	shift &&
	echo "$expect" >expect &&
	shit -C "$dir" rev-parse "$@" >actual &&
	test_cmp expect actual
}

# usage: [options] label is-bare is-inside-shit is-inside-work prefix shit-dir absolute-shit-dir
test_rev_parse () {
	d=
	bare=
	shitdir=
	while :
	do
		case "$1" in
		-C) d="$2"; shift; shift ;;
		-b) case "$2" in
		    [tfu]*) bare="$2"; shift; shift ;;
		    *) error "test_rev_parse: bogus core.bare value '$2'" ;;
		    esac ;;
		-g) shitdir="$2"; shift; shift ;;
		-*) error "test_rev_parse: unrecognized option '$1'" ;;
		*) break ;;
		esac
	done

	name=$1
	shift

	for o in --is-bare-repository \
		 --is-inside-shit-dir \
		 --is-inside-work-tree \
		 --show-prefix \
		 --shit-dir \
		 --absolute-shit-dir
	do
		test $# -eq 0 && break
		expect="$1"
		test_expect_success "$name: $o" '
			if test -n "$shitdir"
			then
				test_when_finished "unset shit_DIR" &&
				shit_DIR="$shitdir" &&
				export shit_DIR
			fi &&

			case "$bare" in
			t*) test_config ${d:+-C} ${d:+"$d"} core.bare true ;;
			f*) test_config ${d:+-C} ${d:+"$d"} core.bare false ;;
			u*) test_unconfig ${d:+-C} ${d:+"$d"} core.bare ;;
			esac &&

			echo "$expect" >expect &&
			shit ${d:+-C} ${d:+"$d"} rev-parse $o >actual &&
			test_cmp expect actual
		'
		shift
	done
}

ROOT=$(pwd)

test_expect_success 'setup' '
	mkdir -p sub/dir work &&
	cp -R .shit repo.shit &&
	shit checkout -B main &&
	test_commit abc &&
	shit checkout -b side &&
	test_commit def &&
	shit checkout main &&
	shit worktree add worktree side
'

test_rev_parse toplevel false false true '' .shit "$ROOT/.shit"

test_rev_parse -C .shit .shit/ false true false '' . "$ROOT/.shit"
test_rev_parse -C .shit/objects .shit/objects/ false true false '' "$ROOT/.shit" "$ROOT/.shit"

test_rev_parse -C sub/dir subdirectory false false true sub/dir/ "$ROOT/.shit" "$ROOT/.shit"

test_rev_parse -b t 'core.bare = true' true false false

test_rev_parse -b u 'core.bare undefined' false false true


test_rev_parse -C work -g ../.shit -b f 'shit_DIR=../.shit, core.bare = false' false false true '' "../.shit" "$ROOT/.shit"

test_rev_parse -C work -g ../.shit -b t 'shit_DIR=../.shit, core.bare = true' true false false ''

test_rev_parse -C work -g ../.shit -b u 'shit_DIR=../.shit, core.bare undefined' false false true ''


test_rev_parse -C work -g ../repo.shit -b f 'shit_DIR=../repo.shit, core.bare = false' false false true '' "../repo.shit" "$ROOT/repo.shit"

test_rev_parse -C work -g ../repo.shit -b t 'shit_DIR=../repo.shit, core.bare = true' true false false ''

test_rev_parse -C work -g ../repo.shit -b u 'shit_DIR=../repo.shit, core.bare undefined' false false true ''

test_expect_success 'rev-parse --path-format=absolute' '
	test_one "." "$ROOT/.shit" --path-format=absolute --shit-dir &&
	test_one "." "$ROOT/.shit" --path-format=absolute --shit-common-dir &&
	test_one "sub/dir" "$ROOT/.shit" --path-format=absolute --shit-dir &&
	test_one "sub/dir" "$ROOT/.shit" --path-format=absolute --shit-common-dir &&
	test_one "worktree" "$ROOT/.shit/worktrees/worktree" --path-format=absolute --shit-dir &&
	test_one "worktree" "$ROOT/.shit" --path-format=absolute --shit-common-dir &&
	test_one "." "$ROOT" --path-format=absolute --show-toplevel &&
	test_one "." "$ROOT/.shit/objects" --path-format=absolute --shit-path objects &&
	test_one "." "$ROOT/.shit/objects/foo/bar/baz" --path-format=absolute --shit-path objects/foo/bar/baz
'

test_expect_success 'rev-parse --path-format=relative' '
	test_one "." ".shit" --path-format=relative --shit-dir &&
	test_one "." ".shit" --path-format=relative --shit-common-dir &&
	test_one "sub/dir" "../../.shit" --path-format=relative --shit-dir &&
	test_one "sub/dir" "../../.shit" --path-format=relative --shit-common-dir &&
	test_one "worktree" "../.shit/worktrees/worktree" --path-format=relative --shit-dir &&
	test_one "worktree" "../.shit" --path-format=relative --shit-common-dir &&
	test_one "." "./" --path-format=relative --show-toplevel &&
	test_one "." ".shit/objects" --path-format=relative --shit-path objects &&
	test_one "." ".shit/objects/foo/bar/baz" --path-format=relative --shit-path objects/foo/bar/baz
'

test_expect_success '--path-format=relative does not affect --absolute-shit-dir' '
	shit rev-parse --path-format=relative --absolute-shit-dir >actual &&
	echo "$ROOT/.shit" >expect &&
	test_cmp expect actual
'

test_expect_success '--path-format can change in the middle of the command line' '
	shit rev-parse --path-format=absolute --shit-dir --path-format=relative --shit-path objects/foo/bar >actual &&
	cat >expect <<-EOF &&
	$ROOT/.shit
	.shit/objects/foo/bar
	EOF
	test_cmp expect actual
'

test_expect_success '--path-format does not segfault without an argument' '
	test_must_fail shit rev-parse --path-format
'

test_expect_success 'shit-common-dir from worktree root' '
	echo .shit >expect &&
	shit rev-parse --shit-common-dir >actual &&
	test_cmp expect actual
'

test_expect_success 'shit-common-dir inside sub-dir' '
	mkdir -p path/to/child &&
	test_when_finished "rm -rf path" &&
	echo "$(shit -C path/to/child rev-parse --show-cdup).shit" >expect &&
	shit -C path/to/child rev-parse --shit-common-dir >actual &&
	test_cmp expect actual
'

test_expect_success 'shit-path from worktree root' '
	echo .shit/objects >expect &&
	shit rev-parse --shit-path objects >actual &&
	test_cmp expect actual
'

test_expect_success 'shit-path inside sub-dir' '
	mkdir -p path/to/child &&
	test_when_finished "rm -rf path" &&
	echo "$(shit -C path/to/child rev-parse --show-cdup).shit/objects" >expect &&
	shit -C path/to/child rev-parse --shit-path objects >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse --is-shallow-repository in shallow repo' '
	test_commit test_commit &&
	echo true >expect &&
	shit clone --depth 1 --no-local . shallow &&
	test_when_finished "rm -rf shallow" &&
	shit -C shallow rev-parse --is-shallow-repository >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse --is-shallow-repository in non-shallow repo' '
	echo false >expect &&
	shit rev-parse --is-shallow-repository >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse --show-object-format in repo' '
	test_oid algo >expect &&
	shit rev-parse --show-object-format >actual &&
	test_cmp expect actual &&
	shit rev-parse --show-object-format=storage >actual &&
	test_cmp expect actual &&
	shit rev-parse --show-object-format=input >actual &&
	test_cmp expect actual &&
	shit rev-parse --show-object-format=output >actual &&
	test_cmp expect actual &&
	test_must_fail shit rev-parse --show-object-format=squeamish-ossifrage 2>err &&
	grep "unknown mode for --show-object-format: squeamish-ossifrage" err
'

test_expect_success 'rev-parse --show-ref-format' '
	test_detect_ref_format >expect &&
	shit rev-parse --show-ref-format >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse --show-ref-format with invalid storage' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		shit config extensions.refstorage broken &&
		test_must_fail shit rev-parse --show-ref-format 2>err &&
		grep "error: invalid value for ${SQ}extensions.refstorage${SQ}: ${SQ}broken${SQ}" err
	)
'

test_expect_success '--show-toplevel from subdir of working tree' '
	pwd >expect &&
	shit -C sub/dir rev-parse --show-toplevel >actual &&
	test_cmp expect actual
'

test_expect_success '--show-toplevel from inside .shit' '
	test_must_fail shit -C .shit rev-parse --show-toplevel
'

test_expect_success 'showing the superproject correctly' '
	shit rev-parse --show-superproject-working-tree >out &&
	test_must_be_empty out &&

	test_create_repo super &&
	test_commit -C super test_commit &&
	test_create_repo sub &&
	test_commit -C sub test_commit &&
	shit -c protocol.file.allow=always \
		-C super submodule add ../sub dir/sub &&
	echo $(pwd)/super >expect  &&
	shit -C super/dir/sub rev-parse --show-superproject-working-tree >out &&
	test_cmp expect out &&

	test_commit -C super submodule_add &&
	shit -C super checkout -b branch1 &&
	shit -C super/dir/sub checkout -b branch1 &&
	test_commit -C super/dir/sub branch1_commit &&
	shit -C super add dir/sub &&
	test_commit -C super branch1_commit &&
	shit -C super checkout -b branch2 main &&
	shit -C super/dir/sub checkout -b branch2 main &&
	test_commit -C super/dir/sub branch2_commit &&
	shit -C super add dir/sub &&
	test_commit -C super branch2_commit &&
	test_must_fail shit -C super merge branch1 &&

	shit -C super/dir/sub rev-parse --show-superproject-working-tree >out &&
	test_cmp expect out
'

# at least one external project depends on this behavior:
test_expect_success 'rev-parse --since= unsqueezed ordering' '
	x1=--since=1970-01-01T00:00:01Z &&
	x2=--since=1970-01-01T00:00:02Z &&
	x3=--since=1970-01-01T00:00:03Z &&
	shit rev-parse $x1 $x1 $x3 $x2 >actual &&
	cat >expect <<-EOF &&
	--max-age=1
	--max-age=1
	--max-age=3
	--max-age=2
	EOF
	test_cmp expect actual
'

test_expect_success 'rev-parse --bisect includes bad, excludes good' '
	test_commit_bulk 6 &&

	shit update-ref refs/bisect/bad-1 HEAD~1 &&
	shit update-ref refs/bisect/b HEAD~2 &&
	shit update-ref refs/bisect/bad-3 HEAD~3 &&
	shit update-ref refs/bisect/good-3 HEAD~3 &&
	shit update-ref refs/bisect/bad-4 HEAD~4 &&
	shit update-ref refs/bisect/go HEAD~4 &&

	# Note: refs/bisect/b and refs/bisect/go should be ignored because they
	# do not match the refs/bisect/bad or refs/bisect/good prefixes.
	cat >expect <<-EOF &&
	refs/bisect/bad-1
	refs/bisect/bad-3
	refs/bisect/bad-4
	^refs/bisect/good-3
	EOF

	shit rev-parse --symbolic-full-name --bisect >actual &&
	test_cmp expect actual
'

test_done
