#!/bin/sh

test_description='shit commit porcelain-ish'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

commit_msg_is () {
	expect=commit_msg_is.expect
	actual=commit_msg_is.actual

	printf "%s" "$(shit log --pretty=format:%s%b -1)" >$actual &&
	printf "%s" "$1" >$expect &&
	test_cmp $expect $actual
}

# Arguments: [<prefix] [<commit message>] [<commit options>]
check_summary_oneline() {
	test_tick &&
	shit commit ${3+"$3"} -m "$2" >raw &&
	head -n 1 raw >act &&

	# branch name
	SUMMARY_PREFIX="$(shit name-rev --name-only HEAD)" &&

	# append the "special" prefix, like "root-commit", "detached HEAD"
	if test -n "$1"
	then
		SUMMARY_PREFIX="$SUMMARY_PREFIX ($1)"
	fi

	# abbrev SHA-1
	SUMMARY_POSTFIX="$(shit log -1 --pretty='format:%h')"
	echo "[$SUMMARY_PREFIX $SUMMARY_POSTFIX] $2" >exp &&

	test_cmp exp act
}

trailer_commit_base () {
	echo "fun" >>file &&
	shit add file &&
	shit commit -s --trailer "Signed-off-by=C1 E1 " \
		--trailer "Helped-by:C2 E2 " \
		--trailer "Reported-by=C3 E3" \
		--trailer "Mentored-by:C4 E4" \
		-m "hello"
}

test_expect_success 'output summary format' '

	echo new >file1 &&
	shit add file1 &&
	check_summary_oneline "root-commit" "initial" &&

	echo change >>file1 &&
	shit add file1
'

test_expect_success 'output summary format: root-commit' '
	check_summary_oneline "" "a change"
'

test_expect_success 'output summary format for commit with an empty diff' '

	check_summary_oneline "" "empty" "--allow-empty"
'

test_expect_success 'output summary format for merges' '

	shit checkout -b recursive-base &&
	test_commit base file1 &&

	shit checkout -b recursive-a recursive-base &&
	test_commit commit-a file1 &&

	shit checkout -b recursive-b recursive-base &&
	test_commit commit-b file1 &&

	# conflict
	shit checkout recursive-a &&
	test_must_fail shit merge recursive-b &&
	# resolve the conflict
	echo commit-a >file1 &&
	shit add file1 &&
	check_summary_oneline "" "Merge"
'

output_tests_cleanup() {
	# this is needed for "do not fire editor in the presence of conflicts"
	shit checkout main &&

	# this is needed for the "partial removal" test to pass
	shit rm file1 &&
	shit commit -m "cleanup"
}

test_expect_success 'the basics' '

	output_tests_cleanup &&

	echo doing partial >"commit is" &&
	mkdir not &&
	echo very much encouraged but we should >not/forbid &&
	shit add "commit is" not &&
	echo update added "commit is" file >"commit is" &&
	echo also update another >not/forbid &&
	test_tick &&
	shit commit -a -m "initial with -a" &&

	shit cat-file blob HEAD:"commit is" >current.1 &&
	shit cat-file blob HEAD:not/forbid >current.2 &&

	cmp current.1 "commit is" &&
	cmp current.2 not/forbid

'

test_expect_success 'partial' '

	echo another >"commit is" &&
	echo another >not/forbid &&
	test_tick &&
	shit commit -m "partial commit to handle a file" "commit is" &&

	changed=$(shit diff-tree --name-only HEAD^ HEAD) &&
	test "$changed" = "commit is"

'

test_expect_success 'partial modification in a subdirectory' '

	test_tick &&
	shit commit -m "partial commit to subdirectory" not &&

	changed=$(shit diff-tree -r --name-only HEAD^ HEAD) &&
	test "$changed" = "not/forbid"

'

test_expect_success 'partial removal' '

	shit rm not/forbid &&
	shit commit -m "partial commit to remove not/forbid" not &&

	changed=$(shit diff-tree -r --name-only HEAD^ HEAD) &&
	test "$changed" = "not/forbid" &&
	remain=$(shit ls-tree -r --name-only HEAD) &&
	test "$remain" = "commit is"

'

test_expect_success 'sign off' '

	>positive &&
	shit add positive &&
	shit commit -s -m "thank you" &&
	shit cat-file commit HEAD >commit.msg &&
	sed -ne "s/Signed-off-by: //p" commit.msg >actual &&
	shit var shit_COMMITTER_IDENT >ident &&
	sed -e "s/>.*/>/" ident >expected &&
	test_cmp expected actual

'

test_expect_success 'commit --trailer with "="' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	EOF
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "replace" as ifexists' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Helped-by: C3 E3
	EOF
	shit -c trailer.ifexists="replace" \
		commit --trailer "Mentored-by: C4 E4" \
		 --trailer "Helped-by: C3 E3" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d"  commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "add" as ifexists' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Reported-by: C3 E3
	Mentored-by: C4 E4
	EOF
	shit -c trailer.ifexists="add" \
		commit --trailer "Reported-by: C3 E3" \
		--trailer "Mentored-by: C4 E4" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d"  commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "donothing" as ifexists' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Reviewed-by: C6 E6
	EOF
	shit -c trailer.ifexists="donothing" \
		commit --trailer "Mentored-by: C5 E5" \
		--trailer "Reviewed-by: C6 E6" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d"  commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "addIfDifferent" as ifexists' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Mentored-by: C5 E5
	EOF
	shit -c trailer.ifexists="addIfDifferent" \
		commit --trailer "Reported-by: C3 E3" \
		--trailer "Mentored-by: C5 E5" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d"  commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "addIfDifferentNeighbor" as ifexists' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Reported-by: C3 E3
	EOF
	shit -c trailer.ifexists="addIfDifferentNeighbor" \
		commit --trailer "Mentored-by: C4 E4" \
		--trailer "Reported-by: C3 E3" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d"  commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "end" as where' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Reported-by: C3 E3
	Mentored-by: C4 E4
	EOF
	shit -c trailer.where="end" \
		commit --trailer "Reported-by: C3 E3" \
		--trailer "Mentored-by: C4 E4" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "start" as where' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C1 E1
	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	EOF
	shit -c trailer.where="start" \
		commit --trailer "Signed-off-by: C O Mitter <committer@example.com>" \
		--trailer "Signed-off-by: C1 E1" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "after" as where' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Mentored-by: C5 E5
	EOF
	shit -c trailer.where="after" \
		commit --trailer "Mentored-by: C4 E4" \
		--trailer "Mentored-by: C5 E5" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "before" as where' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C2 E2
	Mentored-by: C3 E3
	Mentored-by: C4 E4
	EOF
	shit -c trailer.where="before" \
		commit --trailer "Mentored-by: C3 E3" \
		--trailer "Mentored-by: C2 E2" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "donothing" as ifmissing' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Helped-by: C5 E5
	EOF
	shit -c trailer.ifmissing="donothing" \
		commit --trailer "Helped-by: C5 E5" \
		--trailer "Based-by: C6 E6" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and "add" as ifmissing' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Reported-by: C3 E3
	Mentored-by: C4 E4
	Helped-by: C5 E5
	Based-by: C6 E6
	EOF
	shit -c trailer.ifmissing="add" \
		commit --trailer "Helped-by: C5 E5" \
		--trailer "Based-by: C6 E6" \
		--amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c ack.key ' '
	echo "fun" >>file1 &&
	shit add file1 &&
	cat >expected <<-\EOF &&
		hello

		Acked-by: Peff
	EOF
	shit -c trailer.ack.key="Acked-by" \
		commit --trailer "ack = Peff" -m "hello" &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and ":=#" as separators' '
	echo "fun" >>file1 &&
	shit add file1 &&
	cat >expected <<-\EOF &&
		I hate bug

		Bug #42
	EOF
	shit -c trailer.separators=":=#" \
		-c trailer.bug.key="Bug #" \
		commit --trailer "bug = 42" -m "I hate bug" &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with -c and command' '
	trailer_commit_base &&
	cat >expected <<-\EOF &&
	hello

	Signed-off-by: C O Mitter <committer@example.com>
	Signed-off-by: C1 E1
	Helped-by: C2 E2
	Mentored-by: C4 E4
	Reported-by: A U Thor <author@example.com>
	EOF
	shit -c trailer.report.key="Reported-by: " \
		-c trailer.report.ifexists="replace" \
		-c trailer.report.command="NAME=\"\$ARG\"; test -n \"\$NAME\" && \
		shit log --author=\"\$NAME\" -1 --format=\"format:%aN <%aE>\" || true" \
		commit --trailer "report = author" --amend &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer not confused by --- separator' '
	cat >msg <<-\EOF &&
	subject

	body with dashes
	---
	in it
	EOF
	shit commit --allow-empty --trailer="my-trailer: value" -F msg &&
	{
		cat msg &&
		echo &&
		echo "my-trailer: value"
	} >expected &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --trailer with --verbose' '
	cat >msg <<-\EOF &&
	subject

	body
	EOF
	shit_EDITOR=: shit commit --edit -F msg --allow-empty \
		--trailer="my-trailer: value" --verbose &&
	{
		cat msg &&
		echo &&
		echo "my-trailer: value"
	} >expected &&
	shit cat-file commit HEAD >commit.msg &&
	sed -e "1,/^\$/d" commit.msg >actual &&
	test_cmp expected actual
'

test_expect_success 'multiple -m' '

	>negative &&
	shit add negative &&
	shit commit -m "one" -m "two" -m "three" &&
	actual=$(shit cat-file commit HEAD >tmp && sed -e "1,/^\$/d" tmp && rm tmp) &&
	expected=$(test_write_lines "one" "" "two" "" "three") &&
	test "z$actual" = "z$expected"

'

test_expect_success 'verbose' '

	echo minus >negative &&
	shit add negative &&
	shit status -v >raw &&
	sed -ne "/^diff --shit /p" raw >actual &&
	echo "diff --shit a/negative b/negative" >expect &&
	test_cmp expect actual

'

test_expect_success 'verbose respects diff config' '

	test_config diff.noprefix true &&
	shit status -v >actual &&
	grep "diff --shit negative negative" actual
'

mesg_with_comment_and_newlines='
# text

'

test_expect_success 'prepare file with comment line and trailing newlines'  '
	printf "%s" "$mesg_with_comment_and_newlines" >expect
'

test_expect_success 'cleanup commit messages (verbatim option,-t)' '

	echo >>negative &&
	shit commit --cleanup=verbatim --no-status -t expect -a &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_cmp expect actual

'

test_expect_success 'cleanup commit messages (verbatim option,-F)' '

	echo >>negative &&
	shit commit --cleanup=verbatim -F expect -a &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_cmp expect actual

'

test_expect_success 'cleanup commit messages (verbatim option,-m)' '

	echo >>negative &&
	shit commit --cleanup=verbatim -m "$mesg_with_comment_and_newlines" -a &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_cmp expect actual

'

test_expect_success 'cleanup commit messages (whitespace option,-F)' '

	echo >>negative &&
	test_write_lines "" "# text" "" >text &&
	echo "# text" >expect &&
	shit commit --cleanup=whitespace -F text -a &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_cmp expect actual

'

test_expect_success 'cleanup commit messages (scissors option,-F,-e)' '

	echo >>negative &&
	cat >text <<-\EOF &&

	# to be kept

	  # ------------------------ >8 ------------------------
	# to be kept, too
	# ------------------------ >8 ------------------------
	to be removed
	# ------------------------ >8 ------------------------
	to be removed, too
	EOF

	cat >expect <<-\EOF &&
	# to be kept

	  # ------------------------ >8 ------------------------
	# to be kept, too
	EOF
	shit commit --cleanup=scissors -e -F text -a &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_cmp expect actual
'

test_expect_success 'cleanup commit messages (scissors option,-F,-e, scissors on first line)' '

	echo >>negative &&
	cat >text <<-\EOF &&
	# ------------------------ >8 ------------------------
	to be removed
	EOF
	shit commit --cleanup=scissors -e -F text -a --allow-empty-message &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_must_be_empty actual
'

test_expect_success 'cleanup commit messages (strip option,-F)' '

	echo >>negative &&
	test_write_lines "" "# text" "sample" "" >text &&
	echo sample >expect &&
	shit commit --cleanup=strip -F text -a &&
	shit cat-file -p HEAD >raw &&
	sed -e "1,/^\$/d" raw >actual &&
	test_cmp expect actual

'

test_expect_success 'cleanup commit messages (strip option,-F,-e)' '

	echo >>negative &&
	test_write_lines "" "sample" "" >text &&
	shit commit -e -F text -a &&
	head -n 4 .shit/COMMIT_EDITMSG >actual
'

echo "sample

# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit." >expect

test_expect_success 'cleanup commit messages (strip option,-F,-e): output' '
	test_cmp expect actual
'

test_expect_success 'cleanup commit message (fail on invalid cleanup mode option)' '
	test_must_fail shit commit --cleanup=non-existent
'

test_expect_success 'cleanup commit message (fail on invalid cleanup mode configuration)' '
	test_must_fail shit -c commit.cleanup=non-existent commit
'

test_expect_success 'cleanup commit message (no config and no option uses default)' '
	echo content >>file &&
	shit add file &&
	(
	  test_set_editor "$TEST_DIRECTORY"/t7500/add-content-and-comment &&
	  shit commit --no-status
	) &&
	commit_msg_is "commit message"
'

test_expect_success 'cleanup commit message (option overrides default)' '
	echo content >>file &&
	shit add file &&
	(
	  test_set_editor "$TEST_DIRECTORY"/t7500/add-content-and-comment &&
	  shit commit --cleanup=whitespace --no-status
	) &&
	commit_msg_is "commit message # comment"
'

test_expect_success 'cleanup commit message (config overrides default)' '
	echo content >>file &&
	shit add file &&
	(
	  test_set_editor "$TEST_DIRECTORY"/t7500/add-content-and-comment &&
	  shit -c commit.cleanup=whitespace commit --no-status
	) &&
	commit_msg_is "commit message # comment"
'

test_expect_success 'cleanup commit message (option overrides config)' '
	echo content >>file &&
	shit add file &&
	(
	  test_set_editor "$TEST_DIRECTORY"/t7500/add-content-and-comment &&
	  shit -c commit.cleanup=whitespace commit --cleanup=default
	) &&
	commit_msg_is "commit message"
'

test_expect_success 'cleanup commit message (default, -m)' '
	echo content >>file &&
	shit add file &&
	shit commit -m "message #comment " &&
	commit_msg_is "message #comment"
'

test_expect_success 'cleanup commit message (whitespace option, -m)' '
	echo content >>file &&
	shit add file &&
	shit commit --cleanup=whitespace --no-status -m "message #comment " &&
	commit_msg_is "message #comment"
'

test_expect_success 'cleanup commit message (whitespace config, -m)' '
	echo content >>file &&
	shit add file &&
	shit -c commit.cleanup=whitespace commit --no-status -m "message #comment " &&
	commit_msg_is "message #comment"
'

test_expect_success 'message shows author when it is not equal to committer' '
	echo >>negative &&
	shit commit -e -m "sample" -a &&
	test_grep \
	  "^# Author: *A U Thor <author@example.com>\$" \
	  .shit/COMMIT_EDITMSG
'

test_expect_success 'message shows date when it is explicitly set' '
	shit commit --allow-empty -e -m foo --date="2010-01-02T03:04:05" &&
	test_grep \
	  "^# Date: *Sat Jan 2 03:04:05 2010 +0000" \
	  .shit/COMMIT_EDITMSG
'

test_expect_success 'message does not have multiple scissors lines' '
	shit commit --cleanup=scissors -v --allow-empty -e -m foo &&
	test $(grep -c -e "--- >8 ---" .shit/COMMIT_EDITMSG) -eq 1
'

test_expect_success AUTOIDENT 'message shows committer when it is automatic' '

	echo >>negative &&
	(
		sane_unset shit_COMMITTER_EMAIL &&
		sane_unset shit_COMMITTER_NAME &&
		shit commit -e -m "sample" -a
	) &&
	# the ident is calculated from the system, so we cannot
	# check the actual value, only that it is there
	test_grep "^# Committer: " .shit/COMMIT_EDITMSG
'

write_script .shit/FAKE_EDITOR <<EOF
echo editor started >"$(pwd)/.shit/result"
exit 0
EOF

test_expect_success !FAIL_PREREQS,!AUTOIDENT 'do not fire editor when committer is bogus' '
	>.shit/result &&

	echo >>negative &&
	(
		sane_unset shit_COMMITTER_EMAIL &&
		sane_unset shit_COMMITTER_NAME &&
		shit_EDITOR="\"$(pwd)/.shit/FAKE_EDITOR\"" &&
		export shit_EDITOR &&
		test_must_fail shit commit -e -m sample -a
	) &&
	test_must_be_empty .shit/result
'

test_expect_success 'do not fire editor if -m <msg> was given' '
	echo tick >file &&
	shit add file &&
	echo "editor not started" >.shit/result &&
	(shit_EDITOR="\"$(pwd)/.shit/FAKE_EDITOR\"" shit commit -m tick) &&
	test "$(cat .shit/result)" = "editor not started"
'

test_expect_success 'do not fire editor if -m "" was given' '
	echo tock >file &&
	shit add file &&
	echo "editor not started" >.shit/result &&
	(shit_EDITOR="\"$(pwd)/.shit/FAKE_EDITOR\"" \
	 shit commit -m "" --allow-empty-message) &&
	test "$(cat .shit/result)" = "editor not started"
'

test_expect_success 'do not fire editor in the presence of conflicts' '

	shit clean -f &&
	echo f >g &&
	shit add g &&
	shit commit -m "add g" &&
	shit branch second &&
	echo main >g &&
	echo g >h &&
	shit add g h &&
	shit commit -m "modify g and add h" &&
	shit checkout second &&
	echo second >g &&
	shit add g &&
	shit commit -m second &&
	# Must fail due to conflict
	test_must_fail shit cherry-pick -n main &&
	echo "editor not started" >.shit/result &&
	(
		shit_EDITOR="\"$(pwd)/.shit/FAKE_EDITOR\"" &&
		export shit_EDITOR &&
		test_must_fail shit commit
	) &&
	test "$(cat .shit/result)" = "editor not started"
'

write_script .shit/FAKE_EDITOR <<EOF
# kill -TERM command added below.
EOF

test_expect_success EXECKEEPSPID 'a SIGTERM should break locks' '
	echo >>negative &&
	! "$SHELL_PATH" -c '\''
	  echo kill -TERM $$ >>.shit/FAKE_EDITOR
	  shit_EDITOR=.shit/FAKE_EDITOR
	  export shit_EDITOR
	  exec shit commit -a'\'' &&
	test ! -f .shit/index.lock
'

rm -f .shit/MERGE_MSG .shit/COMMIT_EDITMSG
shit reset -q --hard

test_expect_success 'Hand committing of a redundant merge removes dups' '

	shit rev-parse second main >expect &&
	test_must_fail shit merge second main &&
	shit checkout main g &&
	EDITOR=: shit commit -a &&
	shit cat-file commit HEAD >raw &&
	sed -n -e "s/^parent //p" -e "/^$/q" raw >actual &&
	test_cmp expect actual

'

test_expect_success 'A single-liner subject with a token plus colon is not a footer' '

	shit reset --hard &&
	shit commit -s -m "hello: kitty" --allow-empty &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_line_count = 3 actual

'

test_expect_success 'commit -s places sob on third line after two empty lines' '
	shit commit -s --allow-empty --allow-empty-message &&
	cat <<-EOF >expect &&


	Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>

	EOF
	sed -e "/^#/d" -e "s/^:.*//" .shit/COMMIT_EDITMSG >actual &&
	test_cmp expect actual
'

write_script .shit/FAKE_EDITOR <<\EOF
mv "$1" "$1.orig"
(
	echo message
	cat "$1.orig"
) >"$1"
EOF

echo '## Custom template' >template

try_commit () {
	shit reset --hard &&
	echo >>negative &&
	shit_EDITOR=.shit/FAKE_EDITOR shit commit -a $* $use_template &&
	case "$use_template" in
	'')
		test_grep ! "^## Custom template" .shit/COMMIT_EDITMSG ;;
	*)
		test_grep "^## Custom template" .shit/COMMIT_EDITMSG ;;
	esac
}

try_commit_status_combo () {

	test_expect_success 'commit' '
		try_commit "" &&
		test_grep "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit --status' '
		try_commit --status &&
		test_grep "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit --no-status' '
		try_commit --no-status &&
		test_grep ! "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit with commit.status = yes' '
		test_config commit.status yes &&
		try_commit "" &&
		test_grep "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit with commit.status = no' '
		test_config commit.status no &&
		try_commit "" &&
		test_grep ! "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit --status with commit.status = yes' '
		test_config commit.status yes &&
		try_commit --status &&
		test_grep "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit --no-status with commit.status = yes' '
		test_config commit.status yes &&
		try_commit --no-status &&
		test_grep ! "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit --status with commit.status = no' '
		test_config commit.status no &&
		try_commit --status &&
		test_grep "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

	test_expect_success 'commit --no-status with commit.status = no' '
		test_config commit.status no &&
		try_commit --no-status &&
		test_grep ! "^# Changes to be committed:" .shit/COMMIT_EDITMSG
	'

}

try_commit_status_combo

use_template="-t template"

try_commit_status_combo

test_expect_success 'commit --status with custom comment character' '
	test_config core.commentchar ";" &&
	try_commit --status &&
	test_grep "^; Changes to be committed:" .shit/COMMIT_EDITMSG
'

test_expect_success 'switch core.commentchar' '
	test_commit "#foo" foo &&
	shit_EDITOR=.shit/FAKE_EDITOR shit -c core.commentChar=auto commit --amend &&
	test_grep "^; Changes to be committed:" .shit/COMMIT_EDITMSG
'

test_expect_success 'switch core.commentchar but out of options' '
	cat >text <<\EOF &&
# 1
; 2
@ 3
! 4
$ 5
% 6
^ 7
& 8
| 9
: 10
EOF
	shit commit --amend -F text &&
	(
		test_set_editor .shit/FAKE_EDITOR &&
		test_must_fail shit -c core.commentChar=auto commit --amend
	)
'

test_done
