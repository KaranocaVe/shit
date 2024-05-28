#!/bin/sh

test_description='shit_EDITOR, core.editor, and stuff'

. ./test-lib.sh

unset EDITOR VISUAL shit_EDITOR

test_expect_success 'determine default editor' '

	vi=$(TERM=vt100 shit var shit_EDITOR) &&
	test -n "$vi"

'

if ! expr "$vi" : '[a-z]*$' >/dev/null
then
	vi=
fi

for i in shit_EDITOR core_editor EDITOR VISUAL $vi
do
	cat >e-$i.sh <<-EOF
	#!$SHELL_PATH
	echo "Edited by $i" >"\$1"
	EOF
	chmod +x e-$i.sh
done

if ! test -z "$vi"
then
	mv e-$vi.sh $vi
fi

test_expect_success setup '

	msg="Hand-edited" &&
	test_commit "$msg" &&
	echo "$msg" >expect &&
	shit show -s --format=%s > actual &&
	test_cmp expect actual

'

TERM=dumb
export TERM
test_expect_success 'dumb should error out when falling back on vi' '

	if shit commit --amend
	then
		echo "Oops?"
		false
	else
		: happy
	fi
'

test_expect_success 'dumb should prefer EDITOR to VISUAL' '

	EDITOR=./e-EDITOR.sh &&
	VISUAL=./e-VISUAL.sh &&
	export EDITOR VISUAL &&
	shit commit --amend &&
	test "$(shit show -s --format=%s)" = "Edited by EDITOR"

'

TERM=vt100
export TERM
for i in $vi EDITOR VISUAL core_editor shit_EDITOR
do
	echo "Edited by $i" >expect
	unset EDITOR VISUAL shit_EDITOR
	shit config --unset-all core.editor
	case "$i" in
	core_editor)
		shit config core.editor ./e-core_editor.sh
		;;
	[A-Z]*)
		eval "$i=./e-$i.sh"
		export $i
		;;
	esac
	test_expect_success "Using $i" '
		shit --exec-path=. commit --amend &&
		shit show -s --pretty=oneline |
		sed -e "s/^[0-9a-f]* //" >actual &&
		test_cmp expect actual
	'
done

unset EDITOR VISUAL shit_EDITOR
shit config --unset-all core.editor
for i in $vi EDITOR VISUAL core_editor shit_EDITOR
do
	echo "Edited by $i" >expect
	case "$i" in
	core_editor)
		shit config core.editor ./e-core_editor.sh
		;;
	[A-Z]*)
		eval "$i=./e-$i.sh"
		export $i
		;;
	esac
	test_expect_success "Using $i (override)" '
		shit --exec-path=. commit --amend &&
		shit show -s --pretty=oneline |
		sed -e "s/^[0-9a-f]* //" >actual &&
		test_cmp expect actual
	'
done

test_expect_success 'editor with a space' '
	echo "echo space >\"\$1\"" >"e space.sh" &&
	chmod a+x "e space.sh" &&
	shit_EDITOR="./e\ space.sh" shit commit --amend &&
	test space = "$(shit show -s --pretty=format:%s)"

'

unset shit_EDITOR
test_expect_success 'core.editor with a space' '

	shit config core.editor \"./e\ space.sh\" &&
	shit commit --amend &&
	test space = "$(shit show -s --pretty=format:%s)"

'

test_done
