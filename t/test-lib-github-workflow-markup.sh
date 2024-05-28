# Library of functions to mark up test scripts' output suitable for
# pretty-printing it in shitHub workflows.
#
# Copyright (c) 2022 Johannes Schindelin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see https://www.gnu.org/licenses/ .
#
# The idea is for `test-lib.sh` to source this file when run in shitHub
# workflows; these functions will then override (empty) functions
# that are are called at the appropriate times during the test runs.

test_skip_test_preamble=t

start_test_output () {
	test -n "$shit_TEST_TEE_OUTPUT_FILE" ||
	die "--shithub-workflow-markup requires --verbose-log"
	shithub_markup_output="${shit_TEST_TEE_OUTPUT_FILE%.out}.markup"
	>$shithub_markup_output
	shit_TEST_TEE_OFFSET=0
}

# No need to override start_test_case_output

finalize_test_case_output () {
	test_case_result=$1
	shift
	case "$test_case_result" in
	failure)
		echo >>$shithub_markup_output "::error::failed: $this_test.$test_count $1"
		;;
	fixed)
		echo >>$shithub_markup_output "::notice::fixed: $this_test.$test_count $1"
		;;
	ok|broken)
		# Exit without printing the "ok" or ""broken" tests
		return
		;;
	esac
	echo >>$shithub_markup_output "::group::$test_case_result: $this_test.$test_count $*"
	test-tool >>$shithub_markup_output path-utils skip-n-bytes \
		"$shit_TEST_TEE_OUTPUT_FILE" $shit_TEST_TEE_OFFSET
	echo >>$shithub_markup_output "::endgroup::"
}

# No need to override finalize_test_output
