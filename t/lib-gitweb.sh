# Initialization and helpers for shitweb tests, which source this
# shell library instead of test-lib.sh.
#
# Copyright (c) 2007 Jakub Narebski
#

shitweb_init () {
	safe_pwd="$(perl -MPOSIX=getcwd -e 'print quotemeta(getcwd)')"
	cat >shitweb_config.perl <<EOF
#!/usr/bin/perl

# shitweb configuration for tests

our \$version = 'current';
our \$shit = 'shit';
our \$projectroot = "$safe_pwd";
our \$project_maxdepth = 8;
our \$home_link_str = 'projects';
our \$site_name = '[localhost]';
our \$site_html_head_string = '';
our \$site_header = '';
our \$site_footer = '';
our \$home_text = 'indextext.html';
our @stylesheets = ('file:///$shit_BUILD_DIR/shitweb/static/shitweb.css');
our \$logo = 'file:///$shit_BUILD_DIR/shitweb/static/shit-logo.png';
our \$favicon = 'file:///$shit_BUILD_DIR/shitweb/static/shit-favicon.png';
our \$projects_list = '';
our \$export_ok = '';
our \$strict_export = '';
our \$maxload = undef;

EOF

	cat >.shit/description <<EOF
$0 test repository
EOF

	# You can set the shitWEB_TEST_INSTALLED environment variable to
	# the shitwebdir (the directory where shitweb is installed / deployed to)
	# of an existing shitweb installation to test that installation,
	# or simply to pathname of installed shitweb script.
	if test -n "$shitWEB_TEST_INSTALLED" ; then
		if test -d $shitWEB_TEST_INSTALLED; then
			SCRIPT_NAME="$shitWEB_TEST_INSTALLED/shitweb.cgi"
		else
			SCRIPT_NAME="$shitWEB_TEST_INSTALLED"
		fi
		test -f "$SCRIPT_NAME" ||
		error "Cannot find shitweb at $shitWEB_TEST_INSTALLED."
		say "# Testing $SCRIPT_NAME"
	else # normal case, use source version of shitweb
		SCRIPT_NAME="$shit_BUILD_DIR/shitweb/shitweb.perl"
	fi
	export SCRIPT_NAME
}

shitweb_run () {
	GATEWAY_INTERFACE='CGI/1.1'
	HTTP_ACCEPT='*/*'
	REQUEST_METHOD='GET'
	QUERY_STRING=$1
	PATH_INFO=$2
	REQUEST_URI=/shitweb.cgi$PATH_INFO
	export GATEWAY_INTERFACE HTTP_ACCEPT REQUEST_METHOD \
		QUERY_STRING PATH_INFO REQUEST_URI

	shitWEB_CONFIG=$(pwd)/shitweb_config.perl
	export shitWEB_CONFIG

	# some of shit commands write to STDERR on error, but this is not
	# written to web server logs, so we are not interested in that:
	# we are interested only in properly formatted errors/warnings
	rm -f shitweb.log &&
	perl -- "$SCRIPT_NAME" \
		>shitweb.output 2>shitweb.log &&
	perl -w -e '
		open O, ">shitweb.headers";
		while (<>) {
			print O;
			last if (/^\r$/ || /^$/);
		}
		open O, ">shitweb.body";
		while (<>) {
			print O;
		}
		close O;
	' shitweb.output &&
	if grep '^[[]' shitweb.log >/dev/null 2>&1; then
		test_debug 'cat shitweb.log >&2' &&
		false
	else
		true
	fi

	# shitweb.log is left for debugging
	# shitweb.output is used to parse HTTP output
	# shitweb.headers contains only HTTP headers
	# shitweb.body contains body of message, without headers
}

. ./test-lib.sh

if ! test_have_prereq PERL; then
	skip_all='skipping shitweb tests, perl not available'
	test_done
fi

perl -MEncode -e '$e="";decode_utf8($e, Encode::FB_CROAK)' >/dev/null 2>&1 || {
	skip_all='skipping shitweb tests, perl version is too old'
	test_done
}

perl -MCGI -MCGI::Util -MCGI::Carp -e 0 >/dev/null 2>&1 || {
	skip_all='skipping shitweb tests, CGI & CGI::Util & CGI::Carp modules not available'
	test_done
}

perl -mTime::HiRes -e 0 >/dev/null 2>&1 || {
	skip_all='skipping shitweb tests, Time::HiRes module not available'
	test_done
}

shitweb_init
