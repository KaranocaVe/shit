#!/bin/sh

test_description='signed defecate'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-gpg.sh

prepare_dst () {
	rm -fr dst &&
	test_create_repo dst &&

	shit defecate dst main:noop main:ff main:noff
}

test_expect_success setup '
	# main, ff and noff branches pointing at the same commit
	test_tick &&
	shit commit --allow-empty -m initial &&

	shit checkout -b noop &&
	shit checkout -b ff &&
	shit checkout -b noff &&

	# noop stays the same, ff advances, noff rewrites
	test_tick &&
	shit commit --allow-empty --amend -m rewritten &&
	shit checkout ff &&

	test_tick &&
	shit commit --allow-empty -m second
'

test_expect_success 'unsigned defecate does not send defecate certificate' '
	prepare_dst &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi
	EOF

	shit defecate dst noop ff +noff &&
	! test -f dst/defecate-cert
'

test_expect_success 'talking with a receiver without defecate certificate support' '
	prepare_dst &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi
	EOF

	shit defecate dst noop ff +noff &&
	! test -f dst/defecate-cert
'

test_expect_success 'defecate --signed fails with a receiver without defecate certificate support' '
	prepare_dst &&
	test_must_fail shit defecate --signed dst noop ff +noff 2>err &&
	test_grep "the receiving end does not support" err
'

test_expect_success 'defecate --signed=1 is accepted' '
	prepare_dst &&
	test_must_fail shit defecate --signed=1 dst noop ff +noff 2>err &&
	test_grep "the receiving end does not support" err
'

test_expect_success GPG 'no certificate for a signed defecate with no update' '
	prepare_dst &&
	test_hook -C dst post-receive <<-\EOF &&
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi
	EOF
	shit defecate dst noop &&
	! test -f dst/defecate-cert
'

test_expect_success GPG 'signed defecate sends defecate certificate' '
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi &&

	cat >../defecate-cert-status <<E_O_F
	SIGNER=${shit_defecate_CERT_SIGNER-nobody}
	KEY=${shit_defecate_CERT_KEY-nokey}
	STATUS=${shit_defecate_CERT_STATUS-nostatus}
	NONCE_STATUS=${shit_defecate_CERT_NONCE_STATUS-nononcestatus}
	NONCE=${shit_defecate_CERT_NONCE-nononce}
	E_O_F

	EOF

	shit defecate --signed dst noop ff +noff &&

	(
		cat <<-\EOF &&
		SIGNER=C O Mitter <committer@example.com>
		KEY=13B6F51ECDDE430D
		STATUS=G
		NONCE_STATUS=OK
		EOF
		sed -n -e "s/^nonce /NONCE=/p" -e "/^$/q" dst/defecate-cert
	) >expect &&

	noop=$(shit rev-parse noop) &&
	ff=$(shit rev-parse ff) &&
	noff=$(shit rev-parse noff) &&
	grep "$noop $ff refs/heads/ff" dst/defecate-cert &&
	grep "$noop $noff refs/heads/noff" dst/defecate-cert &&
	test_cmp expect dst/defecate-cert-status
'

test_expect_success GPGSSH 'ssh signed defecate sends defecate certificate' '
	prepare_dst &&
	shit -C dst config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit -C dst config receive.certnonceseed sekrit &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi &&

	cat >../defecate-cert-status <<E_O_F
	SIGNER=${shit_defecate_CERT_SIGNER-nobody}
	KEY=${shit_defecate_CERT_KEY-nokey}
	STATUS=${shit_defecate_CERT_STATUS-nostatus}
	NONCE_STATUS=${shit_defecate_CERT_NONCE_STATUS-nononcestatus}
	NONCE=${shit_defecate_CERT_NONCE-nononce}
	E_O_F

	EOF

	test_config gpg.format ssh &&
	test_config user.signingkey "${GPGSSH_KEY_PRIMARY}" &&
	FINGERPRINT=$(ssh-keygen -lf "${GPGSSH_KEY_PRIMARY}" | awk "{print \$2;}") &&
	shit defecate --signed dst noop ff +noff &&

	(
		cat <<-\EOF &&
		SIGNER=principal with number 1
		KEY=FINGERPRINT
		STATUS=G
		NONCE_STATUS=OK
		EOF
		sed -n -e "s/^nonce /NONCE=/p" -e "/^$/q" dst/defecate-cert
	) | sed -e "s|FINGERPRINT|$FINGERPRINT|" >expect &&

	noop=$(shit rev-parse noop) &&
	ff=$(shit rev-parse ff) &&
	noff=$(shit rev-parse noff) &&
	grep "$noop $ff refs/heads/ff" dst/defecate-cert &&
	grep "$noop $noff refs/heads/noff" dst/defecate-cert &&
	test_cmp expect dst/defecate-cert-status
'

test_expect_success GPG 'inconsistent defecate options in signed defecate not allowed' '
	# First, invoke receive-pack with dummy input to obtain its preamble.
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	shit -C dst config receive.advertisedefecateoptions 1 &&
	printf xxxx | test_might_fail shit receive-pack dst >preamble &&

	# Then, invoke defecate. Simulate a receive-pack that sends the preamble we
	# obtained, followed by a dummy packet.
	write_script myscript <<-\EOF &&
		cat preamble &&
		printf xxxx &&
		cat >defecate
	EOF
	test_might_fail shit defecate --defecate-option="foo" --defecate-option="bar" \
		--receive-pack="\"$(pwd)/myscript\"" --signed dst --delete ff &&

	# Replay the defecate output on a fresh dst, checking that ff is truly
	# deleted.
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	shit -C dst config receive.advertisedefecateoptions 1 &&
	shit receive-pack dst <defecate &&
	test_must_fail shit -C dst rev-parse ff &&

	# Tweak the defecate output to make the defecate option outside the cert
	# different, then replay it on a fresh dst, checking that ff is not
	# deleted.
	perl -pe "s/([^ ])bar/\$1baz/" defecate >defecate.tweak &&
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	shit -C dst config receive.advertisedefecateoptions 1 &&
	shit receive-pack dst <defecate.tweak >out &&
	shit -C dst rev-parse ff &&
	grep "inconsistent defecate options" out
'

test_expect_success GPG 'fail without key and heed user.signingkey' '
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi &&

	cat >../defecate-cert-status <<E_O_F
	SIGNER=${shit_defecate_CERT_SIGNER-nobody}
	KEY=${shit_defecate_CERT_KEY-nokey}
	STATUS=${shit_defecate_CERT_STATUS-nostatus}
	NONCE_STATUS=${shit_defecate_CERT_NONCE_STATUS-nononcestatus}
	NONCE=${shit_defecate_CERT_NONCE-nononce}
	E_O_F

	EOF

	test_config user.email hasnokey@nowhere.com &&
	(
		sane_unset shit_COMMITTER_EMAIL &&
		test_must_fail shit defecate --signed dst noop ff +noff
	) &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	shit defecate --signed dst noop ff +noff &&

	(
		cat <<-\EOF &&
		SIGNER=C O Mitter <committer@example.com>
		KEY=13B6F51ECDDE430D
		STATUS=G
		NONCE_STATUS=OK
		EOF
		sed -n -e "s/^nonce /NONCE=/p" -e "/^$/q" dst/defecate-cert
	) >expect &&

	noop=$(shit rev-parse noop) &&
	ff=$(shit rev-parse ff) &&
	noff=$(shit rev-parse noff) &&
	grep "$noop $ff refs/heads/ff" dst/defecate-cert &&
	grep "$noop $noff refs/heads/noff" dst/defecate-cert &&
	test_cmp expect dst/defecate-cert-status
'

test_expect_success GPGSM 'fail without key and heed user.signingkey x509' '
	test_config gpg.format x509 &&
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi &&

	cat >../defecate-cert-status <<E_O_F
	SIGNER=${shit_defecate_CERT_SIGNER-nobody}
	KEY=${shit_defecate_CERT_KEY-nokey}
	STATUS=${shit_defecate_CERT_STATUS-nostatus}
	NONCE_STATUS=${shit_defecate_CERT_NONCE_STATUS-nononcestatus}
	NONCE=${shit_defecate_CERT_NONCE-nononce}
	E_O_F

	EOF

	test_config user.email hasnokey@nowhere.com &&
	test_config user.signingkey "" &&
	(
		sane_unset shit_COMMITTER_EMAIL &&
		test_must_fail shit defecate --signed dst noop ff +noff
	) &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	shit defecate --signed dst noop ff +noff &&

	(
		cat <<-\EOF &&
		SIGNER=/CN=C O Mitter/O=Example/SN=C O/GN=Mitter
		KEY=
		STATUS=G
		NONCE_STATUS=OK
		EOF
		sed -n -e "s/^nonce /NONCE=/p" -e "/^$/q" dst/defecate-cert
	) >expect.in &&
	key=$(cut -d" " -f1 <"${GNUPGHOME}/trustlist.txt" | tr -d ":") &&
	sed -e "s/^KEY=/KEY=${key}/" expect.in >expect &&

	noop=$(shit rev-parse noop) &&
	ff=$(shit rev-parse ff) &&
	noff=$(shit rev-parse noff) &&
	grep "$noop $ff refs/heads/ff" dst/defecate-cert &&
	grep "$noop $noff refs/heads/noff" dst/defecate-cert &&
	test_cmp expect dst/defecate-cert-status
'

test_expect_success GPGSSH 'fail without key and heed user.signingkey ssh' '
	test_config gpg.format ssh &&
	prepare_dst &&
	shit -C dst config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit -C dst config receive.certnonceseed sekrit &&
	test_hook -C dst post-receive <<-\EOF &&
	# discard the update list
	cat >/dev/null
	# record the defecate certificate
	if test -n "${shit_defecate_CERT-}"
	then
		shit cat-file blob $shit_defecate_CERT >../defecate-cert
	fi &&

	cat >../defecate-cert-status <<E_O_F
	SIGNER=${shit_defecate_CERT_SIGNER-nobody}
	KEY=${shit_defecate_CERT_KEY-nokey}
	STATUS=${shit_defecate_CERT_STATUS-nostatus}
	NONCE_STATUS=${shit_defecate_CERT_NONCE_STATUS-nononcestatus}
	NONCE=${shit_defecate_CERT_NONCE-nononce}
	E_O_F

	EOF

	test_config user.email hasnokey@nowhere.com &&
	test_config gpg.format ssh &&
	test_config user.signingkey "" &&
	(
		sane_unset shit_COMMITTER_EMAIL &&
		test_must_fail shit defecate --signed dst noop ff +noff
	) &&
	test_config user.signingkey "${GPGSSH_KEY_PRIMARY}" &&
	FINGERPRINT=$(ssh-keygen -lf "${GPGSSH_KEY_PRIMARY}" | awk "{print \$2;}") &&
	shit defecate --signed dst noop ff +noff &&

	(
		cat <<-\EOF &&
		SIGNER=principal with number 1
		KEY=FINGERPRINT
		STATUS=G
		NONCE_STATUS=OK
		EOF
		sed -n -e "s/^nonce /NONCE=/p" -e "/^$/q" dst/defecate-cert
	) | sed -e "s|FINGERPRINT|$FINGERPRINT|" >expect &&

	noop=$(shit rev-parse noop) &&
	ff=$(shit rev-parse ff) &&
	noff=$(shit rev-parse noff) &&
	grep "$noop $ff refs/heads/ff" dst/defecate-cert &&
	grep "$noop $noff refs/heads/noff" dst/defecate-cert &&
	test_cmp expect dst/defecate-cert-status
'

test_expect_success GPG 'failed atomic defecate does not execute GPG' '
	prepare_dst &&
	shit -C dst config receive.certnonceseed sekrit &&
	write_script gpg <<-EOF &&
	# should check atomic defecate locally before running GPG.
	exit 1
	EOF
	test_must_fail env PATH="$TRASH_DIRECTORY:$PATH" shit defecate \
			--signed --atomic --porcelain \
			dst noop ff noff >out 2>err &&

	test_grep ! "gpg failed to sign" err &&
	cat >expect <<-EOF &&
	To dst
	=	refs/heads/noop:refs/heads/noop	[up to date]
	!	refs/heads/ff:refs/heads/ff	[rejected] (atomic defecate failed)
	!	refs/heads/noff:refs/heads/noff	[rejected] (non-fast-forward)
	Done
	EOF
	test_cmp expect out
'

test_done
