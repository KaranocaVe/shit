#!/bin/sh
#
# Copyright (c) 2007 Jakub Narebski
#

test_description='shitweb as standalone script (basic tests).

This test runs shitweb (shit web interface) as CGI script from
commandline, and checks that it would not write any errors
or warnings to log.'


shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shitweb.sh

# ----------------------------------------------------------------------
# no commits (empty, just initialized repository)

test_expect_success \
	'no commits: projects_list (implicit)' \
	'shitweb_run'

test_expect_success \
	'no commits: projects_index' \
	'shitweb_run "a=project_index"'

test_expect_success \
	'no commits: .shit summary (implicit)' \
	'shitweb_run "p=.shit"'

test_expect_success \
	'no commits: .shit commit (implicit HEAD)' \
	'shitweb_run "p=.shit;a=commit"'

test_expect_success \
	'no commits: .shit commitdiff (implicit HEAD)' \
	'shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'no commits: .shit tree (implicit HEAD)' \
	'shitweb_run "p=.shit;a=tree"'

test_expect_success \
	'no commits: .shit heads' \
	'shitweb_run "p=.shit;a=heads"'

test_expect_success \
	'no commits: .shit tags' \
	'shitweb_run "p=.shit;a=tags"'


# ----------------------------------------------------------------------
# initial commit

test_expect_success \
	'Make initial commit' \
	'echo "Not an empty file." >file &&
	 shit add file &&
	 shit commit -a -m "Initial commit." &&
	 shit branch b'

test_expect_success \
	'projects_list (implicit)' \
	'shitweb_run'

test_expect_success \
	'projects_index' \
	'shitweb_run "a=project_index"'

test_expect_success \
	'.shit summary (implicit)' \
	'shitweb_run "p=.shit"'

test_expect_success \
	'.shit commit (implicit HEAD)' \
	'shitweb_run "p=.shit;a=commit"'

test_expect_success \
	'.shit commitdiff (implicit HEAD, root commit)' \
	'shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'.shit commitdiff_plain (implicit HEAD, root commit)' \
	'shitweb_run "p=.shit;a=commitdiff_plain"'

test_expect_success \
	'.shit commit (HEAD)' \
	'shitweb_run "p=.shit;a=commit;h=HEAD"'

test_expect_success \
	'.shit tree (implicit HEAD)' \
	'shitweb_run "p=.shit;a=tree"'

test_expect_success \
	'.shit blob (file)' \
	'shitweb_run "p=.shit;a=blob;f=file"'

test_expect_success \
	'.shit blob_plain (file)' \
	'shitweb_run "p=.shit;a=blob_plain;f=file"'

# ----------------------------------------------------------------------
# nonexistent objects

test_expect_success \
	'.shit commit (non-existent)' \
	'shitweb_run "p=.shit;a=commit;h=non-existent"'

test_expect_success \
	'.shit commitdiff (non-existent)' \
	'shitweb_run "p=.shit;a=commitdiff;h=non-existent"'

test_expect_success \
	'.shit commitdiff (non-existent vs HEAD)' \
	'shitweb_run "p=.shit;a=commitdiff;hp=non-existent;h=HEAD"'

test_expect_success \
	'.shit tree (0000000000000000000000000000000000000000)' \
	'shitweb_run "p=.shit;a=tree;h=0000000000000000000000000000000000000000"'

test_expect_success \
	'.shit tag (0000000000000000000000000000000000000000)' \
	'shitweb_run "p=.shit;a=tag;h=0000000000000000000000000000000000000000"'

test_expect_success \
	'.shit blob (non-existent)' \
	'shitweb_run "p=.shit;a=blob;f=non-existent"'

test_expect_success \
	'.shit blob_plain (non-existent)' \
	'shitweb_run "p=.shit;a=blob_plain;f=non-existent"'


# ----------------------------------------------------------------------
# commitdiff testing (implicit, one implicit tree-ish)

test_expect_success \
	'commitdiff(0): root' \
	'shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): file added' \
	'echo "New file" >new_file &&
	 shit add new_file &&
	 shit commit -a -m "File added." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): mode change' \
	'test_chmod +x new_file &&
	 shit commit -a -m "Mode changed." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): file renamed' \
	'shit mv new_file renamed_file &&
	 shit commit -a -m "File renamed." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): file to symlink' \
	'rm renamed_file &&
	 test_ln_s_add file renamed_file &&
	 shit commit -a -m "File to symlink." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): file deleted' \
	'shit rm renamed_file &&
	 rm -f renamed_file &&
	 shit commit -a -m "File removed." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): file copied / new file' \
	'cp file file2 &&
	 shit add file2 &&
	 shit commit -a -m "File copied." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): mode change and modified' \
	'echo "New line" >>file2 &&
	 test_chmod +x file2 &&
	 shit commit -a -m "Mode change and modification." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): renamed and modified' \
	'cat >file2<<EOF &&
Dominus reshit me,
et nihil mihi deerit.
In loco pascuae ibi me collocavit,
super aquam refectionis educavit me;
animam meam convertit,
deduxit me super semitas jusitiae,
propter nomen suum.
EOF
	 shit commit -a -m "File added." &&
	 shit mv file2 file3 &&
	 echo "Propter nomen suum." >>file3 &&
	 shit commit -a -m "File rename and modification." &&
	 shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'commitdiff(0): renamed, mode change and modified' \
	'shit mv file3 file2 &&
	 echo "Propter nomen suum." >>file2 &&
	 test_chmod +x file2 &&
	 shit commit -a -m "File rename, mode change and modification." &&
	 shitweb_run "p=.shit;a=commitdiff"'

# ----------------------------------------------------------------------
# commitdiff testing (taken from t4114-apply-typechange.sh)

test_expect_success 'setup typechange commits' '
	echo "hello world" >foo &&
	echo "hi planet" >bar &&
	shit update-index --add foo bar &&
	shit commit -m initial &&
	shit branch initial &&
	rm -f foo &&
	test_ln_s_add bar foo &&
	shit commit -m "foo symlinked to bar" &&
	shit branch foo-symlinked-to-bar &&
	rm -f foo &&
	echo "how far is the sun?" >foo &&
	shit update-index foo &&
	shit commit -m "foo back to file" &&
	shit branch foo-back-to-file &&
	rm -f foo &&
	shit update-index --remove foo &&
	mkdir foo &&
	echo "if only I knew" >foo/baz &&
	shit update-index --add foo/baz &&
	shit commit -m "foo becomes a directory" &&
	shit branch "foo-becomes-a-directory" &&
	echo "hello world" >foo/baz &&
	shit update-index foo/baz &&
	shit commit -m "foo/baz is the original foo" &&
	shit branch foo-baz-renamed-from-foo
	'

test_expect_success \
	'commitdiff(2): file renamed from foo to foo/baz' \
	'shitweb_run "p=.shit;a=commitdiff;hp=initial;h=foo-baz-renamed-from-foo"'

test_expect_success \
	'commitdiff(2): file renamed from foo/baz to foo' \
	'shitweb_run "p=.shit;a=commitdiff;hp=foo-baz-renamed-from-foo;h=initial"'

test_expect_success \
	'commitdiff(2): directory becomes file' \
	'shitweb_run "p=.shit;a=commitdiff;hp=foo-becomes-a-directory;h=initial"'

test_expect_success \
	'commitdiff(2): file becomes directory' \
	'shitweb_run "p=.shit;a=commitdiff;hp=initial;h=foo-becomes-a-directory"'

test_expect_success \
	'commitdiff(2): file becomes symlink' \
	'shitweb_run "p=.shit;a=commitdiff;hp=initial;h=foo-symlinked-to-bar"'

test_expect_success \
	'commitdiff(2): symlink becomes file' \
	'shitweb_run "p=.shit;a=commitdiff;hp=foo-symlinked-to-bar;h=foo-back-to-file"'

test_expect_success \
	'commitdiff(2): symlink becomes directory' \
	'shitweb_run "p=.shit;a=commitdiff;hp=foo-symlinked-to-bar;h=foo-becomes-a-directory"'

test_expect_success \
	'commitdiff(2): directory becomes symlink' \
	'shitweb_run "p=.shit;a=commitdiff;hp=foo-becomes-a-directory;h=foo-symlinked-to-bar"'

# ----------------------------------------------------------------------
# commitdiff testing (incomplete lines)

test_expect_success 'setup incomplete lines' '
	cat >file<<-\EOF &&
	Dominus reshit me,
	et nihil mihi deerit.
	In loco pascuae ibi me collocavit,
	super aquam refectionis educavit me;
	animam meam convertit,
	deduxit me super semitas jusitiae,
	propter nomen suum.
	CHANGE_ME
	EOF
	shit commit -a -m "Preparing for incomplete lines" &&
	echo "incomplete" | tr -d "\\012" >>file &&
	shit commit -a -m "Add incomplete line" &&
	shit tag incomplete_lines_add &&
	sed -e s/CHANGE_ME/change_me/ <file >file+ &&
	mv -f file+ file &&
	shit commit -a -m "Incomplete context line" &&
	shit tag incomplete_lines_ctx &&
	echo "Dominus reshit me," >file &&
	echo "incomplete line" | tr -d "\\012" >>file &&
	shit commit -a -m "Change incomplete line" &&
	shit tag incomplete_lines_chg &&
	echo "Dominus reshit me," >file &&
	shit commit -a -m "Remove incomplete line" &&
	shit tag incomplete_lines_rem
'

test_expect_success 'commitdiff(1): addition of incomplete line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_add"
'

test_expect_success 'commitdiff(1): incomplete line as context line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_ctx"
'

test_expect_success 'commitdiff(1): change incomplete line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_chg"
'

test_expect_success 'commitdiff(1): removal of incomplete line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_rem"
'

# ----------------------------------------------------------------------
# commit, commitdiff: merge, large
test_expect_success \
	'Create a merge' \
	'shit checkout b &&
	 echo "Branch" >>b &&
	 shit add b &&
	 shit commit -a -m "On branch" &&
	 shit checkout main &&
	 shit merge b &&
	 shit tag merge_commit'

test_expect_success \
	'commit(0): merge commit' \
	'shitweb_run "p=.shit;a=commit"'

test_expect_success \
	'commitdiff(0): merge commit' \
	'shitweb_run "p=.shit;a=commitdiff"'

test_expect_success \
	'Prepare large commit' \
	'shit checkout b &&
	 echo "To be changed" >01-change &&
	 echo "To be renamed" >02-pure-rename-from &&
	 echo "To be deleted" >03-delete &&
	 echo "To be renamed and changed" >04-rename-from &&
	 echo "To have mode changed" >05-mode-change &&
	 echo "File to symlink" >06-file-or-symlink &&
	 echo "To be changed and have mode changed" >07-change-mode-change &&
	 shit add 0* &&
	 shit commit -a -m "Prepare large commit" &&
	 echo "Changed" >01-change &&
	 shit mv 02-pure-rename-from 02-pure-rename-to &&
	 shit rm 03-delete && rm -f 03-delete &&
	 echo "A new file" >03-new &&
	 shit add 03-new &&
	 shit mv 04-rename-from 04-rename-to &&
	 echo "Changed" >>04-rename-to &&
	 test_chmod +x 05-mode-change &&
	 rm -f 06-file-or-symlink &&
	 test_ln_s_add 01-change 06-file-or-symlink &&
	 echo "Changed and have mode changed" >07-change-mode-change &&
	 test_chmod +x 07-change-mode-change &&
	 shit commit -a -m "Large commit" &&
	 shit checkout main'

test_expect_success \
	'commit(1): large commit' \
	'shitweb_run "p=.shit;a=commit;h=b"'

test_expect_success \
	'commitdiff(1): large commit' \
	'shitweb_run "p=.shit;a=commitdiff;h=b"'

# ----------------------------------------------------------------------
# side-by-side diff

test_expect_success 'side-by-side: addition of incomplete line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_add;ds=sidebyside"
'

test_expect_success 'side-by-side: incomplete line as context line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_ctx;ds=sidebyside"
'

test_expect_success 'side-by-side: changed incomplete line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_chg;ds=sidebyside"
'

test_expect_success 'side-by-side: removal of incomplete line' '
	shitweb_run "p=.shit;a=commitdiff;h=incomplete_lines_rem;ds=sidebyside"
'

test_expect_success 'side-by-side: merge commit' '
	shitweb_run "p=.shit;a=commitdiff;h=merge_commit;ds=sidebyside"
'

# ----------------------------------------------------------------------
# tags testing

test_expect_success \
	'tags: list of different types of tags' \
	'shit checkout main &&
	 shit tag -a -m "Tag commit object" tag-commit HEAD &&
	 shit tag -a -m "" tag-commit-nomessage HEAD &&
	 shit tag -a -m "Tag tag object" tag-tag tag-commit &&
	 shit tag -a -m "Tag tree object" tag-tree HEAD^{tree} &&
	 shit tag -a -m "Tag blob object" tag-blob HEAD:file &&
	 shit tag lightweight/tag-commit HEAD &&
	 shit tag lightweight/tag-tag tag-commit &&
	 shit tag lightweight/tag-tree HEAD^{tree} &&
	 shit tag lightweight/tag-blob HEAD:file &&
	 shitweb_run "p=.shit;a=tags"'

test_expect_success \
	'tag: Tag to commit object' \
	'shitweb_run "p=.shit;a=tag;h=tag-commit"'

test_expect_success \
	'tag: on lightweight tag (invalid)' \
	'shitweb_run "p=.shit;a=tag;h=lightweight/tag-commit"'

# ----------------------------------------------------------------------
# logs

test_expect_success \
	'logs: log (implicit HEAD)' \
	'shitweb_run "p=.shit;a=log"'

test_expect_success \
	'logs: shortlog (implicit HEAD)' \
	'shitweb_run "p=.shit;a=shortlog"'

test_expect_success \
	'logs: history (implicit HEAD, file)' \
	'shitweb_run "p=.shit;a=history;f=file"'

test_expect_success \
	'logs: history (implicit HEAD, non-existent file)' \
	'shitweb_run "p=.shit;a=history;f=non-existent"'

test_expect_success \
	'logs: history (implicit HEAD, deleted file)' \
	'shit checkout main &&
	 echo "to be deleted" >deleted_file &&
	 shit add deleted_file &&
	 shit commit -m "Add file to be deleted" &&
	 shit rm deleted_file &&
	 shit commit -m "Delete file" &&
	 shitweb_run "p=.shit;a=history;f=deleted_file"'

# ----------------------------------------------------------------------
# path_info links
test_expect_success \
	'path_info: project' \
	'shitweb_run "" "/.shit"'

test_expect_success \
	'path_info: project/branch' \
	'shitweb_run "" "/.shit/b"'

test_expect_success \
	'path_info: project/branch:file' \
	'shitweb_run "" "/.shit/main:file"'

test_expect_success \
	'path_info: project/branch:dir/' \
	'shitweb_run "" "/.shit/main:foo/"'

test_expect_success \
	'path_info: project/branch (non-existent)' \
	'shitweb_run "" "/.shit/non-existent"'

test_expect_success \
	'path_info: project/branch:filename (non-existent branch)' \
	'shitweb_run "" "/.shit/non-existent:non-existent"'

test_expect_success \
	'path_info: project/branch:file (non-existent)' \
	'shitweb_run "" "/.shit/main:non-existent"'

test_expect_success \
	'path_info: project/branch:dir/ (non-existent)' \
	'shitweb_run "" "/.shit/main:non-existent/"'


test_expect_success \
	'path_info: project/branch:/file' \
	'shitweb_run "" "/.shit/main:/file"'

test_expect_success \
	'path_info: project/:/file (implicit HEAD)' \
	'shitweb_run "" "/.shit/:/file"'

test_expect_success \
	'path_info: project/:/ (implicit HEAD, top tree)' \
	'shitweb_run "" "/.shit/:/"'


# ----------------------------------------------------------------------
# feed generation

test_expect_success \
	'feeds: OPML' \
	'shitweb_run "a=opml"'

test_expect_success \
	'feed: RSS' \
	'shitweb_run "p=.shit;a=rss"'

test_expect_success \
	'feed: Atom' \
	'shitweb_run "p=.shit;a=atom"'

# ----------------------------------------------------------------------
# encoding/decoding

test_expect_success \
	'encode(commit): utf8' \
	'. "$TEST_DIRECTORY"/t3901/utf8.txt &&
	 test_when_finished "shit_AUTHOR_NAME=\"A U Thor\"" &&
	 test_when_finished "shit_COMMITTER_NAME=\"C O Mitter\"" &&
	 echo "UTF-8" >>file &&
	 shit add file &&
	 shit commit -F "$TEST_DIRECTORY"/t3900/1-UTF-8.txt &&
	 shitweb_run "p=.shit;a=commit"'

test_expect_success \
	'encode(commit): iso-8859-1' \
	'. "$TEST_DIRECTORY"/t3901/8859-1.txt &&
	 test_when_finished "shit_AUTHOR_NAME=\"A U Thor\"" &&
	 test_when_finished "shit_COMMITTER_NAME=\"C O Mitter\"" &&
	 echo "ISO-8859-1" >>file &&
	 shit add file &&
	 test_config i18n.commitencoding ISO-8859-1 &&
	 shit commit -F "$TEST_DIRECTORY"/t3900/ISO8859-1.txt &&
	 shitweb_run "p=.shit;a=commit"'

test_expect_success \
	'encode(log): utf-8 and iso-8859-1' \
	'shitweb_run "p=.shit;a=log"'

# ----------------------------------------------------------------------
# extra options

test_expect_success \
	'opt: log --no-merges' \
	'shitweb_run "p=.shit;a=log;opt=--no-merges"'

test_expect_success \
	'opt: atom --no-merges' \
	'shitweb_run "p=.shit;a=log;opt=--no-merges"'

test_expect_success \
	'opt: "file" history --no-merges' \
	'shitweb_run "p=.shit;a=history;f=file;opt=--no-merges"'

test_expect_success \
	'opt: log --no-such-option (invalid option)' \
	'shitweb_run "p=.shit;a=log;opt=--no-such-option"'

test_expect_success \
	'opt: tree --no-merges (invalid option for action)' \
	'shitweb_run "p=.shit;a=tree;opt=--no-merges"'

# ----------------------------------------------------------------------
# testing config_to_multi / cloneurl

test_expect_success \
       'URL: no project URLs, no base URL' \
       'shitweb_run "p=.shit;a=summary"'

test_expect_success \
       'URL: project URLs via shitweb.url' \
       'shit config --add shitweb.url shit://example.com/shit/trash.shit &&
        shit config --add shitweb.url http://example.com/shit/trash.shit &&
        shitweb_run "p=.shit;a=summary"'

cat >.shit/cloneurl <<\EOF
shit://example.com/shit/trash.shit
http://example.com/shit/trash.shit
EOF

test_expect_success \
       'URL: project URLs via cloneurl file' \
       'shitweb_run "p=.shit;a=summary"'

# ----------------------------------------------------------------------
# shitweb config and repo config

cat >>shitweb_config.perl <<\EOF

# turn on override for each overridable feature
foreach my $key (keys %feature) {
	if ($feature{$key}{'sub'}) {
		$feature{$key}{'override'} = 1;
	}
}
EOF

test_expect_success \
	'config override: projects list (implicit)' \
	'shitweb_run'

test_expect_success \
	'config override: tree view, features not overridden in repo config' \
	'shitweb_run "p=.shit;a=tree"'

test_expect_success \
	'config override: tree view, features disabled in repo config' \
	'shit config shitweb.blame no &&
	 shit config shitweb.snapshot none &&
	 shit config shitweb.avatar gravatar &&
	 shitweb_run "p=.shit;a=tree"'

test_expect_success \
	'config override: tree view, features enabled in repo config (1)' \
	'shit config shitweb.blame yes &&
	 shit config shitweb.snapshot "zip,tgz, tbz2" &&
	 shitweb_run "p=.shit;a=tree"'

test_expect_success 'setup' '
	version=$(shit config core.repositoryformatversion) &&
	algo=$(test_might_fail shit config extensions.objectformat) &&
	refstorage=$(test_might_fail shit config extensions.refstorage) &&
	cat >.shit/config <<-\EOF &&
	# testing noval and alternate separator
	[shitweb]
		blame
		snapshot = zip tgz
	EOF
	shit config core.repositoryformatversion "$version" &&
	if test -n "$algo"
	then
		shit config extensions.objectformat "$algo"
	fi &&
	if test -n "$refstorage"
	then
		shit config extensions.refstorage "$refstorage"
	fi
'

test_expect_success \
	'config override: tree view, features enabled in repo config (2)' \
	'shitweb_run "p=.shit;a=tree"'

# ----------------------------------------------------------------------
# searching

cat >>shitweb_config.perl <<\EOF

# enable search
$feature{'search'}{'default'} = [1];
$feature{'grep'}{'default'} = [1];
$feature{'pickaxe'}{'default'} = [1];
EOF

test_expect_success \
	'search: preparation' \
	'echo "1st MATCH" >>file &&
	 echo "2nd MATCH" >>file &&
	 echo "MATCH" >>bar &&
	 shit add file bar &&
	 shit commit -m "Added MATCH word"'

test_expect_success \
	'search: commit author' \
	'shitweb_run "p=.shit;a=search;h=HEAD;st=author;s=A+U+Thor"'

test_expect_success \
	'search: commit message' \
	'shitweb_run "p=.shit;a=search;h=HEAD;st=commitr;s=MATCH"'

test_expect_success \
	'search: grep' \
	'shitweb_run "p=.shit;a=search;h=HEAD;st=grep;s=MATCH"'

test_expect_success \
	'search: pickaxe' \
	'shitweb_run "p=.shit;a=search;h=HEAD;st=pickaxe;s=MATCH"'

test_expect_success \
	'search: projects' \
	'shitweb_run "a=project_list;s=.shit"'

# ----------------------------------------------------------------------
# non-ASCII in README.html

test_expect_success \
	'README.html with non-ASCII characters (utf-8)' \
	'echo "<b>UTF-8 example:</b><br />" >.shit/README.html &&
	 cat "$TEST_DIRECTORY"/t3900/1-UTF-8.txt >>.shit/README.html &&
	 shitweb_run "p=.shit;a=summary"'

# ----------------------------------------------------------------------
# syntax highlighting


highlight_version=$(highlight --version </dev/null 2>/dev/null)
if [ $? -eq 127 ]; then
	say "Skipping syntax highlighting tests: 'highlight' not found"
elif test -z "$highlight_version"; then
	say "Skipping syntax highlighting tests: incorrect 'highlight' found"
else
	test_set_prereq HIGHLIGHT
	cat >>shitweb_config.perl <<-\EOF
	our $highlight_bin = "highlight";
	$feature{'highlight'}{'override'} = 1;
	EOF
fi

test_expect_success HIGHLIGHT \
	'syntax highlighting (no highlight, unknown syntax)' \
	'shit config shitweb.highlight yes &&
	 shitweb_run "p=.shit;a=blob;f=file"'

test_expect_success HIGHLIGHT \
	'syntax highlighting (highlighted, shell script)' \
	'shit config shitweb.highlight yes &&
	 echo "#!/usr/bin/sh" >test.sh &&
	 shit add test.sh &&
	 shit commit -m "Add test.sh" &&
	 shitweb_run "p=.shit;a=blob;f=test.sh"'

test_expect_success HIGHLIGHT \
	'syntax highlighting (highlighter language autodetection)' \
	'shit config shitweb.highlight yes &&
	 echo "#!/usr/bin/perl" >test &&
	 shit add test &&
	 shit commit -m "Add test" &&
	 shitweb_run "p=.shit;a=blob;f=test"'

# ----------------------------------------------------------------------
# forks of projects

cat >>shitweb_config.perl <<\EOF &&
$feature{'forks'}{'default'} = [1];
EOF

test_expect_success \
	'forks: prepare' \
	'shit init --bare foo.shit &&
	 shit --shit-dir=foo.shit --work-tree=. add file &&
	 shit --shit-dir=foo.shit --work-tree=. commit -m "Initial commit" &&
	 echo "foo" >foo.shit/description &&
	 mkdir -p foo &&
	 (cd foo &&
	  shit clone --shared --bare ../foo.shit foo-forked.shit &&
	  echo "fork of foo" >foo-forked.shit/description)'

test_expect_success \
	'forks: projects list' \
	'shitweb_run'

test_expect_success \
	'forks: forks action' \
	'shitweb_run "p=foo.shit;a=forks"'

# ----------------------------------------------------------------------
# content tags (tag cloud)

cat >>shitweb_config.perl <<-\EOF &&
# we don't test _setting_ content tags, so any true value is good
$feature{'ctags'}{'default'} = ['ctags_script.cgi'];
EOF

test_expect_success \
	'ctags: tag cloud in projects list' \
	'mkdir .shit/ctags &&
	 echo "2" >.shit/ctags/foo &&
	 echo "1" >.shit/ctags/bar &&
	shitweb_run'

test_expect_success \
	'ctags: search projects by existing tag' \
	'shitweb_run "by_tag=foo"'

test_expect_success \
	'ctags: search projects by non existent tag' \
	'shitweb_run "by_tag=non-existent"'

test_expect_success \
	'ctags: malformed tag weights' \
	'mkdir -p .shit/ctags &&
	 echo "not-a-number" >.shit/ctags/nan &&
	 echo "not-a-number-2" >.shit/ctags/nan2 &&
	 echo "0.1" >.shit/ctags/floating-point &&
	 shitweb_run'

# ----------------------------------------------------------------------
# categories

test_expect_success \
	'categories: projects list, only default category' \
	'echo "\$projects_list_group_categories = 1;" >>shitweb_config.perl &&
	 shitweb_run'

# ----------------------------------------------------------------------
# unborn branches

test_expect_success \
	'unborn HEAD: "summary" page (with "heads" subview)' \
	'{
		shit checkout orphan_branch ||
		shit checkout --orphan orphan_branch
	 } &&
	 test_when_finished "shit checkout main" &&
	 shitweb_run "p=.shit;a=summary"'

test_done
