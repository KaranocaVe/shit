#!/bin/sh
#
# Copyright (c) 2007 Eric Wong
# Based on a script by Joakim Tjernlund <joakim.tjernlund@transmode.se>

test_description='shit svn dcommit handles merges'

. ./lib-shit-svn.sh

big_text_block () {
cat << EOF
#
# (C) Copyright 2000 - 2005
# Wolfgang Denk, DENX Software Engineering, wd@denx.de.
#
# See file CREDITS for list of people who contributed to this
# project.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.
#
EOF
}

test_expect_success 'setup svn repository' '
	svn_cmd co "$svnrepo" mysvnwork &&
	mkdir -p mysvnwork/trunk &&
	(
		cd mysvnwork &&
		big_text_block >>trunk/README &&
		svn_cmd add trunk &&
		svn_cmd ci -m "first commit" trunk
	)
	'

test_expect_success 'setup shit mirror and merge' '
	shit svn init "$svnrepo" -t tags -T trunk -b branches &&
	shit svn fetch &&
	shit checkout -b svn remotes/origin/trunk &&
	shit checkout -b merge &&
	echo new file > new_file &&
	shit add new_file &&
	shit commit -a -m "New file" &&
	echo hello >> README &&
	shit commit -a -m "hello" &&
	echo add some stuff >> new_file &&
	shit commit -a -m "add some stuff" &&
	shit checkout svn &&
	mv -f README tmp &&
	echo friend > README &&
	cat tmp >> README &&
	shit commit -a -m "friend" &&
	shit merge merge
	'

test_debug 'shitk --all & sleep 1'

test_expect_success 'verify pre-merge ancestry' "
	test x\$(shit rev-parse --verify refs/heads/svn^2) = \
	     x\$(shit rev-parse --verify refs/heads/merge) &&
	shit cat-file commit refs/heads/svn^ >actual &&
	grep '^friend$' actual
	"

test_expect_success 'shit svn dcommit merges' "
	shit svn dcommit
	"

test_debug 'shitk --all & sleep 1'

test_expect_success 'verify post-merge ancestry' "
	test x\$(shit rev-parse --verify refs/heads/svn) = \
	     x\$(shit rev-parse --verify refs/remotes/origin/trunk) &&
	test x\$(shit rev-parse --verify refs/heads/svn^2) = \
	     x\$(shit rev-parse --verify refs/heads/merge) &&
	shit cat-file commit refs/heads/svn^ >actual &&
	grep '^friend$' actual
	"

test_expect_success 'verify merge commit message' "
	shit rev-list --pretty=raw -1 refs/heads/svn >actual &&
	grep \"    Merge branch 'merge' into svn\" actual
	"

test_done
