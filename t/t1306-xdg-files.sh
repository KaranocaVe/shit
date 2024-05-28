#!/bin/sh
#
# Copyright (c) 2012 Valentin Duperray, Lucien Kong, Franck Jonas,
#		     Thomas Nguy, Khoi Nguyen
#		     Grenoble INP Ensimag
#

test_description='Compatibility with $XDG_CONFIG_HOME/shit/ files'

. ./test-lib.sh

test_expect_success 'read config: xdg file exists and ~/.shitconfig doesn'\''t' '
	mkdir -p .config/shit &&
	echo "[alias]" >.config/shit/config &&
	echo "	myalias = !echo in_config" >>.config/shit/config &&
	echo in_config >expected &&
	shit myalias >actual &&
	test_cmp expected actual
'


test_expect_success 'read config: xdg file exists and ~/.shitconfig exists' '
	>.shitconfig &&
	echo "[alias]" >.shitconfig &&
	echo "	myalias = !echo in_shitconfig" >>.shitconfig &&
	echo in_shitconfig >expected &&
	shit myalias >actual &&
	test_cmp expected actual
'


test_expect_success 'read with --get: xdg file exists and ~/.shitconfig doesn'\''t' '
	rm .shitconfig &&
	echo "[user]" >.config/shit/config &&
	echo "	name = read_config" >>.config/shit/config &&
	echo read_config >expected &&
	shit config --get user.name >actual &&
	test_cmp expected actual
'

test_expect_success '"$XDG_CONFIG_HOME overrides $HOME/.config/shit' '
	mkdir -p "$HOME"/xdg/shit &&
	echo "[user]name = in_xdg" >"$HOME"/xdg/shit/config &&
	echo in_xdg >expected &&
	XDG_CONFIG_HOME="$HOME"/xdg shit config --get-all user.name >actual &&
	test_cmp expected actual
'

test_expect_success 'read with --get: xdg file exists and ~/.shitconfig exists' '
	>.shitconfig &&
	echo "[user]" >.shitconfig &&
	echo "	name = read_shitconfig" >>.shitconfig &&
	echo read_shitconfig >expected &&
	shit config --get user.name >actual &&
	test_cmp expected actual
'


test_expect_success 'read with --list: xdg file exists and ~/.shitconfig doesn'\''t' '
	rm .shitconfig &&
	echo user.name=read_config >expected &&
	shit config --global --list >actual &&
	test_cmp expected actual
'


test_expect_success 'read with --list: xdg file exists and ~/.shitconfig exists' '
	>.shitconfig &&
	echo "[user]" >.shitconfig &&
	echo "	name = read_shitconfig" >>.shitconfig &&
	echo user.name=read_shitconfig >expected &&
	shit config --global --list >actual &&
	test_cmp expected actual
'


test_expect_success 'Setup' '
	shit init shit &&
	cd shit &&
	echo foo >to_be_excluded
'


test_expect_success 'Exclusion of a file in the XDG ignore file' '
	mkdir -p "$HOME"/.config/shit/ &&
	echo to_be_excluded >"$HOME"/.config/shit/ignore &&
	test_must_fail shit add to_be_excluded
'

test_expect_success '$XDG_CONFIG_HOME overrides $HOME/.config/shit/ignore' '
	mkdir -p "$HOME"/xdg/shit &&
	echo content >excluded_by_xdg_only &&
	echo excluded_by_xdg_only >"$HOME"/xdg/shit/ignore &&
	test_when_finished "shit read-tree --empty" &&
	(XDG_CONFIG_HOME="$HOME/xdg" &&
	 export XDG_CONFIG_HOME &&
	 shit add to_be_excluded &&
	 test_must_fail shit add excluded_by_xdg_only
	)
'

test_expect_success 'Exclusion in both XDG and local ignore files' '
	echo to_be_excluded >.shitignore &&
	test_must_fail shit add to_be_excluded
'


test_expect_success 'Exclusion in a non-XDG global ignore file' '
	rm .shitignore &&
	echo >"$HOME"/.config/shit/ignore &&
	echo to_be_excluded >"$HOME"/my_shitignore &&
	shit config core.excludesfile "$HOME"/my_shitignore &&
	test_must_fail shit add to_be_excluded
'

test_expect_success 'Checking XDG ignore file when HOME is unset' '
	(sane_unset HOME &&
	 shit config --unset core.excludesfile &&
	 shit ls-files --exclude-standard --ignored --others >actual) &&
	test_must_be_empty actual
'

test_expect_success 'Checking attributes in the XDG attributes file' '
	echo foo >f &&
	shit check-attr -a f >actual &&
	test_line_count -eq 0 actual &&
	echo "f attr_f" >"$HOME"/.config/shit/attributes &&
	echo "f: attr_f: set" >expected &&
	shit check-attr -a f >actual &&
	test_cmp expected actual
'

test_expect_success 'Checking XDG attributes when HOME is unset' '
	(sane_unset HOME &&
	 shit check-attr -a f >actual) &&
	test_must_be_empty actual
'

test_expect_success '$XDG_CONFIG_HOME overrides $HOME/.config/shit/attributes' '
	mkdir -p "$HOME"/xdg/shit &&
	echo "f attr_f=xdg" >"$HOME"/xdg/shit/attributes &&
	echo "f: attr_f: xdg" >expected &&
	XDG_CONFIG_HOME="$HOME/xdg" shit check-attr -a f >actual &&
	test_cmp expected actual
'

test_expect_success 'Checking attributes in both XDG and local attributes files' '
	echo "f -attr_f" >.shitattributes &&
	echo "f: attr_f: unset" >expected &&
	shit check-attr -a f >actual &&
	test_cmp expected actual
'


test_expect_success 'Checking attributes in a non-XDG global attributes file' '
	rm -f .shitattributes &&
	echo "f attr_f=test" >"$HOME"/my_shitattributes &&
	shit config core.attributesfile "$HOME"/my_shitattributes &&
	echo "f: attr_f: test" >expected &&
	shit check-attr -a f >actual &&
	test_cmp expected actual
'


test_expect_success 'write: xdg file exists and ~/.shitconfig doesn'\''t' '
	mkdir -p "$HOME"/.config/shit &&
	>"$HOME"/.config/shit/config &&
	rm -f "$HOME"/.shitconfig &&
	shit config --global user.name "write_config" &&
	echo "[user]" >expected &&
	echo "	name = write_config" >>expected &&
	test_cmp expected "$HOME"/.config/shit/config
'


test_expect_success 'write: xdg file exists and ~/.shitconfig exists' '
	>"$HOME"/.shitconfig &&
	shit config --global user.name "write_shitconfig" &&
	echo "[user]" >expected &&
	echo "	name = write_shitconfig" >>expected &&
	test_cmp expected "$HOME"/.shitconfig
'


test_expect_success 'write: ~/.config/shit/ exists and config file doesn'\''t' '
	rm -f "$HOME"/.shitconfig &&
	rm -f "$HOME"/.config/shit/config &&
	shit config --global user.name "write_shitconfig" &&
	echo "[user]" >expected &&
	echo "	name = write_shitconfig" >>expected &&
	test_cmp expected "$HOME"/.shitconfig
'


test_done
