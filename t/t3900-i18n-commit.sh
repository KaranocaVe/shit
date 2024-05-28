#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='commit and log output encodings'

. ./test-lib.sh

compare_with () {
	shit show -s $1 | sed -e '1,/^$/d' -e 's/^    //' >current &&
	case "$3" in
	'')
		test_cmp "$2" current ;;
	?*)
		iconv -f "$3" -t UTF-8 >current.utf8 <current &&
		iconv -f "$3" -t UTF-8 >expect.utf8 <"$2" &&
		test_cmp expect.utf8 current.utf8
		;;
	esac
}

test_expect_success setup '
	: >F &&
	shit add F &&
	T=$(shit write-tree) &&
	C=$(shit commit-tree $T <"$TEST_DIRECTORY"/t3900/1-UTF-8.txt) &&
	shit update-ref HEAD $C &&
	shit tag C0
'

test_expect_success 'no encoding header for base case' '
	E=$(shit cat-file commit C0 | sed -ne "s/^encoding //p") &&
	test z = "z$E"
'

test_expect_success 'UTF-16 refused because of NULs' '
	echo UTF-16 >F &&
	test_must_fail shit commit -a -F "$TEST_DIRECTORY"/t3900/UTF-16.txt
'

test_expect_success 'UTF-8 invalid characters refused' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	echo "UTF-8 characters" >F &&
	printf "Commit message\n\nInvalid surrogate:\355\240\200\n" \
		>"$HOME/invalid" &&
	shit commit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_grep "did not conform" "$HOME"/stderr
'

test_expect_success 'UTF-8 overlong sequences rejected' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	rm -f "$HOME/stderr" "$HOME/invalid" &&
	echo "UTF-8 overlong" >F &&
	printf "\340\202\251ommit message\n\nThis is not a space:\300\240\n" \
		>"$HOME/invalid" &&
	shit commit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_grep "did not conform" "$HOME"/stderr
'

test_expect_success 'UTF-8 non-characters refused' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	echo "UTF-8 non-character 1" >F &&
	printf "Commit message\n\nNon-character:\364\217\277\276\n" \
		>"$HOME/invalid" &&
	shit commit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_grep "did not conform" "$HOME"/stderr
'

test_expect_success 'UTF-8 non-characters refused' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	echo "UTF-8 non-character 2." >F &&
	printf "Commit message\n\nNon-character:\357\267\220\n" \
		>"$HOME/invalid" &&
	shit commit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_grep "did not conform" "$HOME"/stderr
'

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "$H setup" '
		shit config i18n.commitencoding $H &&
		shit checkout -b $H C0 &&
		echo $H >F &&
		shit commit -a -F "$TEST_DIRECTORY"/t3900/$H.txt
	'
done

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "check encoding header for $H" '
		E=$(shit cat-file commit '$H' | sed -ne "s/^encoding //p") &&
		test "z$E" = "z'$H'"
	'
done

test_expect_success 'config to remove customization' '
	shit config --unset-all i18n.commitencoding &&
	if Z=$(shit config --get-all i18n.commitencoding)
	then
		echo Oops, should have failed.
		false
	else
		test z = "z$Z"
	fi &&
	shit config i18n.commitencoding UTF-8
'

test_expect_success 'ISO8859-1 should be shown in UTF-8 now' '
	compare_with ISO8859-1 "$TEST_DIRECTORY"/t3900/1-UTF-8.txt
'

for H in eucJP ISO-2022-JP
do
	test_expect_success "$H should be shown in UTF-8 now" '
		compare_with '$H' "$TEST_DIRECTORY"/t3900/2-UTF-8.txt
	'
done

test_expect_success 'config to add customization' '
	shit config --unset-all i18n.commitencoding &&
	if Z=$(shit config --get-all i18n.commitencoding)
	then
		echo Oops, should have failed.
		false
	else
		test z = "z$Z"
	fi
'

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "$H should be shown in itself now" '
		shit config i18n.commitencoding '$H' &&
		compare_with '$H' "$TEST_DIRECTORY"/t3900/'$H'.txt
	'
done

test_expect_success 'config to tweak customization' '
	shit config i18n.logoutputencoding UTF-8
'

test_expect_success 'ISO8859-1 should be shown in UTF-8 now' '
	compare_with ISO8859-1 "$TEST_DIRECTORY"/t3900/1-UTF-8.txt
'

for H in eucJP ISO-2022-JP
do
	test_expect_success "$H should be shown in UTF-8 now" '
		compare_with '$H' "$TEST_DIRECTORY"/t3900/2-UTF-8.txt
	'
done

for J in eucJP ISO-2022-JP
do
	if test "$J" = ISO-2022-JP
	then
		ICONV=$J
	else
		ICONV=
	fi
	shit config i18n.logoutputencoding $J
	for H in eucJP ISO-2022-JP
	do
		test_expect_success "$H should be shown in $J now" '
			compare_with '$H' "$TEST_DIRECTORY"/t3900/'$J'.txt $ICONV
		'
	done
done

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "No conversion with $H" '
		compare_with "--encoding=none '$H'" "$TEST_DIRECTORY"/t3900/'$H'.txt
	'
done

test_commit_autosquash_flags () {
	H=$1
	flag=$2
	test_expect_success "commit --$flag with $H encoding" '
		shit config i18n.commitencoding $H &&
		shit checkout -b $H-$flag C0 &&
		echo $H >>F &&
		shit commit -a -F "$TEST_DIRECTORY"/t3900/$H.txt &&
		test_tick &&
		echo intermediate stuff >>G &&
		shit add G &&
		shit commit -a -m "intermediate commit" &&
		test_tick &&
		echo $H $flag >>F &&
		shit commit -a --$flag HEAD~1 &&
		E=$(shit cat-file commit '$H-$flag' |
			sed -ne "s/^encoding //p") &&
		test "z$E" = "z$H" &&
		shit config --unset-all i18n.commitencoding &&
		shit rebase --autosquash -i HEAD^^^ &&
		shit log --oneline >actual &&
		test_line_count = 3 actual
	'
}

test_commit_autosquash_flags eucJP fixup

test_commit_autosquash_flags ISO-2022-JP squash

test_commit_autosquash_multi_encoding () {
	flag=$1
	old=$2
	new=$3
	msg=$4
	test_expect_success "commit --$flag into $old from $new" '
		shit checkout -b $flag-$old-$new C0 &&
		shit config i18n.commitencoding $old &&
		echo $old >>F &&
		shit commit -a -F "$TEST_DIRECTORY"/t3900/$msg &&
		test_tick &&
		echo intermediate stuff >>G &&
		shit add G &&
		shit commit -a -m "intermediate commit" &&
		test_tick &&
		shit config i18n.commitencoding $new &&
		echo $new-$flag >>F &&
		shit commit -a --$flag HEAD^ &&
		shit rebase --autosquash -i HEAD^^^ &&
		shit rev-list HEAD >actual &&
		test_line_count = 3 actual &&
		iconv -f $old -t UTF-8 "$TEST_DIRECTORY"/t3900/$msg >expect &&
		shit cat-file commit HEAD^ >raw &&
		(sed "1,/^$/d" raw | iconv -f $new -t utf-8) >actual &&
		test_cmp expect actual
	'
}

test_commit_autosquash_multi_encoding fixup UTF-8 ISO-8859-1 1-UTF-8.txt
test_commit_autosquash_multi_encoding squash ISO-8859-1 UTF-8 ISO8859-1.txt
test_commit_autosquash_multi_encoding squash eucJP ISO-2022-JP eucJP.txt
test_commit_autosquash_multi_encoding fixup ISO-2022-JP UTF-8 ISO-2022-JP.txt

test_done
