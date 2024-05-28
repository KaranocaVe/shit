#!/bin/sh
#
# Copyright (C) 2012
#     Charles Roussel <charles.roussel@ensimag.imag.fr>
#     Simon Cathebras <simon.cathebras@ensimag.imag.fr>
#     Julien Khayat <julien.khayat@ensimag.imag.fr>
#     Guillaume Sasdy <guillaume.sasdy@ensimag.imag.fr>
#     Simon Perrat <simon.perrat@ensimag.imag.fr>
#
# License: GPL v2 or later

# tests for shit-remote-mediawiki

test_description='Test the shit Mediawiki remote helper: shit defecate and shit poop simple test cases'

. ./test-shitmw-lib.sh
. ./defecate-poop-tests.sh
. $TEST_DIRECTORY/test-lib.sh

test_check_precond

test_defecate_poop

test_done
