#!/bin/sh
#
# Copyright (c) 2006, Junio C Hamano
#

test_description='fmt-merge-msg test'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success setup '
	echo one >one &&
	shit add one &&
	test_tick &&
	shit commit -m "Initial" &&

	shit clone . remote &&

	echo uno >one &&
	echo dos >two &&
	shit add two &&
	test_tick &&
	shit commit -a -m "Second" &&

	shit checkout -b left &&

	echo "c1" >one &&
	test_tick &&
	shit commit -a -m "Common #1" &&

	echo "c2" >one &&
	test_tick &&
	shit commit -a -m "Common #2" &&

	shit branch right &&

	echo "l3" >two &&
	test_tick &&
	shit_COMMITTER_NAME="Another Committer" \
	shit_AUTHOR_NAME="Another Author" shit commit -a -m "Left #3" &&

	echo "l4" >two &&
	test_tick &&
	shit_COMMITTER_NAME="Another Committer" \
	shit_AUTHOR_NAME="Another Author" shit commit -a -m "Left #4" &&

	echo "l5" >two &&
	test_tick &&
	shit_COMMITTER_NAME="Another Committer" \
	shit_AUTHOR_NAME="Another Author" shit commit -a -m "Left #5" &&
	shit tag tag-l5 &&

	shit checkout right &&

	echo "r3" >three &&
	shit add three &&
	test_tick &&
	shit commit -a -m "Right #3" &&
	shit tag tag-r3 &&

	echo "r4" >three &&
	test_tick &&
	shit commit -a -m "Right #4" &&

	echo "r5" >three &&
	test_tick &&
	shit commit -a -m "Right #5" &&

	shit checkout -b long &&
	test_commit_bulk --start=0 --message=%s --filename=one 30 &&

	shit show-branch &&

	apos="'\''"
'

test_expect_success GPG 'set up a signed tag' '
	shit tag -s -m signed-tag-msg signed-good-tag left
'

test_expect_success GPGSSH 'created ssh signed commit and tag' '
	test_config gpg.format ssh &&
	shit checkout -b signed-ssh &&
	touch file &&
	shit add file &&
	shit commit -m "ssh signed" -S"${GPGSSH_KEY_PRIMARY}" &&
	shit tag -s -u"${GPGSSH_KEY_PRIMARY}" -m signed-ssh-tag-msg signed-good-ssh-tag left &&
	shit tag -s -u"${GPGSSH_KEY_UNTRUSTED}" -m signed-ssh-tag-msg-untrusted signed-untrusted-ssh-tag left
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'create signed tags with keys having defined lifetimes' '
	test_when_finished "test_unconfig commit.gpgsign" &&
	test_config gpg.format ssh &&
	shit checkout -b signed-expiry-ssh &&
	touch file &&
	shit add file &&

	echo expired >file && test_tick && shit commit -a -m expired -S"${GPGSSH_KEY_EXPIRED}" &&
	shit tag -s -u "${GPGSSH_KEY_EXPIRED}" -m expired-signed expired-signed &&

	echo notyetvalid >file && test_tick && shit commit -a -m notyetvalid -S"${GPGSSH_KEY_NOTYETVALID}" &&
	shit tag -s -u "${GPGSSH_KEY_NOTYETVALID}" -m notyetvalid-signed notyetvalid-signed &&

	echo timeboxedvalid >file && test_tick && shit commit -a -m timeboxedvalid -S"${GPGSSH_KEY_TIMEBOXEDVALID}" &&
	shit tag -s -u "${GPGSSH_KEY_TIMEBOXEDVALID}" -m timeboxedvalid-signed timeboxedvalid-signed &&

	echo timeboxedinvalid >file && test_tick && shit commit -a -m timeboxedinvalid -S"${GPGSSH_KEY_TIMEBOXEDINVALID}" &&
	shit tag -s -u "${GPGSSH_KEY_TIMEBOXEDINVALID}" -m timeboxedinvalid-signed timeboxedinvalid-signed
'

test_expect_success 'message for merging local branch' '
	echo "Merge branch ${apos}left${apos}" >expected &&

	shit checkout main &&
	shit fetch . left &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success GPG 'message for merging local tag signed by good key' '
	shit checkout main &&
	shit fetch . signed-good-tag &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}signed-good-tag${apos}" actual &&
	grep "^signed-tag-msg" actual &&
	grep "^# gpg: Signature made" actual &&
	grep "^# gpg: Good signature from" actual
'

test_expect_success GPG 'message for merging local tag signed by unknown key' '
	shit checkout main &&
	shit fetch . signed-good-tag &&
	GNUPGHOME=. shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}signed-good-tag${apos}" actual &&
	grep "^signed-tag-msg" actual &&
	grep "^# gpg: Signature made" actual &&
	grep -E "^# gpg: Can${apos}t check signature: (public key not found|No public key)" actual
'

test_expect_success GPGSSH 'message for merging local tag signed by good ssh key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit checkout main &&
	shit fetch . signed-good-ssh-tag &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}signed-good-ssh-tag${apos}" actual &&
	grep "^signed-ssh-tag-msg" actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
	! grep "${GPGSSH_BAD_SIGNATURE}" actual
'

test_expect_success GPGSSH 'message for merging local tag signed by unknown ssh key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit checkout main &&
	shit fetch . signed-untrusted-ssh-tag &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}signed-untrusted-ssh-tag${apos}" actual &&
	grep "^signed-ssh-tag-msg-untrusted" actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_UNTRUSTED}" actual &&
	! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
	grep "${GPGSSH_KEY_NOT_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'message for merging local tag signed by expired ssh key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit checkout main &&
	shit fetch . expired-signed &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}expired-signed${apos}" actual &&
	grep "^expired-signed" actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'message for merging local tag signed by not yet valid ssh key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit checkout main &&
	shit fetch . notyetvalid-signed &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}notyetvalid-signed${apos}" actual &&
	grep "^notyetvalid-signed" actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'message for merging local tag signed by valid timeboxed ssh key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit checkout main &&
	shit fetch . timeboxedvalid-signed &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}timeboxedvalid-signed${apos}" actual &&
	grep "^timeboxedvalid-signed" actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
	! grep "${GPGSSH_BAD_SIGNATURE}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'message for merging local tag signed by invalid timeboxed ssh key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit checkout main &&
	shit fetch . timeboxedinvalid-signed &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	grep "^Merge tag ${apos}timeboxedinvalid-signed${apos}" actual &&
	grep "^timeboxedinvalid-signed" actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success 'message for merging external branch' '
	echo "Merge branch ${apos}left${apos} of $(pwd)" >expected &&

	shit checkout main &&
	shit fetch "$(pwd)" left &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '[merge] summary/log configuration' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	test_config merge.log true &&
	test_unconfig merge.summary &&

	shit checkout main &&
	test_tick &&
	shit fetch . left &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual1 &&

	test_unconfig merge.log &&
	test_config merge.summary true &&

	shit checkout main &&
	test_tick &&
	shit fetch . left &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual2 &&

	test_cmp expected actual1 &&
	test_cmp expected actual2
'

test_expect_success 'setup FETCH_HEAD' '
	shit checkout main &&
	test_tick &&
	shit fetch . left
'

test_expect_success 'merge.log=3 limits shortlog length' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left: (5 commits)
	  Left #5
	  Left #4
	  Left #3
	  ...
	EOF

	shit -c merge.log=3 fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge.log=5 shows all 5 commits' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	shit -c merge.log=5 fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--log=5 with custom comment character' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}

	x By Another Author (3) and A U Thor (2)
	x Via Another Committer
	* left:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	shit -c core.commentchar="x" fmt-merge-msg --log=5 <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge.log=0 disables shortlog' '
	echo "Merge branch ${apos}left${apos}" >expected &&
	shit -c merge.log=0 fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--log=3 limits shortlog length' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left: (5 commits)
	  Left #5
	  Left #4
	  Left #3
	  ...
	EOF

	shit fmt-merge-msg --log=3 <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--log=5 shows all 5 commits' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	shit fmt-merge-msg --log=5 <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--no-log disables shortlog' '
	echo "Merge branch ${apos}left${apos}" >expected &&
	shit fmt-merge-msg --no-log <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--log=0 disables shortlog' '
	echo "Merge branch ${apos}left${apos}" >expected &&
	shit fmt-merge-msg --no-log <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'fmt-merge-msg -m' '
	echo "Sync with left" >expected &&
	cat >expected.log <<-EOF &&
	Sync with left

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* ${apos}left${apos} of $(pwd):
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	test_unconfig merge.log &&
	test_unconfig merge.summary &&
	shit checkout main &&
	shit fetch "$(pwd)" left &&
	shit fmt-merge-msg -m "Sync with left" <.shit/FETCH_HEAD >actual &&
	shit fmt-merge-msg --log -m "Sync with left" \
					<.shit/FETCH_HEAD >actual.log &&
	test_config merge.log true &&
	shit fmt-merge-msg -m "Sync with left" \
					<.shit/FETCH_HEAD >actual.log-config &&
	shit fmt-merge-msg --no-log -m "Sync with left" \
					<.shit/FETCH_HEAD >actual.nolog &&

	test_cmp expected actual &&
	test_cmp expected.log actual.log &&
	test_cmp expected.log actual.log-config &&
	test_cmp expected actual.nolog
'

test_expect_success 'setup: expected shortlog for two branches' '
	cat >expected <<-EOF
	Merge branches ${apos}left${apos} and ${apos}right${apos}

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1

	* right:
	  Right #5
	  Right #4
	  Right #3
	  Common #2
	  Common #1
	EOF
'

test_expect_success 'shortlog for two branches' '
	test_config merge.log true &&
	test_unconfig merge.summary &&
	shit checkout main &&
	test_tick &&
	shit fetch . left right &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual1 &&

	test_unconfig merge.log &&
	test_config merge.summary true &&
	shit checkout main &&
	test_tick &&
	shit fetch . left right &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual2 &&

	test_config merge.log yes &&
	test_unconfig merge.summary &&
	shit checkout main &&
	test_tick &&
	shit fetch . left right &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual3 &&

	test_unconfig merge.log &&
	test_config merge.summary yes &&
	shit checkout main &&
	test_tick &&
	shit fetch . left right &&
	shit fmt-merge-msg <.shit/FETCH_HEAD >actual4 &&

	test_cmp expected actual1 &&
	test_cmp expected actual2 &&
	test_cmp expected actual3 &&
	test_cmp expected actual4
'

test_expect_success 'merge-msg -F' '
	test_unconfig merge.log &&
	test_config merge.summary yes &&
	shit checkout main &&
	test_tick &&
	shit fetch . left right &&
	shit fmt-merge-msg -F .shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge-msg -F in subdirectory' '
	test_unconfig merge.log &&
	test_config merge.summary yes &&
	shit checkout main &&
	test_tick &&
	shit fetch . left right &&
	mkdir sub &&
	cp .shit/FETCH_HEAD sub/FETCH_HEAD &&
	(
		cd sub &&
		shit fmt-merge-msg -F FETCH_HEAD >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'merge-msg with nothing to merge' '
	test_unconfig merge.log &&
	test_config merge.summary yes &&

	(
		cd remote &&
		shit checkout -b unrelated &&
		test_tick &&
		shit fetch origin &&
		shit fmt-merge-msg <.shit/FETCH_HEAD >../actual
	) &&

	test_must_be_empty actual
'

test_expect_success 'merge-msg tag' '
	cat >expected <<-EOF &&
	Merge tag ${apos}tag-r3${apos}

	* tag ${apos}tag-r3${apos}:
	  Right #3
	  Common #2
	  Common #1
	EOF

	test_unconfig merge.log &&
	test_config merge.summary yes &&

	shit checkout main &&
	test_tick &&
	shit fetch . tag tag-r3 &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge-msg two tags' '
	cat >expected <<-EOF &&
	Merge tags ${apos}tag-r3${apos} and ${apos}tag-l5${apos}

	* tag ${apos}tag-r3${apos}:
	  Right #3
	  Common #2
	  Common #1

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* tag ${apos}tag-l5${apos}:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	test_unconfig merge.log &&
	test_config merge.summary yes &&

	shit checkout main &&
	test_tick &&
	shit fetch . tag tag-r3 tag tag-l5 &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge-msg tag and branch' '
	cat >expected <<-EOF &&
	Merge branch ${apos}left${apos}, tag ${apos}tag-r3${apos}

	* tag ${apos}tag-r3${apos}:
	  Right #3
	  Common #2
	  Common #1

	# By Another Author (3) and A U Thor (2)
	# Via Another Committer
	* left:
	  Left #5
	  Left #4
	  Left #3
	  Common #2
	  Common #1
	EOF

	test_unconfig merge.log &&
	test_config merge.summary yes &&

	shit checkout main &&
	test_tick &&
	shit fetch . tag tag-r3 left &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge-msg lots of commits' '
	{
		cat <<-EOF &&
		Merge branch ${apos}long${apos}

		* long: (35 commits)
		EOF

		i=29 &&
		while test $i -gt 9
		do
			echo "  $i" &&
			i=$(($i-1)) || return 1
		done &&
		echo "  ..."
	} >expected &&

	test_config merge.summary yes &&

	shit checkout main &&
	test_tick &&
	shit fetch . long &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'merge-msg with "merging" an annotated tag' '
	test_config merge.log true &&

	shit checkout main^0 &&
	shit commit --allow-empty -m "One step ahead" &&
	shit tag -a -m "An annotated one" annote HEAD &&

	shit checkout main &&
	shit fetch . annote &&

	shit fmt-merge-msg <.shit/FETCH_HEAD >actual &&
	{
		cat <<-\EOF
		Merge tag '\''annote'\''

		An annotated one

		* tag '\''annote'\'':
		  One step ahead
		EOF
	} >expected &&
	test_cmp expected actual &&

	test_when_finished "shit reset --hard" &&
	annote=$(shit rev-parse annote) &&
	shit merge --no-commit --no-ff $annote &&
	{
		cat <<-EOF
		Merge tag '\''$annote'\''

		An annotated one

		* tag '\''$annote'\'':
		  One step ahead
		EOF
	} >expected &&
	test_cmp expected .shit/MERGE_MSG
'

test_expect_success 'merge --into-name=<name>' '
	test_when_finished "shit checkout main" &&
	shit checkout -B side main &&
	shit commit --allow-empty -m "One step ahead" &&

	shit checkout --detach main &&
	shit merge --no-ff side &&
	shit show -s --format="%s" >full.0 &&
	head -n1 full.0 >actual &&
	# expect that HEAD is shown as-is
	grep -e "Merge branch .side. into HEAD$" actual &&

	shit reset --hard main &&
	shit merge --no-ff --into-name=main side &&
	shit show -s --format="%s" >full.1 &&
	head -n1 full.1 >actual &&
	# expect that we pretend to be merging to main, that is suppressed
	grep -e "Merge branch .side.$" actual &&

	shit checkout -b throwaway main &&
	shit merge --no-ff --into-name=main side &&
	shit show -s --format="%s" >full.2 &&
	head -n1 full.2 >actual &&
	# expect that we pretend to be merging to main, that is suppressed
	grep -e "Merge branch .side.$" actual
'

test_expect_success 'merge.suppressDest configuration' '
	test_when_finished "shit checkout main" &&
	shit checkout -B side main &&
	shit commit --allow-empty -m "One step ahead" &&
	shit checkout main &&
	shit fetch . side &&

	shit -c merge.suppressDest="" fmt-merge-msg <.shit/FETCH_HEAD >full.1 &&
	head -n1 full.1 >actual &&
	grep -e "Merge branch .side. into main" actual &&

	shit -c merge.suppressDest="mast" fmt-merge-msg <.shit/FETCH_HEAD >full.2 &&
	head -n1 full.2 >actual &&
	grep -e "Merge branch .side. into main$" actual &&

	shit -c merge.suppressDest="ma?*[rn]" fmt-merge-msg <.shit/FETCH_HEAD >full.3 &&
	head -n1 full.3 >actual &&
	grep -e "Merge branch .side." actual &&
	! grep -e " into main$" actual &&

	shit checkout --detach HEAD &&
	shit -c merge.suppressDest="main" fmt-merge-msg <.shit/FETCH_HEAD >full.4 &&
	head -n1 full.4 >actual &&
	grep -e "Merge branch .side. into HEAD$" actual &&

	shit -c merge.suppressDest="main" fmt-merge-msg \
		--into-name=main <.shit/FETCH_HEAD >full.5 &&
	head -n1 full.5 >actual &&
	grep -e "Merge branch .side." actual &&
	! grep -e " into main$" actual &&
	! grep -e " into HEAD$" actual
'

test_done
