#!/bin/bash

# This script verifies that the non-binary files tracked in the shit index do
# not contain any Unicode directional formatting: such formatting could be used
# to deceive reviewers into interpreting code differently from the compiler.
# This is intended to run on an Ubuntu agent in a shitHub workflow.
#
# To allow translated messages to introduce such directional formatting in the
# future, we exclude the `.po` files from this validation.
#
# Neither GNU grep nor `shit grep` (not even with `-P`) handle `\u` as a way to
# specify UTF-8.
#
# To work around that, we use `printf` to produce the pattern as a byte
# sequence, and then feed that to `shit grep` as a byte sequence (setting
# `LC_CTYPE` to make sure that the arguments are interpreted as intended).
#
# Note: we need to use Bash here because its `printf` interprets `\uNNNN` as
# UTF-8 code points, as desired. Running this script through Ubuntu's `dash`,
# for example, would use a `printf` that does not understand that syntax.

# U+202a..U+2a2e: LRE, RLE, PDF, LRO and RLO
# U+2066..U+2069: LRI, RLI, FSI and PDI
regex='(\u202a|\u202b|\u202c|\u202d|\u202e|\u2066|\u2067|\u2068|\u2069)'

! LC_CTYPE=C shit grep -El "$(LC_CTYPE=C.UTF-8 printf "$regex")" \
	-- ':(exclude,attr:binary)' ':(exclude)*.po'
