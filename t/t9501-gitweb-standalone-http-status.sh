#!/bin/sh
#
# Copyright (c) 2009 Mark Rada
#

test_description='shitweb as standalone script (http status tests).

This test runs shitweb (shit web interface) as a CGI script from the
commandline, and checks that it returns the expected HTTP status
code and message.'


shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-shitweb.sh

#
# shitweb only provides the functionality tested by the 'modification times'
# tests if it can access a date parser from one of these modules:
#
perl -MHTTP::Date -e 0 >/dev/null 2>&1 && test_set_prereq DATE_PARSER
perl -MTime::ParseDate -e 0 >/dev/null 2>&1 && test_set_prereq DATE_PARSER

# ----------------------------------------------------------------------
# snapshot settings

test_expect_success 'setup' "
	test_commit 'SnapshotTests' 'i can has snapshot'
"


cat >>shitweb_config.perl <<\EOF
$feature{'snapshot'}{'override'} = 0;
EOF

test_expect_success \
    'snapshots: tgz only default format enabled' \
    'shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=tgz" &&
    grep "Status: 200 OK" shitweb.output &&
    shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=tbz2" &&
    grep "403 - Unsupported snapshot format" shitweb.output &&
    shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=txz" &&
    grep "403 - Snapshot format not allowed" shitweb.output &&
    shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=zip" &&
    grep "403 - Unsupported snapshot format" shitweb.output'


cat >>shitweb_config.perl <<\EOF
$feature{'snapshot'}{'default'} = ['tgz','tbz2','txz','zip'];
EOF

test_expect_success \
    'snapshots: all enabled in default, use default disabled value' \
    'shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=tgz" &&
    grep "Status: 200 OK" shitweb.output &&
    shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=tbz2" &&
    grep "Status: 200 OK" shitweb.output &&
    shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=txz" &&
    grep "403 - Snapshot format not allowed" shitweb.output &&
    shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=zip" &&
    grep "Status: 200 OK" shitweb.output'


cat >>shitweb_config.perl <<\EOF
$known_snapshot_formats{'zip'}{'disabled'} = 1;
EOF

test_expect_success \
    'snapshots: zip explicitly disabled' \
    'shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=zip" &&
    grep "403 - Snapshot format not allowed" shitweb.output'
test_debug 'cat shitweb.output'


cat >>shitweb_config.perl <<\EOF
$known_snapshot_formats{'tgz'}{'disabled'} = 0;
EOF

test_expect_success \
    'snapshots: tgz explicitly enabled' \
    'shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=tgz" &&
    grep "Status: 200 OK" shitweb.output'
test_debug 'cat shitweb.headers'


# ----------------------------------------------------------------------
# snapshot hash ids

test_expect_success 'snapshots: good tree-ish id' '
	shitweb_run "p=.shit;a=snapshot;h=main;sf=tgz" &&
	grep "Status: 200 OK" shitweb.output
'
test_debug 'cat shitweb.headers'

test_expect_success 'snapshots: bad tree-ish id' '
	shitweb_run "p=.shit;a=snapshot;h=frizzumFrazzum;sf=tgz" &&
	grep "404 - Object does not exist" shitweb.output
'
test_debug 'cat shitweb.output'

test_expect_success 'snapshots: bad tree-ish id (tagged object)' '
	echo object > tag-object &&
	shit add tag-object &&
	test_tick && shit commit -m "Object to be tagged" &&
	shit tag tagged-object $(shit hash-object tag-object) &&
	shitweb_run "p=.shit;a=snapshot;h=tagged-object;sf=tgz" &&
	grep "400 - Object is not a tree-ish" shitweb.output
'
test_debug 'cat shitweb.output'

test_expect_success 'snapshots: good object id' '
	ID=$(shit rev-parse --verify HEAD) &&
	shitweb_run "p=.shit;a=snapshot;h=$ID;sf=tgz" &&
	grep "Status: 200 OK" shitweb.output
'
test_debug 'cat shitweb.headers'

test_expect_success 'snapshots: bad object id' '
	shitweb_run "p=.shit;a=snapshot;h=abcdef01234;sf=tgz" &&
	grep "404 - Object does not exist" shitweb.output
'
test_debug 'cat shitweb.output'

# ----------------------------------------------------------------------
# modification times (Last-Modified and If-Modified-Since)

test_expect_success DATE_PARSER 'modification: feed last-modified' '
	shitweb_run "p=.shit;a=atom;h=main" &&
	grep "Status: 200 OK" shitweb.headers &&
	grep "Last-modified: Thu, 7 Apr 2005 22:14:13 +0000" shitweb.headers
'
test_debug 'cat shitweb.headers'

test_expect_success DATE_PARSER 'modification: feed if-modified-since (modified)' '
	HTTP_IF_MODIFIED_SINCE="Wed, 6 Apr 2005 22:14:13 +0000" &&
	export HTTP_IF_MODIFIED_SINCE &&
	test_when_finished "unset HTTP_IF_MODIFIED_SINCE" &&
	shitweb_run "p=.shit;a=atom;h=main" &&
	grep "Status: 200 OK" shitweb.headers
'
test_debug 'cat shitweb.headers'

test_expect_success DATE_PARSER 'modification: feed if-modified-since (unmodified)' '
	HTTP_IF_MODIFIED_SINCE="Thu, 7 Apr 2005 22:14:13 +0000" &&
	export HTTP_IF_MODIFIED_SINCE &&
	test_when_finished "unset HTTP_IF_MODIFIED_SINCE" &&
	shitweb_run "p=.shit;a=atom;h=main" &&
	grep "Status: 304 Not Modified" shitweb.headers
'
test_debug 'cat shitweb.headers'

test_expect_success DATE_PARSER 'modification: snapshot last-modified' '
	shitweb_run "p=.shit;a=snapshot;h=main;sf=tgz" &&
	grep "Status: 200 OK" shitweb.headers &&
	grep "Last-modified: Thu, 7 Apr 2005 22:14:13 +0000" shitweb.headers
'
test_debug 'cat shitweb.headers'

test_expect_success DATE_PARSER 'modification: snapshot if-modified-since (modified)' '
	HTTP_IF_MODIFIED_SINCE="Wed, 6 Apr 2005 22:14:13 +0000" &&
	export HTTP_IF_MODIFIED_SINCE &&
	test_when_finished "unset HTTP_IF_MODIFIED_SINCE" &&
	shitweb_run "p=.shit;a=snapshot;h=main;sf=tgz" &&
	grep "Status: 200 OK" shitweb.headers
'
test_debug 'cat shitweb.headers'

test_expect_success DATE_PARSER 'modification: snapshot if-modified-since (unmodified)' '
	HTTP_IF_MODIFIED_SINCE="Thu, 7 Apr 2005 22:14:13 +0000" &&
	export HTTP_IF_MODIFIED_SINCE &&
	test_when_finished "unset HTTP_IF_MODIFIED_SINCE" &&
	shitweb_run "p=.shit;a=snapshot;h=main;sf=tgz" &&
	grep "Status: 304 Not Modified" shitweb.headers
'
test_debug 'cat shitweb.headers'

test_expect_success DATE_PARSER 'modification: tree snapshot' '
	ID=$(shit rev-parse --verify HEAD^{tree}) &&
	HTTP_IF_MODIFIED_SINCE="Wed, 6 Apr 2005 22:14:13 +0000" &&
	export HTTP_IF_MODIFIED_SINCE &&
	test_when_finished "unset HTTP_IF_MODIFIED_SINCE" &&
	shitweb_run "p=.shit;a=snapshot;h=$ID;sf=tgz" &&
	grep "Status: 200 OK" shitweb.headers &&
	! grep -i "last-modified" shitweb.headers
'
test_debug 'cat shitweb.headers'

# ----------------------------------------------------------------------
# load checking

# always hit the load limit
cat >>shitweb_config.perl <<\EOF
our $maxload = -1;
EOF

test_expect_success 'load checking: load too high (default action)' '
	shitweb_run "p=.shit" &&
	grep "Status: 503 Service Unavailable" shitweb.headers &&
	grep "503 - The load average on the server is too high" shitweb.body
'
test_debug 'cat shitweb.headers'

# turn off load checking
cat >>shitweb_config.perl <<\EOF
our $maxload = undef;
EOF


# ----------------------------------------------------------------------
# invalid arguments

test_expect_success 'invalid arguments: invalid regexp (in project search)' '
	shitweb_run "a=project_list;s=*\.shit;sr=1" &&
	grep "Status: 400" shitweb.headers &&
	grep "400 - Invalid.*regexp" shitweb.body
'
test_debug 'cat shitweb.headers'

test_done
