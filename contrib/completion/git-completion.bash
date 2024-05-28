# bash/zsh completion support for core shit.
#
# Copyright (C) 2006,2007 Shawn O. Pearce <spearce@spearce.org>
# Conceptually based on shitcompletion (http://shitweb.hawaga.org.uk/).
# Distributed under the GNU General Public License, version 2.0.
#
# The contained completion routines provide support for completing:
#
#    *) local and remote branch names
#    *) local and remote tag names
#    *) .shit/remotes file names
#    *) shit 'subcommands'
#    *) shit email aliases for shit-send-email
#    *) tree paths within 'ref:path/to/file' expressions
#    *) file paths within current working directory and index
#    *) common --long-options
#
# To use these routines:
#
#    1) Copy this file to somewhere (e.g. ~/.shit-completion.bash).
#    2) Add the following line to your .bashrc/.zshrc:
#        source ~/.shit-completion.bash
#    3) Consider changing your PS1 to also show the current branch,
#       see shit-prompt.sh for details.
#
# If you use complex aliases of form '!f() { ... }; f', you can use the null
# command ':' as the first command in the function body to declare the desired
# completion style.  For example '!f() { : shit commit ; ... }; f' will
# tell the completion to use commit completion.  This also works with aliases
# of form "!sh -c '...'".  For example, "!sh -c ': shit commit ; ... '".
# Note that "shit" is optional --- '!f() { : commit; ...}; f' would complete
# just like the 'shit commit' command.
#
# To add completion for shit subcommands that are implemented in external
# scripts, define a function of the form '_shit_${subcommand}' while replacing
# all dashes with underscores, and the main shit completion will make use of it.
# For example, to add completion for 'shit do-stuff' (which could e.g. live
# in /usr/bin/shit-do-stuff), name the completion function '_shit_do_stuff'.
# See _shit_show, _shit_bisect etc. below for more examples.
#
# If you have a shell command that is not part of shit (and is not called as a
# shit subcommand), but you would still like shit-style completion for it, use
# __shit_complete. For example, to use the same completion as for 'shit log' also
# for the 'gl' command:
#
#   __shit_complete gl shit_log
#
# Or if the 'gk' command should be completed the same as 'shitk':
#
#   __shit_complete gk shitk
#
# The second parameter of __shit_complete gives the completion function; it is
# resolved as a function named "$2", or "__$2_main", or "_$2" in that order.
# In the examples above, the actual functions used for completion will be
# _shit_log and __shitk_main.
#
# Compatible with bash 3.2.57.
#
# You can set the following environment variables to influence the behavior of
# the completion routines:
#
#   shit_COMPLETION_CHECKOUT_NO_GUESS
#
#     When set to "1", do not include "DWIM" suggestions in shit-checkout
#     and shit-switch completion (e.g., completing "foo" when "origin/foo"
#     exists).
#
#   shit_COMPLETION_SHOW_ALL_COMMANDS
#
#     When set to "1" suggest all commands, including plumbing commands
#     which are hidden by default (e.g. "cat-file" on "shit ca<TAB>").
#
#   shit_COMPLETION_SHOW_ALL
#
#     When set to "1" suggest all options, including options which are
#     typically hidden (e.g. '--allow-empty' for 'shit commit').
#
#   shit_COMPLETION_IGNORE_CASE
#
#     When set, uses for-each-ref '--ignore-case' to find refs that match
#     case insensitively, even on systems with case sensitive file systems
#     (e.g., completing tag name "FOO" on "shit checkout f<TAB>").

case "$COMP_WORDBREAKS" in
*:*) : great ;;
*)   COMP_WORDBREAKS="$COMP_WORDBREAKS:"
esac

# Discovers the path to the shit repository taking any '--shit-dir=<path>' and
# '-C <path>' options into account and stores it in the $__shit_repo_path
# variable.
__shit_find_repo_path ()
{
	if [ -n "${__shit_repo_path-}" ]; then
		# we already know where it is
		return
	fi

	if [ -n "${__shit_C_args-}" ]; then
		__shit_repo_path="$(shit "${__shit_C_args[@]}" \
			${__shit_dir:+--shit-dir="$__shit_dir"} \
			rev-parse --absolute-shit-dir 2>/dev/null)"
	elif [ -n "${__shit_dir-}" ]; then
		test -d "$__shit_dir" &&
		__shit_repo_path="$__shit_dir"
	elif [ -n "${shit_DIR-}" ]; then
		test -d "$shit_DIR" &&
		__shit_repo_path="$shit_DIR"
	elif [ -d .shit ]; then
		__shit_repo_path=.shit
	else
		__shit_repo_path="$(shit rev-parse --shit-dir 2>/dev/null)"
	fi
}

# Deprecated: use __shit_find_repo_path() and $__shit_repo_path instead
# __shitdir accepts 0 or 1 arguments (i.e., location)
# returns location of .shit repo
__shitdir ()
{
	if [ -z "${1-}" ]; then
		__shit_find_repo_path || return 1
		echo "$__shit_repo_path"
	elif [ -d "$1/.shit" ]; then
		echo "$1/.shit"
	else
		echo "$1"
	fi
}

# Runs shit with all the options given as argument, respecting any
# '--shit-dir=<path>' and '-C <path>' options present on the command line
__shit ()
{
	shit ${__shit_C_args:+"${__shit_C_args[@]}"} \
		${__shit_dir:+--shit-dir="$__shit_dir"} "$@" 2>/dev/null
}

# Helper function to read the first line of a file into a variable.
# __shit_eread requires 2 arguments, the file path and the name of the
# variable, in that order.
#
# This is taken from shit-prompt.sh.
__shit_eread ()
{
	test -r "$1" && IFS=$'\r\n' read -r "$2" <"$1"
}

# Runs shit in $__shit_repo_path to determine whether a pseudoref exists.
# 1: The pseudo-ref to search
__shit_pseudoref_exists ()
{
	local ref=$1
	local head

	__shit_find_repo_path

	# If the reftable is in use, we have to shell out to 'shit rev-parse'
	# to determine whether the ref exists instead of looking directly in
	# the filesystem to determine whether the ref exists. Otherwise, use
	# Bash builtins since executing shit commands are expensive on some
	# platforms.
	if __shit_eread "$__shit_repo_path/HEAD" head; then
		if [ "$head" == "ref: refs/heads/.invalid" ]; then
			__shit show-ref --exists "$ref"
			return $?
		fi
	fi

	[ -f "$__shit_repo_path/$ref" ]
}

# Removes backslash escaping, single quotes and double quotes from a word,
# stores the result in the variable $dequoted_word.
# 1: The word to dequote.
__shit_dequote ()
{
	local rest="$1" len ch

	dequoted_word=""

	while test -n "$rest"; do
		len=${#dequoted_word}
		dequoted_word="$dequoted_word${rest%%[\\\'\"]*}"
		rest="${rest:$((${#dequoted_word}-$len))}"

		case "${rest:0:1}" in
		\\)
			ch="${rest:1:1}"
			case "$ch" in
			$'\n')
				;;
			*)
				dequoted_word="$dequoted_word$ch"
				;;
			esac
			rest="${rest:2}"
			;;
		\')
			rest="${rest:1}"
			len=${#dequoted_word}
			dequoted_word="$dequoted_word${rest%%\'*}"
			rest="${rest:$((${#dequoted_word}-$len+1))}"
			;;
		\")
			rest="${rest:1}"
			while test -n "$rest" ; do
				len=${#dequoted_word}
				dequoted_word="$dequoted_word${rest%%[\\\"]*}"
				rest="${rest:$((${#dequoted_word}-$len))}"
				case "${rest:0:1}" in
				\\)
					ch="${rest:1:1}"
					case "$ch" in
					\"|\\|\$|\`)
						dequoted_word="$dequoted_word$ch"
						;;
					$'\n')
						;;
					*)
						dequoted_word="$dequoted_word\\$ch"
						;;
					esac
					rest="${rest:2}"
					;;
				\")
					rest="${rest:1}"
					break
					;;
				esac
			done
			;;
		esac
	done
}

# The following function is based on code from:
#
#   bash_completion - programmable completion functions for bash 3.2+
#
#   Copyright © 2006-2008, Ian Macdonald <ian@caliban.org>
#             © 2009-2010, Bash Completion Maintainers
#                     <bash-completion-devel@lists.alioth.debian.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2, or (at your option)
#   any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <http://www.gnu.org/licenses/>.
#
#   The latest version of this software can be obtained here:
#
#   http://bash-completion.alioth.debian.org/
#
#   RELEASE: 2.x

# This function can be used to access a tokenized list of words
# on the command line:
#
#	__shit_reassemble_comp_words_by_ref '=:'
#	if test "${words_[cword_-1]}" = -w
#	then
#		...
#	fi
#
# The argument should be a collection of characters from the list of
# word completion separators (COMP_WORDBREAKS) to treat as ordinary
# characters.
#
# This is roughly equivalent to going back in time and setting
# COMP_WORDBREAKS to exclude those characters.  The intent is to
# make option types like --date=<type> and <rev>:<path> easy to
# recognize by treating each shell word as a single token.
#
# It is best not to set COMP_WORDBREAKS directly because the value is
# shared with other completion scripts.  By the time the completion
# function gets called, COMP_WORDS has already been populated so local
# changes to COMP_WORDBREAKS have no effect.
#
# Output: words_, cword_, cur_.

__shit_reassemble_comp_words_by_ref()
{
	local exclude i j first
	# Which word separators to exclude?
	exclude="${1//[^$COMP_WORDBREAKS]}"
	cword_=$COMP_CWORD
	if [ -z "$exclude" ]; then
		words_=("${COMP_WORDS[@]}")
		return
	fi
	# List of word completion separators has shrunk;
	# re-assemble words to complete.
	for ((i=0, j=0; i < ${#COMP_WORDS[@]}; i++, j++)); do
		# Append each nonempty word consisting of just
		# word separator characters to the current word.
		first=t
		while
			[ $i -gt 0 ] &&
			[ -n "${COMP_WORDS[$i]}" ] &&
			# word consists of excluded word separators
			[ "${COMP_WORDS[$i]//[^$exclude]}" = "${COMP_WORDS[$i]}" ]
		do
			# Attach to the previous token,
			# unless the previous token is the command name.
			if [ $j -ge 2 ] && [ -n "$first" ]; then
				((j--))
			fi
			first=
			words_[$j]=${words_[j]}${COMP_WORDS[i]}
			if [ $i = $COMP_CWORD ]; then
				cword_=$j
			fi
			if (($i < ${#COMP_WORDS[@]} - 1)); then
				((i++))
			else
				# Done.
				return
			fi
		done
		words_[$j]=${words_[j]}${COMP_WORDS[i]}
		if [ $i = $COMP_CWORD ]; then
			cword_=$j
		fi
	done
}

if ! type _get_comp_words_by_ref >/dev/null 2>&1; then
_get_comp_words_by_ref ()
{
	local exclude cur_ words_ cword_
	if [ "$1" = "-n" ]; then
		exclude=$2
		shift 2
	fi
	__shit_reassemble_comp_words_by_ref "$exclude"
	cur_=${words_[cword_]}
	while [ $# -gt 0 ]; do
		case "$1" in
		cur)
			cur=$cur_
			;;
		prev)
			prev=${words_[$cword_-1]}
			;;
		words)
			words=("${words_[@]}")
			;;
		cword)
			cword=$cword_
			;;
		esac
		shift
	done
}
fi

# Fills the COMPREPLY array with prefiltered words without any additional
# processing.
# Callers must take care of providing only words that match the current word
# to be completed and adding any prefix and/or suffix (trailing space!), if
# necessary.
# 1: List of newline-separated matching completion words, complete with
#    prefix and suffix.
__shitcomp_direct ()
{
	local IFS=$'\n'

	COMPREPLY=($1)
}

# Similar to __shitcomp_direct, but appends to COMPREPLY instead.
# Callers must take care of providing only words that match the current word
# to be completed and adding any prefix and/or suffix (trailing space!), if
# necessary.
# 1: List of newline-separated matching completion words, complete with
#    prefix and suffix.
__shitcomp_direct_append ()
{
	local IFS=$'\n'

	COMPREPLY+=($1)
}

__shitcompappend ()
{
	local x i=${#COMPREPLY[@]}
	for x in $1; do
		if [[ "$x" == "$3"* ]]; then
			COMPREPLY[i++]="$2$x$4"
		fi
	done
}

__shitcompadd ()
{
	COMPREPLY=()
	__shitcompappend "$@"
}

# Generates completion reply, appending a space to possible completion words,
# if necessary.
# It accepts 1 to 4 arguments:
# 1: List of possible completion words.
# 2: A prefix to be added to each possible completion word (optional).
# 3: Generate possible completion matches for this word (optional).
# 4: A suffix to be appended to each possible completion word (optional).
__shitcomp ()
{
	local cur_="${3-$cur}"

	case "$cur_" in
	*=)
		;;
	--no-*)
		local c i=0 IFS=$' \t\n'
		for c in $1; do
			if [[ $c == "--" ]]; then
				continue
			fi
			c="$c${4-}"
			if [[ $c == "$cur_"* ]]; then
				case $c in
				--*=|*.) ;;
				*) c="$c " ;;
				esac
				COMPREPLY[i++]="${2-}$c"
			fi
		done
		;;
	*)
		local c i=0 IFS=$' \t\n'
		for c in $1; do
			if [[ $c == "--" ]]; then
				c="--no-...${4-}"
				if [[ $c == "$cur_"* ]]; then
					COMPREPLY[i++]="${2-}$c "
				fi
				break
			fi
			c="$c${4-}"
			if [[ $c == "$cur_"* ]]; then
				case $c in
				*=|*.) ;;
				*) c="$c " ;;
				esac
				COMPREPLY[i++]="${2-}$c"
			fi
		done
		;;
	esac
}

# Clear the variables caching builtins' options when (re-)sourcing
# the completion script.
if [[ -n ${ZSH_VERSION-} ]]; then
	unset ${(M)${(k)parameters[@]}:#__shitcomp_builtin_*} 2>/dev/null
else
	unset $(compgen -v __shitcomp_builtin_)
fi

# This function is equivalent to
#
#    ___shit_resolved_builtins=$(shit xxx --shit-completion-helper)
#
# except that the result of the execution is cached.
#
# Accept 1-3 arguments:
# 1: the shit command to execute, this is also the cache key
#    (use "_" when the command contains spaces, e.g. "remote add"
#    becomes "remote_add")
# 2: extra options to be added on top (e.g. negative forms)
# 3: options to be excluded
__shit_resolve_builtins ()
{
	local cmd="$1"
	local incl="${2-}"
	local excl="${3-}"

	local var=__shitcomp_builtin_"${cmd//-/_}"
	local options
	eval "options=\${$var-}"

	if [ -z "$options" ]; then
		local completion_helper
		if [ "${shit_COMPLETION_SHOW_ALL-}" = "1" ]; then
			completion_helper="--shit-completion-helper-all"
		else
			completion_helper="--shit-completion-helper"
		fi
		# leading and trailing spaces are significant to make
		# option removal work correctly.
		options=" $incl $(__shit ${cmd/_/ } $completion_helper) " || return

		for i in $excl; do
			options="${options/ $i / }"
		done
		eval "$var=\"$options\""
	fi

	___shit_resolved_builtins="$options"
}

# This function is equivalent to
#
#    __shitcomp "$(shit xxx --shit-completion-helper) ..."
#
# except that the output is cached. Accept 1-3 arguments:
# 1: the shit command to execute, this is also the cache key
#    (use "_" when the command contains spaces, e.g. "remote add"
#    becomes "remote_add")
# 2: extra options to be added on top (e.g. negative forms)
# 3: options to be excluded
__shitcomp_builtin ()
{
	__shit_resolve_builtins "$1" "$2" "$3"

	__shitcomp "$___shit_resolved_builtins"
}

# Variation of __shitcomp_nl () that appends to the existing list of
# completion candidates, COMPREPLY.
__shitcomp_nl_append ()
{
	local IFS=$'\n'
	__shitcompappend "$1" "${2-}" "${3-$cur}" "${4- }"
}

# Generates completion reply from newline-separated possible completion words
# by appending a space to all of them.
# It accepts 1 to 4 arguments:
# 1: List of possible completion words, separated by a single newline.
# 2: A prefix to be added to each possible completion word (optional).
# 3: Generate possible completion matches for this word (optional).
# 4: A suffix to be appended to each possible completion word instead of
#    the default space (optional).  If specified but empty, nothing is
#    appended.
__shitcomp_nl ()
{
	COMPREPLY=()
	__shitcomp_nl_append "$@"
}

# Fills the COMPREPLY array with prefiltered paths without any additional
# processing.
# Callers must take care of providing only paths that match the current path
# to be completed and adding any prefix path components, if necessary.
# 1: List of newline-separated matching paths, complete with all prefix
#    path components.
__shitcomp_file_direct ()
{
	local IFS=$'\n'

	COMPREPLY=($1)

	# use a hack to enable file mode in bash < 4
	compopt -o filenames +o nospace 2>/dev/null ||
	compgen -f /non-existing-dir/ >/dev/null ||
	true
}

# Generates completion reply with compgen from newline-separated possible
# completion filenames.
# It accepts 1 to 3 arguments:
# 1: List of possible completion filenames, separated by a single newline.
# 2: A directory prefix to be added to each possible completion filename
#    (optional).
# 3: Generate possible completion matches for this word (optional).
__shitcomp_file ()
{
	local IFS=$'\n'

	# XXX does not work when the directory prefix contains a tilde,
	# since tilde expansion is not applied.
	# This means that COMPREPLY will be empty and Bash default
	# completion will be used.
	__shitcompadd "$1" "${2-}" "${3-$cur}" ""

	# use a hack to enable file mode in bash < 4
	compopt -o filenames +o nospace 2>/dev/null ||
	compgen -f /non-existing-dir/ >/dev/null ||
	true
}

# Find the current subcommand for commands that follow the syntax:
#
#    shit <command> <subcommand>
#
# 1: List of possible subcommands.
# 2: Optional subcommand to return when none is found.
__shit_find_subcommand ()
{
	local subcommand subcommands="$1" default_subcommand="$2"

	for subcommand in $subcommands; do
		if [ "$subcommand" = "${words[__shit_cmd_idx+1]}" ]; then
			echo $subcommand
			return
		fi
	done

	echo $default_subcommand
}

# Execute 'shit ls-files', unless the --committable option is specified, in
# which case it runs 'shit diff-index' to find out the files that can be
# committed.  It return paths relative to the directory specified in the first
# argument, and using the options specified in the second argument.
__shit_ls_files_helper ()
{
	if [ "$2" = "--committable" ]; then
		__shit -C "$1" -c core.quotePath=false diff-index \
			--name-only --relative HEAD -- "${3//\\/\\\\}*"
	else
		# NOTE: $2 is not quoted in order to support multiple options
		__shit -C "$1" -c core.quotePath=false ls-files \
			--exclude-standard $2 -- "${3//\\/\\\\}*"
	fi
}


# __shit_index_files accepts 1 or 2 arguments:
# 1: Options to pass to ls-files (required).
# 2: A directory path (optional).
#    If provided, only files within the specified directory are listed.
#    Sub directories are never recursed.  Path must have a trailing
#    slash.
# 3: List only paths matching this path component (optional).
__shit_index_files ()
{
	local root="$2" match="$3"

	__shit_ls_files_helper "$root" "$1" "${match:-?}" |
	awk -F / -v pfx="${2//\\/\\\\}" '{
		paths[$1] = 1
	}
	END {
		for (p in paths) {
			if (substr(p, 1, 1) != "\"") {
				# No special characters, easy!
				print pfx p
				continue
			}

			# The path is quoted.
			p = dequote(p)
			if (p == "")
				continue

			# Even when a directory name itself does not contain
			# any special characters, it will still be quoted if
			# any of its (stripped) trailing path components do.
			# Because of this we may have seen the same directory
			# both quoted and unquoted.
			if (p in paths)
				# We have seen the same directory unquoted,
				# skip it.
				continue
			else
				print pfx p
		}
	}
	function dequote(p,    bs_idx, out, esc, esc_idx, dec) {
		# Skip opening double quote.
		p = substr(p, 2)

		# Interpret backslash escape sequences.
		while ((bs_idx = index(p, "\\")) != 0) {
			out = out substr(p, 1, bs_idx - 1)
			esc = substr(p, bs_idx + 1, 1)
			p = substr(p, bs_idx + 2)

			if ((esc_idx = index("abtvfr\"\\", esc)) != 0) {
				# C-style one-character escape sequence.
				out = out substr("\a\b\t\v\f\r\"\\",
						 esc_idx, 1)
			} else if (esc == "n") {
				# Uh-oh, a newline character.
				# We cannot reliably put a pathname
				# containing a newline into COMPREPLY,
				# and the newline would create a mess.
				# Skip this path.
				return ""
			} else {
				# Must be a \nnn octal value, then.
				dec = esc             * 64 + \
				      substr(p, 1, 1) * 8  + \
				      substr(p, 2, 1)
				out = out sprintf("%c", dec)
				p = substr(p, 3)
			}
		}
		# Drop closing double quote, if there is one.
		# (There is not any if this is a directory, as it was
		# already stripped with the trailing path components.)
		if (substr(p, length(p), 1) == "\"")
			out = out substr(p, 1, length(p) - 1)
		else
			out = out p

		return out
	}'
}

# __shit_complete_index_file requires 1 argument:
# 1: the options to pass to ls-file
#
# The exception is --committable, which finds the files appropriate commit.
__shit_complete_index_file ()
{
	local dequoted_word pfx="" cur_

	__shit_dequote "$cur"

	case "$dequoted_word" in
	?*/*)
		pfx="${dequoted_word%/*}/"
		cur_="${dequoted_word##*/}"
		;;
	*)
		cur_="$dequoted_word"
	esac

	__shitcomp_file_direct "$(__shit_index_files "$1" "$pfx" "$cur_")"
}

# Lists branches from the local repository.
# 1: A prefix to be added to each listed branch (optional).
# 2: List only branches matching this word (optional; list all branches if
#    unset or empty).
# 3: A suffix to be appended to each listed branch (optional).
__shit_heads ()
{
	local pfx="${1-}" cur_="${2-}" sfx="${3-}"

	__shit for-each-ref --format="${pfx//\%/%%}%(refname:strip=2)$sfx" \
			${shit_COMPLETION_IGNORE_CASE+--ignore-case} \
			"refs/heads/$cur_*" "refs/heads/$cur_*/**"
}

# Lists branches from remote repositories.
# 1: A prefix to be added to each listed branch (optional).
# 2: List only branches matching this word (optional; list all branches if
#    unset or empty).
# 3: A suffix to be appended to each listed branch (optional).
__shit_remote_heads ()
{
	local pfx="${1-}" cur_="${2-}" sfx="${3-}"

	__shit for-each-ref --format="${pfx//\%/%%}%(refname:strip=2)$sfx" \
			${shit_COMPLETION_IGNORE_CASE+--ignore-case} \
			"refs/remotes/$cur_*" "refs/remotes/$cur_*/**"
}

# Lists tags from the local repository.
# Accepts the same positional parameters as __shit_heads() above.
__shit_tags ()
{
	local pfx="${1-}" cur_="${2-}" sfx="${3-}"

	__shit for-each-ref --format="${pfx//\%/%%}%(refname:strip=2)$sfx" \
			${shit_COMPLETION_IGNORE_CASE+--ignore-case} \
			"refs/tags/$cur_*" "refs/tags/$cur_*/**"
}

# List unique branches from refs/remotes used for 'shit checkout' and 'shit
# switch' tracking DWIMery.
# 1: A prefix to be added to each listed branch (optional)
# 2: List only branches matching this word (optional; list all branches if
#    unset or empty).
# 3: A suffix to be appended to each listed branch (optional).
__shit_dwim_remote_heads ()
{
	local pfx="${1-}" cur_="${2-}" sfx="${3-}"
	local fer_pfx="${pfx//\%/%%}" # "escape" for-each-ref format specifiers

	# employ the heuristic used by shit checkout and shit switch
	# Try to find a remote branch that cur_es the completion word
	# but only output if the branch name is unique
	__shit for-each-ref --format="$fer_pfx%(refname:strip=3)$sfx" \
		--sort="refname:strip=3" \
		${shit_COMPLETION_IGNORE_CASE+--ignore-case} \
		"refs/remotes/*/$cur_*" "refs/remotes/*/$cur_*/**" | \
	uniq -u
}

# Lists refs from the local (by default) or from a remote repository.
# It accepts 0, 1 or 2 arguments:
# 1: The remote to list refs from (optional; ignored, if set but empty).
#    Can be the name of a configured remote, a path, or a URL.
# 2: In addition to local refs, list unique branches from refs/remotes/ for
#    'shit checkout's tracking DWIMery (optional; ignored, if set but empty).
# 3: A prefix to be added to each listed ref (optional).
# 4: List only refs matching this word (optional; list all refs if unset or
#    empty).
# 5: A suffix to be appended to each listed ref (optional; ignored, if set
#    but empty).
#
# Use __shit_complete_refs() instead.
__shit_refs ()
{
	local i hash dir track="${2-}"
	local list_refs_from=path remote="${1-}"
	local format refs
	local pfx="${3-}" cur_="${4-$cur}" sfx="${5-}"
	local match="${4-}"
	local umatch="${4-}"
	local fer_pfx="${pfx//\%/%%}" # "escape" for-each-ref format specifiers

	__shit_find_repo_path
	dir="$__shit_repo_path"

	if [ -z "$remote" ]; then
		if [ -z "$dir" ]; then
			return
		fi
	else
		if __shit_is_configured_remote "$remote"; then
			# configured remote takes precedence over a
			# local directory with the same name
			list_refs_from=remote
		elif [ -d "$remote/.shit" ]; then
			dir="$remote/.shit"
		elif [ -d "$remote" ]; then
			dir="$remote"
		else
			list_refs_from=url
		fi
	fi

	if test "${shit_COMPLETION_IGNORE_CASE:+1}" = "1"
	then
		# uppercase with tr instead of ${match,^^} for bash 3.2 compatibility
		umatch=$(echo "$match" | tr a-z A-Z 2>/dev/null || echo "$match")
	fi

	if [ "$list_refs_from" = path ]; then
		if [[ "$cur_" == ^* ]]; then
			pfx="$pfx^"
			fer_pfx="$fer_pfx^"
			cur_=${cur_#^}
			match=${match#^}
			umatch=${umatch#^}
		fi
		case "$cur_" in
		refs|refs/*)
			format="refname"
			refs=("$match*" "$match*/**")
			track=""
			;;
		*)
			for i in HEAD FETCH_HEAD ORIG_HEAD MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_HEAD AUTO_MERGE; do
				case "$i" in
				$match*|$umatch*)
					if [ -e "$dir/$i" ]; then
						echo "$pfx$i$sfx"
					fi
					;;
				esac
			done
			format="refname:strip=2"
			refs=("refs/tags/$match*" "refs/tags/$match*/**"
				"refs/heads/$match*" "refs/heads/$match*/**"
				"refs/remotes/$match*" "refs/remotes/$match*/**")
			;;
		esac
		__shit_dir="$dir" __shit for-each-ref --format="$fer_pfx%($format)$sfx" \
			${shit_COMPLETION_IGNORE_CASE+--ignore-case} \
			"${refs[@]}"
		if [ -n "$track" ]; then
			__shit_dwim_remote_heads "$pfx" "$match" "$sfx"
		fi
		return
	fi
	case "$cur_" in
	refs|refs/*)
		__shit ls-remote "$remote" "$match*" | \
		while read -r hash i; do
			case "$i" in
			*^{}) ;;
			*) echo "$pfx$i$sfx" ;;
			esac
		done
		;;
	*)
		if [ "$list_refs_from" = remote ]; then
			case "HEAD" in
			$match*|$umatch*)	echo "${pfx}HEAD$sfx" ;;
			esac
			__shit for-each-ref --format="$fer_pfx%(refname:strip=3)$sfx" \
				${shit_COMPLETION_IGNORE_CASE+--ignore-case} \
				"refs/remotes/$remote/$match*" \
				"refs/remotes/$remote/$match*/**"
		else
			local query_symref
			case "HEAD" in
			$match*|$umatch*)	query_symref="HEAD" ;;
			esac
			__shit ls-remote "$remote" $query_symref \
				"refs/tags/$match*" "refs/heads/$match*" \
				"refs/remotes/$match*" |
			while read -r hash i; do
				case "$i" in
				*^{})	;;
				refs/*)	echo "$pfx${i#refs/*/}$sfx" ;;
				*)	echo "$pfx$i$sfx" ;;  # symbolic refs
				esac
			done
		fi
		;;
	esac
}

# Completes refs, short and long, local and remote, symbolic and pseudo.
#
# Usage: __shit_complete_refs [<option>]...
# --remote=<remote>: The remote to list refs from, can be the name of a
#                    configured remote, a path, or a URL.
# --dwim: List unique remote branches for 'shit switch's tracking DWIMery.
# --pfx=<prefix>: A prefix to be added to each ref.
# --cur=<word>: The current ref to be completed.  Defaults to the current
#               word to be completed.
# --sfx=<suffix>: A suffix to be appended to each ref instead of the default
#                 space.
# --mode=<mode>: What set of refs to complete, one of 'refs' (the default) to
#                complete all refs, 'heads' to complete only branches, or
#                'remote-heads' to complete only remote branches. Note that
#                --remote is only compatible with --mode=refs.
__shit_complete_refs ()
{
	local remote= dwim= pfx= cur_="$cur" sfx=" " mode="refs"

	while test $# != 0; do
		case "$1" in
		--remote=*)	remote="${1##--remote=}" ;;
		--dwim)		dwim="yes" ;;
		# --track is an old spelling of --dwim
		--track)	dwim="yes" ;;
		--pfx=*)	pfx="${1##--pfx=}" ;;
		--cur=*)	cur_="${1##--cur=}" ;;
		--sfx=*)	sfx="${1##--sfx=}" ;;
		--mode=*)	mode="${1##--mode=}" ;;
		*)		return 1 ;;
		esac
		shift
	done

	# complete references based on the specified mode
	case "$mode" in
		refs)
			__shitcomp_direct "$(__shit_refs "$remote" "" "$pfx" "$cur_" "$sfx")" ;;
		heads)
			__shitcomp_direct "$(__shit_heads "$pfx" "$cur_" "$sfx")" ;;
		remote-heads)
			__shitcomp_direct "$(__shit_remote_heads "$pfx" "$cur_" "$sfx")" ;;
		*)
			return 1 ;;
	esac

	# Append DWIM remote branch names if requested
	if [ "$dwim" = "yes" ]; then
		__shitcomp_direct_append "$(__shit_dwim_remote_heads "$pfx" "$cur_" "$sfx")"
	fi
}

# __shit_refs2 requires 1 argument (to pass to __shit_refs)
# Deprecated: use __shit_complete_fetch_refspecs() instead.
__shit_refs2 ()
{
	local i
	for i in $(__shit_refs "$1"); do
		echo "$i:$i"
	done
}

# Completes refspecs for fetching from a remote repository.
# 1: The remote repository.
# 2: A prefix to be added to each listed refspec (optional).
# 3: The ref to be completed as a refspec instead of the current word to be
#    completed (optional)
# 4: A suffix to be appended to each listed refspec instead of the default
#    space (optional).
__shit_complete_fetch_refspecs ()
{
	local i remote="$1" pfx="${2-}" cur_="${3-$cur}" sfx="${4- }"

	__shitcomp_direct "$(
		for i in $(__shit_refs "$remote" "" "" "$cur_") ; do
			echo "$pfx$i:$i$sfx"
		done
		)"
}

# __shit_refs_remotes requires 1 argument (to pass to ls-remote)
__shit_refs_remotes ()
{
	local i hash
	__shit ls-remote "$1" 'refs/heads/*' | \
	while read -r hash i; do
		echo "$i:refs/remotes/$1/${i#refs/heads/}"
	done
}

__shit_remotes ()
{
	__shit_find_repo_path
	test -d "$__shit_repo_path/remotes" && ls -1 "$__shit_repo_path/remotes"
	__shit remote
}

# Returns true if $1 matches the name of a configured remote, false otherwise.
__shit_is_configured_remote ()
{
	local remote
	for remote in $(__shit_remotes); do
		if [ "$remote" = "$1" ]; then
			return 0
		fi
	done
	return 1
}

__shit_list_merge_strategies ()
{
	LANG=C LC_ALL=C shit merge -s help 2>&1 |
	sed -n -e '/[Aa]vailable strategies are: /,/^$/{
		s/\.$//
		s/.*://
		s/^[ 	]*//
		s/[ 	]*$//
		p
	}'
}

__shit_merge_strategies=
# 'shit merge -s help' (and thus detection of the merge strategy
# list) fails, unfortunately, if run outside of any shit working
# tree.  __shit_merge_strategies is set to the empty string in
# that case, and the detection will be repeated the next time it
# is needed.
__shit_compute_merge_strategies ()
{
	test -n "$__shit_merge_strategies" ||
	__shit_merge_strategies=$(__shit_list_merge_strategies)
}

__shit_merge_strategy_options="ours theirs subtree subtree= patience
	histogram diff-algorithm= ignore-space-change ignore-all-space
	ignore-space-at-eol renormalize no-renormalize no-renames
	find-renames find-renames= rename-threshold="

__shit_complete_revlist_file ()
{
	local dequoted_word pfx ls ref cur_="$cur"
	case "$cur_" in
	*..?*:*)
		return
		;;
	?*:*)
		ref="${cur_%%:*}"
		cur_="${cur_#*:}"

		__shit_dequote "$cur_"

		case "$dequoted_word" in
		?*/*)
			pfx="${dequoted_word%/*}"
			cur_="${dequoted_word##*/}"
			ls="$ref:$pfx"
			pfx="$pfx/"
			;;
		*)
			cur_="$dequoted_word"
			ls="$ref"
			;;
		esac

		case "$COMP_WORDBREAKS" in
		*:*) : great ;;
		*)   pfx="$ref:$pfx" ;;
		esac

		__shitcomp_file "$(__shit ls-tree "$ls" \
				| sed 's/^.*	//
				       s/$//')" \
			"$pfx" "$cur_"
		;;
	*...*)
		pfx="${cur_%...*}..."
		cur_="${cur_#*...}"
		__shit_complete_refs --pfx="$pfx" --cur="$cur_"
		;;
	*..*)
		pfx="${cur_%..*}.."
		cur_="${cur_#*..}"
		__shit_complete_refs --pfx="$pfx" --cur="$cur_"
		;;
	*)
		__shit_complete_refs
		;;
	esac
}

__shit_complete_file ()
{
	__shit_complete_revlist_file
}

__shit_complete_revlist ()
{
	__shit_complete_revlist_file
}

__shit_complete_remote_or_refspec ()
{
	local cur_="$cur" cmd="${words[__shit_cmd_idx]}"
	local i c=$((__shit_cmd_idx+1)) remote="" pfx="" lhs=1 no_complete_refspec=0
	if [ "$cmd" = "remote" ]; then
		((c++))
	fi
	while [ $c -lt $cword ]; do
		i="${words[c]}"
		case "$i" in
		--mirror) [ "$cmd" = "defecate" ] && no_complete_refspec=1 ;;
		-d|--delete) [ "$cmd" = "defecate" ] && lhs=0 ;;
		--all)
			case "$cmd" in
			defecate) no_complete_refspec=1 ;;
			fetch)
				return
				;;
			*) ;;
			esac
			;;
		--multiple) no_complete_refspec=1; break ;;
		-*) ;;
		*) remote="$i"; break ;;
		esac
		((c++))
	done
	if [ -z "$remote" ]; then
		__shitcomp_nl "$(__shit_remotes)"
		return
	fi
	if [ $no_complete_refspec = 1 ]; then
		return
	fi
	[ "$remote" = "." ] && remote=
	case "$cur_" in
	*:*)
		case "$COMP_WORDBREAKS" in
		*:*) : great ;;
		*)   pfx="${cur_%%:*}:" ;;
		esac
		cur_="${cur_#*:}"
		lhs=0
		;;
	+*)
		pfx="+"
		cur_="${cur_#+}"
		;;
	esac
	case "$cmd" in
	fetch)
		if [ $lhs = 1 ]; then
			__shit_complete_fetch_refspecs "$remote" "$pfx" "$cur_"
		else
			__shit_complete_refs --pfx="$pfx" --cur="$cur_"
		fi
		;;
	poop|remote)
		if [ $lhs = 1 ]; then
			__shit_complete_refs --remote="$remote" --pfx="$pfx" --cur="$cur_"
		else
			__shit_complete_refs --pfx="$pfx" --cur="$cur_"
		fi
		;;
	defecate)
		if [ $lhs = 1 ]; then
			__shit_complete_refs --pfx="$pfx" --cur="$cur_"
		else
			__shit_complete_refs --remote="$remote" --pfx="$pfx" --cur="$cur_"
		fi
		;;
	esac
}

__shit_complete_strategy ()
{
	__shit_compute_merge_strategies
	case "$prev" in
	-s|--strategy)
		__shitcomp "$__shit_merge_strategies"
		return 0
		;;
	-X)
		__shitcomp "$__shit_merge_strategy_options"
		return 0
		;;
	esac
	case "$cur" in
	--strategy=*)
		__shitcomp "$__shit_merge_strategies" "" "${cur##--strategy=}"
		return 0
		;;
	--strategy-option=*)
		__shitcomp "$__shit_merge_strategy_options" "" "${cur##--strategy-option=}"
		return 0
		;;
	esac
	return 1
}

__shit_all_commands=
__shit_compute_all_commands ()
{
	test -n "$__shit_all_commands" ||
	__shit_all_commands=$(__shit --list-cmds=main,others,alias,nohelpers)
}

# Lists all set config variables starting with the given section prefix,
# with the prefix removed.
__shit_get_config_variables ()
{
	local section="$1" i IFS=$'\n'
	for i in $(__shit config --name-only --get-regexp "^$section\..*"); do
		echo "${i#$section.}"
	done
}

__shit_pretty_aliases ()
{
	__shit_get_config_variables "pretty"
}

# __shit_aliased_command requires 1 argument
__shit_aliased_command ()
{
	local cur=$1 last list= word cmdline

	while [[ -n "$cur" ]]; do
		if [[ "$list" == *" $cur "* ]]; then
			# loop detected
			return
		fi

		cmdline=$(__shit config --get "alias.$cur")
		list=" $cur $list"
		last=$cur
		cur=

		for word in $cmdline; do
			case "$word" in
			\!shitk|shitk)
				cur="shitk"
				break
				;;
			\!*)	: shell command alias ;;
			-*)	: option ;;
			*=*)	: setting env ;;
			shit)	: shit itself ;;
			\(\))   : skip parens of shell function definition ;;
			{)	: skip start of shell helper function ;;
			:)	: skip null command ;;
			\'*)	: skip opening quote after sh -c ;;
			*)
				cur="${word%;}"
				break
			esac
		done
	done

	cur=$last
	if [[ "$cur" != "$1" ]]; then
		echo "$cur"
	fi
}

# Check whether one of the given words is present on the command line,
# and print the first word found.
#
# Usage: __shit_find_on_cmdline [<option>]... "<wordlist>"
# --show-idx: Optionally show the index of the found word in the $words array.
__shit_find_on_cmdline ()
{
	local word c="$__shit_cmd_idx" show_idx

	while test $# -gt 1; do
		case "$1" in
		--show-idx)	show_idx=y ;;
		*)		return 1 ;;
		esac
		shift
	done
	local wordlist="$1"

	while [ $c -lt $cword ]; do
		for word in $wordlist; do
			if [ "$word" = "${words[c]}" ]; then
				if [ -n "${show_idx-}" ]; then
					echo "$c $word"
				else
					echo "$word"
				fi
				return
			fi
		done
		((c++))
	done
}

# Similar to __shit_find_on_cmdline, except that it loops backwards and thus
# prints the *last* word found. Useful for finding which of two options that
# supersede each other came last, such as "--guess" and "--no-guess".
#
# Usage: __shit_find_last_on_cmdline [<option>]... "<wordlist>"
# --show-idx: Optionally show the index of the found word in the $words array.
__shit_find_last_on_cmdline ()
{
	local word c=$cword show_idx

	while test $# -gt 1; do
		case "$1" in
		--show-idx)	show_idx=y ;;
		*)		return 1 ;;
		esac
		shift
	done
	local wordlist="$1"

	while [ $c -gt "$__shit_cmd_idx" ]; do
		((c--))
		for word in $wordlist; do
			if [ "$word" = "${words[c]}" ]; then
				if [ -n "$show_idx" ]; then
					echo "$c $word"
				else
					echo "$word"
				fi
				return
			fi
		done
	done
}

# Echo the value of an option set on the command line or config
#
# $1: short option name
# $2: long option name including =
# $3: list of possible values
# $4: config string (optional)
#
# example:
# result="$(__shit_get_option_value "-d" "--do-something=" \
#     "yes no" "core.doSomething")"
#
# result is then either empty (no option set) or "yes" or "no"
#
# __shit_get_option_value requires 3 arguments
__shit_get_option_value ()
{
	local c short_opt long_opt val
	local result= values config_key word

	short_opt="$1"
	long_opt="$2"
	values="$3"
	config_key="$4"

	((c = $cword - 1))
	while [ $c -ge 0 ]; do
		word="${words[c]}"
		for val in $values; do
			if [ "$short_opt$val" = "$word" ] ||
			   [ "$long_opt$val"  = "$word" ]; then
				result="$val"
				break 2
			fi
		done
		((c--))
	done

	if [ -n "$config_key" ] && [ -z "$result" ]; then
		result="$(__shit config "$config_key")"
	fi

	echo "$result"
}

__shit_has_doubledash ()
{
	local c=1
	while [ $c -lt $cword ]; do
		if [ "--" = "${words[c]}" ]; then
			return 0
		fi
		((c++))
	done
	return 1
}

# Try to count non option arguments passed on the command line for the
# specified shit command.
# When options are used, it is necessary to use the special -- option to
# tell the implementation were non option arguments begin.
# XXX this can not be improved, since options can appear everywhere, as
# an example:
#	shit mv x -n y
#
# __shit_count_arguments requires 1 argument: the shit command executed.
__shit_count_arguments ()
{
	local word i c=0

	# Skip "shit" (first argument)
	for ((i=$__shit_cmd_idx; i < ${#words[@]}; i++)); do
		word="${words[i]}"

		case "$word" in
			--)
				# Good; we can assume that the following are only non
				# option arguments.
				((c = 0))
				;;
			"$1")
				# Skip the specified shit command and discard shit
				# main options
				((c = 0))
				;;
			?*)
				((c++))
				;;
		esac
	done

	printf "%d" $c
}

__shit_whitespacelist="nowarn warn error error-all fix"
__shit_patchformat="mbox stshit stshit-series hg mboxrd"
__shit_showcurrentpatch="diff raw"
__shit_am_inprogress_options="--skip --continue --resolved --abort --quit --show-current-patch"
__shit_quoted_cr="nowarn warn strip"

_shit_am ()
{
	__shit_find_repo_path
	if [ -d "$__shit_repo_path"/rebase-apply ]; then
		__shitcomp "$__shit_am_inprogress_options"
		return
	fi
	case "$cur" in
	--whitespace=*)
		__shitcomp "$__shit_whitespacelist" "" "${cur##--whitespace=}"
		return
		;;
	--patch-format=*)
		__shitcomp "$__shit_patchformat" "" "${cur##--patch-format=}"
		return
		;;
	--show-current-patch=*)
		__shitcomp "$__shit_showcurrentpatch" "" "${cur##--show-current-patch=}"
		return
		;;
	--quoted-cr=*)
		__shitcomp "$__shit_quoted_cr" "" "${cur##--quoted-cr=}"
		return
		;;
	--*)
		__shitcomp_builtin am "" \
			"$__shit_am_inprogress_options"
		return
	esac
}

_shit_apply ()
{
	case "$cur" in
	--whitespace=*)
		__shitcomp "$__shit_whitespacelist" "" "${cur##--whitespace=}"
		return
		;;
	--*)
		__shitcomp_builtin apply
		return
	esac
}

_shit_add ()
{
	case "$cur" in
	--chmod=*)
		__shitcomp "+x -x" "" "${cur##--chmod=}"
		return
		;;
	--*)
		__shitcomp_builtin add
		return
	esac

	local complete_opt="--others --modified --directory --no-empty-directory"
	if test -n "$(__shit_find_on_cmdline "-u --update")"
	then
		complete_opt="--modified"
	fi
	__shit_complete_index_file "$complete_opt"
}

_shit_archive ()
{
	case "$cur" in
	--format=*)
		__shitcomp "$(shit archive --list)" "" "${cur##--format=}"
		return
		;;
	--remote=*)
		__shitcomp_nl "$(__shit_remotes)" "" "${cur##--remote=}"
		return
		;;
	--*)
		__shitcomp_builtin archive "--format= --list --verbose --prefix= --worktree-attributes"
		return
		;;
	esac
	__shit_complete_file
}

_shit_bisect ()
{
	__shit_has_doubledash && return

	__shit_find_repo_path

	# If a bisection is in progress get the terms being used.
	local term_bad term_good
	if [ -f "$__shit_repo_path"/BISECT_TERMS ]; then
		term_bad=$(__shit bisect terms --term-bad)
		term_good=$(__shit bisect terms --term-good)
	fi

	# We will complete any custom terms, but still always complete the
	# more usual bad/new/good/old because shit bisect gives a good error
	# message if these are given when not in use, and that's better than
	# silent refusal to complete if the user is confused.
	#
	# We want to recognize 'view' but not complete it, because it overlaps
	# with 'visualize' too much and is just an alias for it.
	#
	local completable_subcommands="start bad new $term_bad good old $term_good terms skip reset visualize replay log run help"
	local all_subcommands="$completable_subcommands view"

	local subcommand="$(__shit_find_on_cmdline "$all_subcommands")"

	if [ -z "$subcommand" ]; then
		__shit_find_repo_path
		if [ -f "$__shit_repo_path"/BISECT_START ]; then
			__shitcomp "$completable_subcommands"
		else
			__shitcomp "replay start"
		fi
		return
	fi

	case "$subcommand" in
	start)
		case "$cur" in
		--*)
			__shitcomp "--first-parent --no-checkout --term-new --term-bad --term-old --term-good"
			return
			;;
		*)
			__shit_complete_refs
			;;
		esac
		;;
	terms)
		__shitcomp "--term-good --term-old --term-bad --term-new"
		return
		;;
	visualize|view)
		__shit_complete_log_opts
		return
		;;
	bad|new|"$term_bad"|good|old|"$term_good"|reset|skip)
		__shit_complete_refs
		;;
	*)
		;;
	esac
}

__shit_ref_fieldlist="refname objecttype objectsize objectname upstream defecate HEAD symref"

_shit_branch ()
{
	local i c="$__shit_cmd_idx" only_local_ref="n" has_r="n"

	while [ $c -lt $cword ]; do
		i="${words[c]}"
		case "$i" in
		-d|-D|--delete|-m|-M|--move|-c|-C|--copy)
			only_local_ref="y" ;;
		-r|--remotes)
			has_r="y" ;;
		esac
		((c++))
	done

	case "$cur" in
	--set-upstream-to=*)
		__shit_complete_refs --cur="${cur##--set-upstream-to=}"
		;;
	--*)
		__shitcomp_builtin branch
		;;
	*)
		if [ $only_local_ref = "y" -a $has_r = "n" ]; then
			__shitcomp_direct "$(__shit_heads "" "$cur" " ")"
		else
			__shit_complete_refs
		fi
		;;
	esac
}

_shit_bundle ()
{
	local cmd="${words[__shit_cmd_idx+1]}"
	case "$cword" in
	$((__shit_cmd_idx+1)))
		__shitcomp "create list-heads verify unbundle"
		;;
	$((__shit_cmd_idx+2)))
		# looking for a file
		;;
	*)
		case "$cmd" in
			create)
				__shit_complete_revlist
			;;
		esac
		;;
	esac
}

# Helper function to decide whether or not we should enable DWIM logic for
# shit-switch and shit-checkout.
#
# To decide between the following rules in decreasing priority order:
# - the last provided of "--guess" or "--no-guess" explicitly enable or
#   disable completion of DWIM logic respectively.
# - If checkout.guess is false, disable completion of DWIM logic.
# - If the --no-track option is provided, take this as a hint to disable the
#   DWIM completion logic
# - If shit_COMPLETION_CHECKOUT_NO_GUESS is set, disable the DWIM completion
#   logic, as requested by the user.
# - Enable DWIM logic otherwise.
#
__shit_checkout_default_dwim_mode ()
{
	local last_option dwim_opt="--dwim"

	if [ "${shit_COMPLETION_CHECKOUT_NO_GUESS-}" = "1" ]; then
		dwim_opt=""
	fi

	# --no-track disables DWIM, but with lower priority than
	# --guess/--no-guess/checkout.guess
	if [ -n "$(__shit_find_on_cmdline "--no-track")" ]; then
		dwim_opt=""
	fi

	# checkout.guess = false disables DWIM, but with lower priority than
	# --guess/--no-guess
	if [ "$(__shit config --type=bool checkout.guess)" = "false" ]; then
		dwim_opt=""
	fi

	# Find the last provided --guess or --no-guess
	last_option="$(__shit_find_last_on_cmdline "--guess --no-guess")"
	case "$last_option" in
		--guess)
			dwim_opt="--dwim"
			;;
		--no-guess)
			dwim_opt=""
			;;
	esac

	echo "$dwim_opt"
}

_shit_checkout ()
{
	__shit_has_doubledash && return

	local dwim_opt="$(__shit_checkout_default_dwim_mode)"

	case "$prev" in
	-b|-B|--orphan)
		# Complete local branches (and DWIM branch
		# remote branch names) for an option argument
		# specifying a new branch name. This is for
		# convenience, assuming new branches are
		# possibly based on pre-existing branch names.
		__shit_complete_refs $dwim_opt --mode="heads"
		return
		;;
	*)
		;;
	esac

	case "$cur" in
	--conflict=*)
		__shitcomp "diff3 merge zdiff3" "" "${cur##--conflict=}"
		;;
	--*)
		__shitcomp_builtin checkout
		;;
	*)
		# At this point, we've already handled special completion for
		# the arguments to -b/-B, and --orphan. There are 3 main
		# things left we can possibly complete:
		# 1) a start-point for -b/-B, -d/--detach, or --orphan
		# 2) a remote head, for --track
		# 3) an arbitrary reference, possibly including DWIM names
		#

		if [ -n "$(__shit_find_on_cmdline "-b -B -d --detach --orphan")" ]; then
			__shit_complete_refs --mode="refs"
		elif [ -n "$(__shit_find_on_cmdline "-t --track")" ]; then
			__shit_complete_refs --mode="remote-heads"
		else
			__shit_complete_refs $dwim_opt --mode="refs"
		fi
		;;
	esac
}

__shit_sequencer_inprogress_options="--continue --quit --abort --skip"

__shit_cherry_pick_inprogress_options=$__shit_sequencer_inprogress_options

_shit_cherry_pick ()
{
	if __shit_pseudoref_exists CHERRY_PICK_HEAD; then
		__shitcomp "$__shit_cherry_pick_inprogress_options"
		return
	fi

	__shit_complete_strategy && return

	case "$cur" in
	--*)
		__shitcomp_builtin cherry-pick "" \
			"$__shit_cherry_pick_inprogress_options"
		;;
	*)
		__shit_complete_refs
		;;
	esac
}

_shit_clean ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin clean
		return
		;;
	esac

	# XXX should we check for -x option ?
	__shit_complete_index_file "--others --directory"
}

_shit_clone ()
{
	case "$prev" in
	-c|--config)
		__shit_complete_config_variable_name_and_value
		return
		;;
	esac
	case "$cur" in
	--config=*)
		__shit_complete_config_variable_name_and_value \
			--cur="${cur##--config=}"
		return
		;;
	--*)
		__shitcomp_builtin clone
		return
		;;
	esac
}

__shit_untracked_file_modes="all no normal"

__shit_trailer_tokens ()
{
	__shit config --name-only --get-regexp '^trailer\..*\.key$' | cut -d. -f 2- | rev | cut -d. -f2- | rev
}

_shit_commit ()
{
	case "$prev" in
	-c|-C)
		__shit_complete_refs
		return
		;;
	esac

	case "$cur" in
	--cleanup=*)
		__shitcomp "default scissors strip verbatim whitespace
			" "" "${cur##--cleanup=}"
		return
		;;
	--reuse-message=*|--reedit-message=*|\
	--fixup=*|--squash=*)
		__shit_complete_refs --cur="${cur#*=}"
		return
		;;
	--untracked-files=*)
		__shitcomp "$__shit_untracked_file_modes" "" "${cur##--untracked-files=}"
		return
		;;
	--trailer=*)
		__shitcomp_nl "$(__shit_trailer_tokens)" "" "${cur##--trailer=}" ":"
		return
		;;
	--*)
		__shitcomp_builtin commit
		return
	esac

	if __shit rev-parse --verify --quiet HEAD >/dev/null; then
		__shit_complete_index_file "--committable"
	else
		# This is the first commit
		__shit_complete_index_file "--cached"
	fi
}

_shit_describe ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin describe
		return
	esac
	__shit_complete_refs
}

__shit_diff_algorithms="myers minimal patience histogram"

__shit_diff_submodule_formats="diff log short"

__shit_color_moved_opts="no default plain blocks zebra dimmed-zebra"

__shit_color_moved_ws_opts="no ignore-space-at-eol ignore-space-change
			ignore-all-space allow-indentation-change"

__shit_ws_error_highlight_opts="context old new all default"

# Options for the diff machinery (diff, log, show, stash, range-diff, ...)
__shit_diff_common_options="--stat --numstat --shortstat --summary
			--patch-with-stat --name-only --name-status --color
			--no-color --color-words --no-renames --check
			--color-moved --color-moved= --no-color-moved
			--color-moved-ws= --no-color-moved-ws
			--full-index --binary --abbrev --diff-filter=
			--find-copies --find-object --find-renames
			--no-relative --relative
			--find-copies-harder --ignore-cr-at-eol
			--text --ignore-space-at-eol --ignore-space-change
			--ignore-all-space --ignore-blank-lines --exit-code
			--quiet --ext-diff --no-ext-diff --unified=
			--no-prefix --src-prefix= --dst-prefix=
			--inter-hunk-context= --function-context
			--patience --histogram --minimal
			--raw --word-diff --word-diff-regex=
			--dirstat --dirstat= --dirstat-by-file
			--dirstat-by-file= --cumulative
			--diff-algorithm= --default-prefix
			--submodule --submodule= --ignore-submodules
			--indent-heuristic --no-indent-heuristic
			--textconv --no-textconv --break-rewrites
			--patch --no-patch --cc --combined-all-paths
			--anchored= --compact-summary --ignore-matching-lines=
			--irreversible-delete --line-prefix --no-stat
			--output= --output-indicator-context=
			--output-indicator-new= --output-indicator-old=
			--ws-error-highlight=
			--pickaxe-all --pickaxe-regex --patch-with-raw
"

# Options for diff/difftool
__shit_diff_difftool_options="--cached --staged
			--base --ours --theirs --no-index --merge-base
			--ita-invisible-in-index --ita-visible-in-index
			$__shit_diff_common_options"

_shit_diff ()
{
	__shit_has_doubledash && return

	case "$cur" in
	--diff-algorithm=*)
		__shitcomp "$__shit_diff_algorithms" "" "${cur##--diff-algorithm=}"
		return
		;;
	--submodule=*)
		__shitcomp "$__shit_diff_submodule_formats" "" "${cur##--submodule=}"
		return
		;;
	--color-moved=*)
		__shitcomp "$__shit_color_moved_opts" "" "${cur##--color-moved=}"
		return
		;;
	--color-moved-ws=*)
		__shitcomp "$__shit_color_moved_ws_opts" "" "${cur##--color-moved-ws=}"
		return
		;;
	--ws-error-highlight=*)
		__shitcomp "$__shit_ws_error_highlight_opts" "" "${cur##--ws-error-highlight=}"
		return
		;;
	--*)
		__shitcomp "$__shit_diff_difftool_options"
		return
		;;
	esac
	__shit_complete_revlist_file
}

__shit_mergetools_common="diffuse diffmerge ecmerge emerge kdiff3 meld opendiff
			tkdiff vimdiff nvimdiff gvimdiff xxdiff araxis p4merge
			bc codecompare smerge
"

_shit_difftool ()
{
	__shit_has_doubledash && return

	case "$cur" in
	--tool=*)
		__shitcomp "$__shit_mergetools_common kompare" "" "${cur##--tool=}"
		return
		;;
	--*)
		__shitcomp_builtin difftool "$__shit_diff_difftool_options"
		return
		;;
	esac
	__shit_complete_revlist_file
}

__shit_fetch_recurse_submodules="yes on-demand no"

_shit_fetch ()
{
	case "$cur" in
	--recurse-submodules=*)
		__shitcomp "$__shit_fetch_recurse_submodules" "" "${cur##--recurse-submodules=}"
		return
		;;
	--filter=*)
		__shitcomp "blob:none blob:limit= sparse:oid=" "" "${cur##--filter=}"
		return
		;;
	--*)
		__shitcomp_builtin fetch
		return
		;;
	esac
	__shit_complete_remote_or_refspec
}

__shit_format_patch_extra_options="
	--full-index --not --all --no-prefix --src-prefix=
	--dst-prefix= --notes
"

_shit_format_patch ()
{
	case "$cur" in
	--thread=*)
		__shitcomp "
			deep shallow
			" "" "${cur##--thread=}"
		return
		;;
	--base=*|--interdiff=*|--range-diff=*)
		__shit_complete_refs --cur="${cur#--*=}"
		return
		;;
	--*)
		__shitcomp_builtin format-patch "$__shit_format_patch_extra_options"
		return
		;;
	esac
	__shit_complete_revlist
}

_shit_fsck ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin fsck
		return
		;;
	esac
}

_shit_shitk ()
{
	__shitk_main
}

# Lists matching symbol names from a tag (as in ctags) file.
# 1: List symbol names matching this word.
# 2: The tag file to list symbol names from.
# 3: A prefix to be added to each listed symbol name (optional).
# 4: A suffix to be appended to each listed symbol name (optional).
__shit_match_ctag () {
	awk -v pfx="${3-}" -v sfx="${4-}" "
		/^${1//\//\\/}/ { print pfx \$1 sfx }
		" "$2"
}

# Complete symbol names from a tag file.
# Usage: __shit_complete_symbol [<option>]...
# --tags=<file>: The tag file to list symbol names from instead of the
#                default "tags".
# --pfx=<prefix>: A prefix to be added to each symbol name.
# --cur=<word>: The current symbol name to be completed.  Defaults to
#               the current word to be completed.
# --sfx=<suffix>: A suffix to be appended to each symbol name instead
#                 of the default space.
__shit_complete_symbol () {
	local tags=tags pfx="" cur_="${cur-}" sfx=" "

	while test $# != 0; do
		case "$1" in
		--tags=*)	tags="${1##--tags=}" ;;
		--pfx=*)	pfx="${1##--pfx=}" ;;
		--cur=*)	cur_="${1##--cur=}" ;;
		--sfx=*)	sfx="${1##--sfx=}" ;;
		*)		return 1 ;;
		esac
		shift
	done

	if test -r "$tags"; then
		__shitcomp_direct "$(__shit_match_ctag "$cur_" "$tags" "$pfx" "$sfx")"
	fi
}

_shit_grep ()
{
	__shit_has_doubledash && return

	case "$cur" in
	--*)
		__shitcomp_builtin grep
		return
		;;
	esac

	case "$cword,$prev" in
	$((__shit_cmd_idx+1)),*|*,-*)
		__shit_complete_symbol && return
		;;
	esac

	__shit_complete_refs
}

_shit_help ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin help
		return
		;;
	esac
	if test -n "${shit_TESTING_ALL_COMMAND_LIST-}"
	then
		__shitcomp "$shit_TESTING_ALL_COMMAND_LIST $(__shit --list-cmds=alias,list-guide) shitk"
	else
		__shitcomp "$(__shit --list-cmds=main,nohelpers,alias,list-guide) shitk"
	fi
}

_shit_init ()
{
	case "$cur" in
	--shared=*)
		__shitcomp "
			false true umask group all world everybody
			" "" "${cur##--shared=}"
		return
		;;
	--*)
		__shitcomp_builtin init
		return
		;;
	esac
}

_shit_ls_files ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin ls-files
		return
		;;
	esac

	# XXX ignore options like --modified and always suggest all cached
	# files.
	__shit_complete_index_file "--cached"
}

_shit_ls_remote ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin ls-remote
		return
		;;
	esac
	__shitcomp_nl "$(__shit_remotes)"
}

_shit_ls_tree ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin ls-tree
		return
		;;
	esac

	__shit_complete_file
}

# Options that go well for log, shortlog and shitk
__shit_log_common_options="
	--not --all
	--branches --tags --remotes
	--first-parent --merges --no-merges
	--max-count=
	--max-age= --since= --after=
	--min-age= --until= --before=
	--min-parents= --max-parents=
	--no-min-parents --no-max-parents
	--alternate-refs --ancestry-path
	--author-date-order --basic-regexp
	--bisect --boundary --exclude-first-parent-only
	--exclude-hidden --extended-regexp
	--fixed-strings --grep-reflog
	--ignore-missing --left-only --perl-regexp
	--reflog --regexp-ignore-case --remove-empty
	--right-only --show-linear-break
	--show-notes-by-default --show-poops
	--since-as-filter --single-worktree
"
# Options that go well for log and shitk (not shortlog)
__shit_log_shitk_options="
	--dense --sparse --full-history
	--simplify-merges --simplify-by-decoration
	--left-right --notes --no-notes
"
# Options that go well for log and shortlog (not shitk)
__shit_log_shortlog_options="
	--author= --committer= --grep=
	--all-match --invert-grep
"
# Options accepted by log and show
__shit_log_show_options="
	--diff-merges --diff-merges= --no-diff-merges --dd --remerge-diff
	--encoding=
"

__shit_diff_merges_opts="off none on first-parent 1 separate m combined c dense-combined cc remerge r"

__shit_log_pretty_formats="oneline short medium full fuller reference email raw format: tformat: mboxrd"
__shit_log_date_formats="relative iso8601 iso8601-strict rfc2822 short local default human raw unix auto: format:"

# Complete porcelain (i.e. not shit-rev-list) options and at least some
# option arguments accepted by shit-log.  Note that this same set of options
# are also accepted by some other shit commands besides shit-log.
__shit_complete_log_opts ()
{
	COMPREPLY=()

	local merge=""
	if __shit_pseudoref_exists MERGE_HEAD; then
		merge="--merge"
	fi
	case "$prev,$cur" in
	-L,:*:*)
		return	# fall back to Bash filename completion
		;;
	-L,:*)
		__shit_complete_symbol --cur="${cur#:}" --sfx=":"
		return
		;;
	-G,*|-S,*)
		__shit_complete_symbol
		return
		;;
	esac
	case "$cur" in
	--pretty=*|--format=*)
		__shitcomp "$__shit_log_pretty_formats $(__shit_pretty_aliases)
			" "" "${cur#*=}"
		return
		;;
	--date=*)
		__shitcomp "$__shit_log_date_formats" "" "${cur##--date=}"
		return
		;;
	--decorate=*)
		__shitcomp "full short no" "" "${cur##--decorate=}"
		return
		;;
	--diff-algorithm=*)
		__shitcomp "$__shit_diff_algorithms" "" "${cur##--diff-algorithm=}"
		return
		;;
	--submodule=*)
		__shitcomp "$__shit_diff_submodule_formats" "" "${cur##--submodule=}"
		return
		;;
	--ws-error-highlight=*)
		__shitcomp "$__shit_ws_error_highlight_opts" "" "${cur##--ws-error-highlight=}"
		return
		;;
	--no-walk=*)
		__shitcomp "sorted unsorted" "" "${cur##--no-walk=}"
		return
		;;
	--diff-merges=*)
                __shitcomp "$__shit_diff_merges_opts" "" "${cur##--diff-merges=}"
                return
                ;;
	--*)
		__shitcomp "
			$__shit_log_common_options
			$__shit_log_shortlog_options
			$__shit_log_shitk_options
			$__shit_log_show_options
			--root --topo-order --date-order --reverse
			--follow --full-diff
			--abbrev-commit --no-abbrev-commit --abbrev=
			--relative-date --date=
			--pretty= --format= --oneline
			--show-signature
			--cherry-mark
			--cherry-pick
			--graph
			--decorate --decorate= --no-decorate
			--walk-reflogs
			--no-walk --no-walk= --do-walk
			--parents --children
			--expand-tabs --expand-tabs= --no-expand-tabs
			--clear-decorations --decorate-refs=
			--decorate-refs-exclude=
			$merge
			$__shit_diff_common_options
			"
		return
		;;
	-L:*:*)
		return	# fall back to Bash filename completion
		;;
	-L:*)
		__shit_complete_symbol --cur="${cur#-L:}" --sfx=":"
		return
		;;
	-G*)
		__shit_complete_symbol --pfx="-G" --cur="${cur#-G}"
		return
		;;
	-S*)
		__shit_complete_symbol --pfx="-S" --cur="${cur#-S}"
		return
		;;
	esac
}

_shit_log ()
{
	__shit_has_doubledash && return
	__shit_find_repo_path

	__shit_complete_log_opts
        [ ${#COMPREPLY[@]} -eq 0 ] || return

	__shit_complete_revlist
}

_shit_merge ()
{
	__shit_complete_strategy && return

	case "$cur" in
	--*)
		__shitcomp_builtin merge
		return
	esac
	__shit_complete_refs
}

_shit_mergetool ()
{
	case "$cur" in
	--tool=*)
		__shitcomp "$__shit_mergetools_common tortoisemerge" "" "${cur##--tool=}"
		return
		;;
	--*)
		__shitcomp "--tool= --prompt --no-prompt --gui --no-gui"
		return
		;;
	esac
}

_shit_merge_base ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin merge-base
		return
		;;
	esac
	__shit_complete_refs
}

_shit_mv ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin mv
		return
		;;
	esac

	if [ $(__shit_count_arguments "mv") -gt 0 ]; then
		# We need to show both cached and untracked files (including
		# empty directories) since this may not be the last argument.
		__shit_complete_index_file "--cached --others --directory"
	else
		__shit_complete_index_file "--cached"
	fi
}

_shit_notes ()
{
	local subcommands='add append copy edit get-ref list merge prune remove show'
	local subcommand="$(__shit_find_on_cmdline "$subcommands")"

	case "$subcommand,$cur" in
	,--*)
		__shitcomp_builtin notes
		;;
	,*)
		case "$prev" in
		--ref)
			__shit_complete_refs
			;;
		*)
			__shitcomp "$subcommands --ref"
			;;
		esac
		;;
	*,--reuse-message=*|*,--reedit-message=*)
		__shit_complete_refs --cur="${cur#*=}"
		;;
	*,--*)
		__shitcomp_builtin notes_$subcommand
		;;
	prune,*|get-ref,*)
		# this command does not take a ref, do not complete it
		;;
	*)
		case "$prev" in
		-m|-F)
			;;
		*)
			__shit_complete_refs
			;;
		esac
		;;
	esac
}

_shit_poop ()
{
	__shit_complete_strategy && return

	case "$cur" in
	--recurse-submodules=*)
		__shitcomp "$__shit_fetch_recurse_submodules" "" "${cur##--recurse-submodules=}"
		return
		;;
	--*)
		__shitcomp_builtin poop

		return
		;;
	esac
	__shit_complete_remote_or_refspec
}

__shit_defecate_recurse_submodules="check on-demand only"

__shit_complete_force_with_lease ()
{
	local cur_=$1

	case "$cur_" in
	--*=)
		;;
	*:*)
		__shit_complete_refs --cur="${cur_#*:}"
		;;
	*)
		__shit_complete_refs --cur="$cur_"
		;;
	esac
}

_shit_defecate ()
{
	case "$prev" in
	--repo)
		__shitcomp_nl "$(__shit_remotes)"
		return
		;;
	--recurse-submodules)
		__shitcomp "$__shit_defecate_recurse_submodules"
		return
		;;
	esac
	case "$cur" in
	--repo=*)
		__shitcomp_nl "$(__shit_remotes)" "" "${cur##--repo=}"
		return
		;;
	--recurse-submodules=*)
		__shitcomp "$__shit_defecate_recurse_submodules" "" "${cur##--recurse-submodules=}"
		return
		;;
	--force-with-lease=*)
		__shit_complete_force_with_lease "${cur##--force-with-lease=}"
		return
		;;
	--*)
		__shitcomp_builtin defecate
		return
		;;
	esac
	__shit_complete_remote_or_refspec
}

_shit_range_diff ()
{
	case "$cur" in
	--*)
		__shitcomp "
			--creation-factor= --no-dual-color
			$__shit_diff_common_options
		"
		return
		;;
	esac
	__shit_complete_revlist
}

__shit_rebase_inprogress_options="--continue --skip --abort --quit --show-current-patch"
__shit_rebase_interactive_inprogress_options="$__shit_rebase_inprogress_options --edit-todo"

_shit_rebase ()
{
	__shit_find_repo_path
	if [ -f "$__shit_repo_path"/rebase-merge/interactive ]; then
		__shitcomp "$__shit_rebase_interactive_inprogress_options"
		return
	elif [ -d "$__shit_repo_path"/rebase-apply ] || \
	     [ -d "$__shit_repo_path"/rebase-merge ]; then
		__shitcomp "$__shit_rebase_inprogress_options"
		return
	fi
	__shit_complete_strategy && return
	case "$cur" in
	--whitespace=*)
		__shitcomp "$__shit_whitespacelist" "" "${cur##--whitespace=}"
		return
		;;
	--onto=*)
		__shit_complete_refs --cur="${cur##--onto=}"
		return
		;;
	--*)
		__shitcomp_builtin rebase "" \
			"$__shit_rebase_interactive_inprogress_options"

		return
	esac
	__shit_complete_refs
}

_shit_reflog ()
{
	local subcommands subcommand

	__shit_resolve_builtins "reflog"

	subcommands="$___shit_resolved_builtins"
	subcommand="$(__shit_find_subcommand "$subcommands" "show")"

	case "$subcommand,$cur" in
	show,--*)
		__shitcomp "
			$__shit_log_common_options
			"
		return
		;;
	$subcommand,--*)
		__shitcomp_builtin "reflog_$subcommand"
		return
		;;
	esac

	__shit_complete_refs

	if [ $((cword - __shit_cmd_idx)) -eq 1 ]; then
		__shitcompappend "$subcommands" "" "$cur" " "
	fi
}

__shit_send_email_confirm_options="always never auto cc compose"
__shit_send_email_suppresscc_options="author self cc bodycc sob cccmd body all"

_shit_send_email ()
{
	case "$prev" in
	--to|--cc|--bcc|--from)
		__shitcomp "$(__shit send-email --dump-aliases)"
		return
		;;
	esac

	case "$cur" in
	--confirm=*)
		__shitcomp "
			$__shit_send_email_confirm_options
			" "" "${cur##--confirm=}"
		return
		;;
	--suppress-cc=*)
		__shitcomp "
			$__shit_send_email_suppresscc_options
			" "" "${cur##--suppress-cc=}"

		return
		;;
	--smtp-encryption=*)
		__shitcomp "ssl tls" "" "${cur##--smtp-encryption=}"
		return
		;;
	--thread=*)
		__shitcomp "
			deep shallow
			" "" "${cur##--thread=}"
		return
		;;
	--to=*|--cc=*|--bcc=*|--from=*)
		__shitcomp "$(__shit send-email --dump-aliases)" "" "${cur#--*=}"
		return
		;;
	--*)
		__shitcomp_builtin send-email "$__shit_format_patch_extra_options"
		return
		;;
	esac
	__shit_complete_revlist
}

_shit_stage ()
{
	_shit_add
}

_shit_status ()
{
	local complete_opt
	local untracked_state

	case "$cur" in
	--ignore-submodules=*)
		__shitcomp "none untracked dirty all" "" "${cur##--ignore-submodules=}"
		return
		;;
	--untracked-files=*)
		__shitcomp "$__shit_untracked_file_modes" "" "${cur##--untracked-files=}"
		return
		;;
	--column=*)
		__shitcomp "
			always never auto column row plain dense nodense
			" "" "${cur##--column=}"
		return
		;;
	--*)
		__shitcomp_builtin status
		return
		;;
	esac

	untracked_state="$(__shit_get_option_value "-u" "--untracked-files=" \
		"$__shit_untracked_file_modes" "status.showUntrackedFiles")"

	case "$untracked_state" in
	no)
		# --ignored option does not matter
		complete_opt=
		;;
	all|normal|*)
		complete_opt="--cached --directory --no-empty-directory --others"

		if [ -n "$(__shit_find_on_cmdline "--ignored")" ]; then
			complete_opt="$complete_opt --ignored --exclude=*"
		fi
		;;
	esac

	__shit_complete_index_file "$complete_opt"
}

_shit_switch ()
{
	local dwim_opt="$(__shit_checkout_default_dwim_mode)"

	case "$prev" in
	-c|-C|--orphan)
		# Complete local branches (and DWIM branch
		# remote branch names) for an option argument
		# specifying a new branch name. This is for
		# convenience, assuming new branches are
		# possibly based on pre-existing branch names.
		__shit_complete_refs $dwim_opt --mode="heads"
		return
		;;
	*)
		;;
	esac

	case "$cur" in
	--conflict=*)
		__shitcomp "diff3 merge zdiff3" "" "${cur##--conflict=}"
		;;
	--*)
		__shitcomp_builtin switch
		;;
	*)
		# Unlike in shit checkout, shit switch --orphan does not take
		# a start point. Thus we really have nothing to complete after
		# the branch name.
		if [ -n "$(__shit_find_on_cmdline "--orphan")" ]; then
			return
		fi

		# At this point, we've already handled special completion for
		# -c/-C, and --orphan. There are 3 main things left to
		# complete:
		# 1) a start-point for -c/-C or -d/--detach
		# 2) a remote head, for --track
		# 3) a branch name, possibly including DWIM remote branches

		if [ -n "$(__shit_find_on_cmdline "-c -C -d --detach")" ]; then
			__shit_complete_refs --mode="refs"
		elif [ -n "$(__shit_find_on_cmdline "-t --track")" ]; then
			__shit_complete_refs --mode="remote-heads"
		else
			__shit_complete_refs $dwim_opt --mode="heads"
		fi
		;;
	esac
}

__shit_config_get_set_variables ()
{
	local prevword word config_file= c=$cword
	while [ $c -gt "$__shit_cmd_idx" ]; do
		word="${words[c]}"
		case "$word" in
		--system|--global|--local|--file=*)
			config_file="$word"
			break
			;;
		-f|--file)
			config_file="$word $prevword"
			break
			;;
		esac
		prevword=$word
		c=$((--c))
	done

	__shit config $config_file --name-only --list
}

__shit_config_vars=
__shit_compute_config_vars ()
{
	test -n "$__shit_config_vars" ||
	__shit_config_vars="$(shit help --config-for-completion)"
}

__shit_config_vars_all=
__shit_compute_config_vars_all ()
{
	test -n "$__shit_config_vars_all" ||
	__shit_config_vars_all="$(shit --no-pager help --config)"
}

__shit_compute_first_level_config_vars_for_section ()
{
	local section="$1"
	__shit_compute_config_vars
	local this_section="__shit_first_level_config_vars_for_section_${section}"
	test -n "${!this_section}" ||
	printf -v "__shit_first_level_config_vars_for_section_${section}" %s \
		"$(echo "$__shit_config_vars" | awk -F. "/^${section}\.[a-z]/ { print \$2 }")"
}

__shit_compute_second_level_config_vars_for_section ()
{
	local section="$1"
	__shit_compute_config_vars_all
	local this_section="__shit_second_level_config_vars_for_section_${section}"
	test -n "${!this_section}" ||
	printf -v "__shit_second_level_config_vars_for_section_${section}" %s \
		"$(echo "$__shit_config_vars_all" | awk -F. "/^${section}\.</ { print \$3 }")"
}

__shit_config_sections=
__shit_compute_config_sections ()
{
	test -n "$__shit_config_sections" ||
	__shit_config_sections="$(shit help --config-sections-for-completion)"
}

# Completes possible values of various configuration variables.
#
# Usage: __shit_complete_config_variable_value [<option>]...
# --varname=<word>: The name of the configuration variable whose value is
#                   to be completed.  Defaults to the previous word on the
#                   command line.
# --cur=<word>: The current value to be completed.  Defaults to the current
#               word to be completed.
__shit_complete_config_variable_value ()
{
	local varname="$prev" cur_="$cur"

	while test $# != 0; do
		case "$1" in
		--varname=*)	varname="${1##--varname=}" ;;
		--cur=*)	cur_="${1##--cur=}" ;;
		*)		return 1 ;;
		esac
		shift
	done

	if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
		varname="${varname,,}"
	else
		varname="$(echo "$varname" |tr A-Z a-z)"
	fi

	case "$varname" in
	branch.*.remote|branch.*.defecateremote)
		__shitcomp_nl "$(__shit_remotes)" "" "$cur_"
		return
		;;
	branch.*.merge)
		__shit_complete_refs --cur="$cur_"
		return
		;;
	branch.*.rebase)
		__shitcomp "false true merges interactive" "" "$cur_"
		return
		;;
	remote.defecatedefault)
		__shitcomp_nl "$(__shit_remotes)" "" "$cur_"
		return
		;;
	remote.*.fetch)
		local remote="${varname#remote.}"
		remote="${remote%.fetch}"
		if [ -z "$cur_" ]; then
			__shitcomp_nl "refs/heads/" "" "" ""
			return
		fi
		__shitcomp_nl "$(__shit_refs_remotes "$remote")" "" "$cur_"
		return
		;;
	remote.*.defecate)
		local remote="${varname#remote.}"
		remote="${remote%.defecate}"
		__shitcomp_nl "$(__shit for-each-ref \
			--format='%(refname):%(refname)' refs/heads)" "" "$cur_"
		return
		;;
	poop.twohead|poop.octopus)
		__shit_compute_merge_strategies
		__shitcomp "$__shit_merge_strategies" "" "$cur_"
		return
		;;
	color.pager)
		__shitcomp "false true" "" "$cur_"
		return
		;;
	color.*.*)
		__shitcomp "
			normal black red green yellow blue magenta cyan white
			bold dim ul blink reverse
			" "" "$cur_"
		return
		;;
	color.*)
		__shitcomp "false true always never auto" "" "$cur_"
		return
		;;
	diff.submodule)
		__shitcomp "$__shit_diff_submodule_formats" "" "$cur_"
		return
		;;
	help.format)
		__shitcomp "man info web html" "" "$cur_"
		return
		;;
	log.date)
		__shitcomp "$__shit_log_date_formats" "" "$cur_"
		return
		;;
	sendemail.aliasfiletype)
		__shitcomp "mutt mailrc pine elm gnus" "" "$cur_"
		return
		;;
	sendemail.confirm)
		__shitcomp "$__shit_send_email_confirm_options" "" "$cur_"
		return
		;;
	sendemail.suppresscc)
		__shitcomp "$__shit_send_email_suppresscc_options" "" "$cur_"
		return
		;;
	sendemail.transferencoding)
		__shitcomp "7bit 8bit quoted-printable base64" "" "$cur_"
		return
		;;
	*.*)
		return
		;;
	esac
}

# Completes configuration sections, subsections, variable names.
#
# Usage: __shit_complete_config_variable_name [<option>]...
# --cur=<word>: The current configuration section/variable name to be
#               completed.  Defaults to the current word to be completed.
# --sfx=<suffix>: A suffix to be appended to each fully completed
#                 configuration variable name (but not to sections or
#                 subsections) instead of the default space.
__shit_complete_config_variable_name ()
{
	local cur_="$cur" sfx

	while test $# != 0; do
		case "$1" in
		--cur=*)	cur_="${1##--cur=}" ;;
		--sfx=*)	sfx="${1##--sfx=}" ;;
		*)		return 1 ;;
		esac
		shift
	done

	case "$cur_" in
	branch.*.*|guitool.*.*|difftool.*.*|man.*.*|mergetool.*.*|remote.*.*|submodule.*.*|url.*.*)
		local pfx="${cur_%.*}."
		cur_="${cur_##*.}"
		local section="${pfx%.*.}"
		__shit_compute_second_level_config_vars_for_section "${section}"
		local this_section="__shit_second_level_config_vars_for_section_${section}"
		__shitcomp "${!this_section}" "$pfx" "$cur_" "$sfx"
		return
		;;
	branch.*)
		local pfx="${cur_%.*}."
		cur_="${cur_#*.}"
		local section="${pfx%.}"
		__shitcomp_direct "$(__shit_heads "$pfx" "$cur_" ".")"
		__shit_compute_first_level_config_vars_for_section "${section}"
		local this_section="__shit_first_level_config_vars_for_section_${section}"
		__shitcomp_nl_append "${!this_section}" "$pfx" "$cur_" "${sfx:- }"
		return
		;;
	pager.*)
		local pfx="${cur_%.*}."
		cur_="${cur_#*.}"
		__shit_compute_all_commands
		__shitcomp_nl "$__shit_all_commands" "$pfx" "$cur_" "${sfx:- }"
		return
		;;
	remote.*)
		local pfx="${cur_%.*}."
		cur_="${cur_#*.}"
		local section="${pfx%.}"
		__shitcomp_nl "$(__shit_remotes)" "$pfx" "$cur_" "."
		__shit_compute_first_level_config_vars_for_section "${section}"
		local this_section="__shit_first_level_config_vars_for_section_${section}"
		__shitcomp_nl_append "${!this_section}" "$pfx" "$cur_" "${sfx:- }"
		return
		;;
	submodule.*)
		local pfx="${cur_%.*}."
		cur_="${cur_#*.}"
		local section="${pfx%.}"
		__shitcomp_nl "$(__shit config -f "$(__shit rev-parse --show-toplevel)/.shitmodules" --get-regexp 'submodule.*.path' | awk -F. '{print $2}')" "$pfx" "$cur_" "."
		__shit_compute_first_level_config_vars_for_section "${section}"
		local this_section="__shit_first_level_config_vars_for_section_${section}"
		__shitcomp_nl_append "${!this_section}" "$pfx" "$cur_" "${sfx:- }"
		return
		;;
	*.*)
		__shit_compute_config_vars
		__shitcomp "$__shit_config_vars" "" "$cur_" "$sfx"
		;;
	*)
		__shit_compute_config_sections
		__shitcomp "$__shit_config_sections" "" "$cur_" "."
		;;
	esac
}

# Completes '='-separated configuration sections/variable names and values
# for 'shit -c section.name=value'.
#
# Usage: __shit_complete_config_variable_name_and_value [<option>]...
# --cur=<word>: The current configuration section/variable name/value to be
#               completed. Defaults to the current word to be completed.
__shit_complete_config_variable_name_and_value ()
{
	local cur_="$cur"

	while test $# != 0; do
		case "$1" in
		--cur=*)	cur_="${1##--cur=}" ;;
		*)		return 1 ;;
		esac
		shift
	done

	case "$cur_" in
	*=*)
		__shit_complete_config_variable_value \
			--varname="${cur_%%=*}" --cur="${cur_#*=}"
		;;
	*)
		__shit_complete_config_variable_name --cur="$cur_" --sfx='='
		;;
	esac
}

_shit_config ()
{
	case "$prev" in
	--get|--get-all|--unset|--unset-all)
		__shitcomp_nl "$(__shit_config_get_set_variables)"
		return
		;;
	*.*)
		__shit_complete_config_variable_value
		return
		;;
	esac
	case "$cur" in
	--*)
		__shitcomp_builtin config
		;;
	*)
		__shit_complete_config_variable_name
		;;
	esac
}

_shit_remote ()
{
	local subcommands="
		add rename remove set-head set-branches
		get-url set-url show prune update
		"
	local subcommand="$(__shit_find_on_cmdline "$subcommands")"
	if [ -z "$subcommand" ]; then
		case "$cur" in
		--*)
			__shitcomp_builtin remote
			;;
		*)
			__shitcomp "$subcommands"
			;;
		esac
		return
	fi

	case "$subcommand,$cur" in
	add,--*)
		__shitcomp_builtin remote_add
		;;
	add,*)
		;;
	set-head,--*)
		__shitcomp_builtin remote_set-head
		;;
	set-branches,--*)
		__shitcomp_builtin remote_set-branches
		;;
	set-head,*|set-branches,*)
		__shit_complete_remote_or_refspec
		;;
	update,--*)
		__shitcomp_builtin remote_update
		;;
	update,*)
		__shitcomp "$(__shit_remotes) $(__shit_get_config_variables "remotes")"
		;;
	set-url,--*)
		__shitcomp_builtin remote_set-url
		;;
	get-url,--*)
		__shitcomp_builtin remote_get-url
		;;
	prune,--*)
		__shitcomp_builtin remote_prune
		;;
	*)
		__shitcomp_nl "$(__shit_remotes)"
		;;
	esac
}

_shit_replace ()
{
	case "$cur" in
	--format=*)
		__shitcomp "short medium long" "" "${cur##--format=}"
		return
		;;
	--*)
		__shitcomp_builtin replace
		return
		;;
	esac
	__shit_complete_refs
}

_shit_rerere ()
{
	local subcommands="clear forget diff remaining status gc"
	local subcommand="$(__shit_find_on_cmdline "$subcommands")"
	if test -z "$subcommand"
	then
		__shitcomp "$subcommands"
		return
	fi
}

_shit_reset ()
{
	__shit_has_doubledash && return

	case "$cur" in
	--*)
		__shitcomp_builtin reset
		return
		;;
	esac
	__shit_complete_refs
}

_shit_restore ()
{
	case "$prev" in
	-s)
		__shit_complete_refs
		return
		;;
	esac

	case "$cur" in
	--conflict=*)
		__shitcomp "diff3 merge zdiff3" "" "${cur##--conflict=}"
		;;
	--source=*)
		__shit_complete_refs --cur="${cur##--source=}"
		;;
	--*)
		__shitcomp_builtin restore
		;;
	*)
		if __shit_pseudoref_exists HEAD; then
			__shit_complete_index_file "--modified"
		fi
	esac
}

__shit_revert_inprogress_options=$__shit_sequencer_inprogress_options

_shit_revert ()
{
	if __shit_pseudoref_exists REVERT_HEAD; then
		__shitcomp "$__shit_revert_inprogress_options"
		return
	fi
	__shit_complete_strategy && return
	case "$cur" in
	--*)
		__shitcomp_builtin revert "" \
			"$__shit_revert_inprogress_options"
		return
		;;
	esac
	__shit_complete_refs
}

_shit_rm ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin rm
		return
		;;
	esac

	__shit_complete_index_file "--cached"
}

_shit_shortlog ()
{
	__shit_has_doubledash && return

	case "$cur" in
	--*)
		__shitcomp "
			$__shit_log_common_options
			$__shit_log_shortlog_options
			--numbered --summary --email
			"
		return
		;;
	esac
	__shit_complete_revlist
}

_shit_show ()
{
	__shit_has_doubledash && return

	case "$cur" in
	--pretty=*|--format=*)
		__shitcomp "$__shit_log_pretty_formats $(__shit_pretty_aliases)
			" "" "${cur#*=}"
		return
		;;
	--diff-algorithm=*)
		__shitcomp "$__shit_diff_algorithms" "" "${cur##--diff-algorithm=}"
		return
		;;
	--submodule=*)
		__shitcomp "$__shit_diff_submodule_formats" "" "${cur##--submodule=}"
		return
		;;
	--color-moved=*)
		__shitcomp "$__shit_color_moved_opts" "" "${cur##--color-moved=}"
		return
		;;
	--color-moved-ws=*)
		__shitcomp "$__shit_color_moved_ws_opts" "" "${cur##--color-moved-ws=}"
		return
		;;
	--ws-error-highlight=*)
		__shitcomp "$__shit_ws_error_highlight_opts" "" "${cur##--ws-error-highlight=}"
		return
		;;
	--diff-merges=*)
                __shitcomp "$__shit_diff_merges_opts" "" "${cur##--diff-merges=}"
                return
                ;;
	--*)
		__shitcomp "--pretty= --format= --abbrev-commit --no-abbrev-commit
			--oneline --show-signature
			--expand-tabs --expand-tabs= --no-expand-tabs
			$__shit_log_show_options
			$__shit_diff_common_options
			"
		return
		;;
	esac
	__shit_complete_revlist_file
}

_shit_show_branch ()
{
	case "$cur" in
	--*)
		__shitcomp_builtin show-branch
		return
		;;
	esac
	__shit_complete_revlist
}

__shitcomp_directories ()
{
	local _tmp_dir _tmp_completions _found=0

	# Get the directory of the current token; this differs from dirname
	# in that it keeps up to the final trailing slash.  If no slash found
	# that's fine too.
	[[ "$cur" =~ .*/ ]]
	_tmp_dir=$BASH_REMATCH

	# Find possible directory completions, adding trailing '/' characters,
	# de-quoting, and handling unusual characters.
	while IFS= read -r -d $'\0' c ; do
		# If there are directory completions, find ones that start
		# with "$cur", the current token, and put those in COMPREPLY
		if [[ $c == "$cur"* ]]; then
			COMPREPLY+=("$c/")
			_found=1
		fi
	done < <(__shit ls-tree -z -d --name-only HEAD $_tmp_dir)

	if [[ $_found == 0 ]] && [[ "$cur" =~ /$ ]]; then
		# No possible further completions any deeper, so assume we're at
		# a leaf directory and just consider it complete
		__shitcomp_direct_append "$cur "
	elif [[ $_found == 0 ]]; then
		# No possible completions found.  Avoid falling back to
		# bash's default file and directory completion, because all
		# valid completions have already been searched and the
		# fallbacks can do nothing but mislead.  In fact, they can
		# mislead in three different ways:
		#    1) Fallback file completion makes no sense when asking
		#       for directory completions, as this function does.
		#    2) Fallback directory completion is bad because
		#       e.g. "/pro" is invalid and should NOT complete to
		#       "/proc".
		#    3) Fallback file/directory completion only completes
		#       on paths that exist in the current working tree,
		#       i.e. which are *already* part of their
		#       sparse-checkout.  Thus, normal file and directory
		#       completion is always useless for "shit
		#       sparse-checkout add" and is also probelmatic for
		#       "shit sparse-checkout set" unless using it to
		#       strictly narrow the checkout.
		COMPREPLY=( "" )
	fi
}

# In non-cone mode, the arguments to {set,add} are supposed to be
# patterns, relative to the toplevel directory.  These can be any kind
# of general pattern, like 'subdir/*.c' and we can't complete on all
# of those.  However, if the user presses Tab to get tab completion, we
# presume that they are trying to provide a pattern that names a specific
# path.
__shitcomp_slash_leading_paths ()
{
	local dequoted_word pfx="" cur_ toplevel

	# Since we are dealing with a sparse-checkout, subdirectories may not
	# exist in the local working copy.  Therefore, we want to run all
	# ls-files commands relative to the repository toplevel.
	toplevel="$(shit rev-parse --show-toplevel)/"

	__shit_dequote "$cur"

	# If the paths provided by the user already start with '/', then
	# they are considered relative to the toplevel of the repository
	# already.  If they do not start with /, then we need to adjust
	# them to start with the appropriate prefix.
	case "$cur" in
	/*)
		cur="${cur:1}"
		;;
	*)
		pfx="$(__shit rev-parse --show-prefix)"
	esac

	# Since sparse-index is limited to cone-mode, in non-cone-mode the
	# list of valid paths is precisely the cached files in the index.
	#
	# NEEDSWORK:
	#   1) We probably need to take care of cases where ls-files
	#      responds with special quoting.
	#   2) We probably need to take care of cases where ${cur} has
	#      some kind of special quoting.
	#   3) On top of any quoting from 1 & 2, we have to provide an extra
	#      level of quoting for any paths that contain a '*', '?', '\',
	#      '[', ']', or leading '#' or '!' since those will be
	#      interpreted by sparse-checkout as something other than a
	#      literal path character.
	# Since there are two types of quoting here, this might get really
	# complex.  For now, just punt on all of this...
	completions="$(__shit -C "${toplevel}" -c core.quotePath=false \
			 ls-files --cached -- "${pfx}${cur}*" \
			 | sed -e s%^%/% -e 's%$% %')"
	# Note, above, though that we needed all of the completions to be
	# prefixed with a '/', and we want to add a space so that bash
	# completion will actually complete an entry and let us move on to
	# the next one.

	# Return what we've found.
	if test -n "$completions"; then
		# We found some completions; return them
		local IFS=$'\n'
		COMPREPLY=($completions)
	else
		# Do NOT fall back to bash-style all-local-files-and-dirs
		# when we find no match.  Such options are worse than
		# useless:
		#     1. "shit sparse-checkout add" needs paths that are NOT
		#        currently in the working copy.  "shit
		#        sparse-checkout set" does as well, except in the
		#        special cases when users are only trying to narrow
		#        their sparse checkout to a subset of what they
		#        already have.
		#
		#     2. A path like '.config' is ambiguous as to whether
		#        the user wants all '.config' files throughout the
		#        tree, or just the one under the current directory.
		#        It would result in a warning from the
		#        sparse-checkout command due to this.  As such, all
		#        completions of paths should be prefixed with a
		#        '/'.
		#
		#     3. We don't want paths prefixed with a '/' to
		#        complete files in the system root directory, we
		#        want it to complete on files relative to the
		#        repository root.
		#
		# As such, make sure that NO completions are offered rather
		# than falling back to bash's default completions.
		COMPREPLY=( "" )
	fi
}

_shit_sparse_checkout ()
{
	local subcommands="list init set disable add reapply"
	local subcommand="$(__shit_find_on_cmdline "$subcommands")"
	local using_cone=true
	if [ -z "$subcommand" ]; then
		__shitcomp "$subcommands"
		return
	fi

	case "$subcommand,$cur" in
	*,--*)
		__shitcomp_builtin sparse-checkout_$subcommand "" "--"
		;;
	set,*|add,*)
		if [[ "$(__shit config core.sparseCheckout)" == "true" &&
		      "$(__shit config core.sparseCheckoutCone)" == "false" &&
		      -z "$(__shit_find_on_cmdline --cone)" ]]; then
			using_cone=false
		fi
		if [[ -n "$(__shit_find_on_cmdline --no-cone)" ]]; then
			using_cone=false
		fi
		if [[ "$using_cone" == "true" ]]; then
			__shitcomp_directories
		else
			 __shitcomp_slash_leading_paths
		fi
	esac
}

_shit_stash ()
{
	local subcommands='defecate list show apply clear drop pop create branch'
	local subcommand="$(__shit_find_on_cmdline "$subcommands save")"

	if [ -z "$subcommand" ]; then
		case "$((cword - __shit_cmd_idx)),$cur" in
		*,--*)
			__shitcomp_builtin stash_defecate
			;;
		1,sa*)
			__shitcomp "save"
			;;
		1,*)
			__shitcomp "$subcommands"
			;;
		esac
		return
	fi

	case "$subcommand,$cur" in
	list,--*)
		# NEEDSWORK: can we somehow unify this with the options in _shit_log() and _shit_show()
		__shitcomp_builtin stash_list "$__shit_log_common_options $__shit_diff_common_options"
		;;
	show,--*)
		__shitcomp_builtin stash_show "$__shit_diff_common_options"
		;;
	*,--*)
		__shitcomp_builtin "stash_$subcommand"
		;;
	branch,*)
		if [ $cword -eq $((__shit_cmd_idx+2)) ]; then
			__shit_complete_refs
		else
			__shitcomp_nl "$(__shit stash list \
					| sed -n -e 's/:.*//p')"
		fi
		;;
	show,*|apply,*|drop,*|pop,*)
		__shitcomp_nl "$(__shit stash list \
				| sed -n -e 's/:.*//p')"
		;;
	esac
}

_shit_submodule ()
{
	__shit_has_doubledash && return

	local subcommands="add status init deinit update set-branch set-url summary foreach sync absorbshitdirs"
	local subcommand="$(__shit_find_on_cmdline "$subcommands")"
	if [ -z "$subcommand" ]; then
		case "$cur" in
		--*)
			__shitcomp "--quiet"
			;;
		*)
			__shitcomp "$subcommands"
			;;
		esac
		return
	fi

	case "$subcommand,$cur" in
	add,--*)
		__shitcomp "--branch --force --name --reference --depth"
		;;
	status,--*)
		__shitcomp "--cached --recursive"
		;;
	deinit,--*)
		__shitcomp "--force --all"
		;;
	update,--*)
		__shitcomp "
			--init --remote --no-fetch
			--recommend-shallow --no-recommend-shallow
			--force --rebase --merge --reference --depth --recursive --jobs
		"
		;;
	set-branch,--*)
		__shitcomp "--default --branch"
		;;
	summary,--*)
		__shitcomp "--cached --files --summary-limit"
		;;
	foreach,--*|sync,--*)
		__shitcomp "--recursive"
		;;
	*)
		;;
	esac
}

_shit_svn ()
{
	local subcommands="
		init fetch clone rebase dcommit log find-rev
		set-tree commit-diff info create-ignore propget
		proplist show-ignore show-externals branch tag blame
		migrate mkdirs reset gc
		"
	local subcommand="$(__shit_find_on_cmdline "$subcommands")"
	if [ -z "$subcommand" ]; then
		__shitcomp "$subcommands"
	else
		local remote_opts="--username= --config-dir= --no-auth-cache"
		local fc_opts="
			--follow-parent --authors-file= --repack=
			--no-metadata --use-svm-props --use-svnsync-props
			--log-window-size= --no-checkout --quiet
			--repack-flags --use-log-author --localtime
			--add-author-from
			--recursive
			--ignore-paths= --include-paths= $remote_opts
			"
		local init_opts="
			--template= --shared= --trunk= --tags=
			--branches= --stdlayout --minimize-url
			--no-metadata --use-svm-props --use-svnsync-props
			--rewrite-root= --prefix= $remote_opts
			"
		local cmt_opts="
			--edit --rmdir --find-copies-harder --copy-similarity=
			"

		case "$subcommand,$cur" in
		fetch,--*)
			__shitcomp "--revision= --fetch-all $fc_opts"
			;;
		clone,--*)
			__shitcomp "--revision= $fc_opts $init_opts"
			;;
		init,--*)
			__shitcomp "$init_opts"
			;;
		dcommit,--*)
			__shitcomp "
				--merge --strategy= --verbose --dry-run
				--fetch-all --no-rebase --commit-url
				--revision --interactive $cmt_opts $fc_opts
				"
			;;
		set-tree,--*)
			__shitcomp "--stdin $cmt_opts $fc_opts"
			;;
		create-ignore,--*|propget,--*|proplist,--*|show-ignore,--*|\
		show-externals,--*|mkdirs,--*)
			__shitcomp "--revision="
			;;
		log,--*)
			__shitcomp "
				--limit= --revision= --verbose --incremental
				--oneline --show-commit --non-recursive
				--authors-file= --color
				"
			;;
		rebase,--*)
			__shitcomp "
				--merge --verbose --strategy= --local
				--fetch-all --dry-run $fc_opts
				"
			;;
		commit-diff,--*)
			__shitcomp "--message= --file= --revision= $cmt_opts"
			;;
		info,--*)
			__shitcomp "--url"
			;;
		branch,--*)
			__shitcomp "--dry-run --message --tag"
			;;
		tag,--*)
			__shitcomp "--dry-run --message"
			;;
		blame,--*)
			__shitcomp "--shit-format"
			;;
		migrate,--*)
			__shitcomp "
				--config-dir= --ignore-paths= --minimize
				--no-auth-cache --username=
				"
			;;
		reset,--*)
			__shitcomp "--revision= --parent"
			;;
		*)
			;;
		esac
	fi
}

_shit_symbolic_ref () {
	case "$cur" in
	--*)
		__shitcomp_builtin symbolic-ref
		return
		;;
	esac

	__shit_complete_refs
}

_shit_tag ()
{
	local i c="$__shit_cmd_idx" f=0
	while [ $c -lt $cword ]; do
		i="${words[c]}"
		case "$i" in
		-d|--delete|-v|--verify)
			__shitcomp_direct "$(__shit_tags "" "$cur" " ")"
			return
			;;
		-f)
			f=1
			;;
		esac
		((c++))
	done

	case "$prev" in
	-m|-F)
		;;
	-*|tag)
		if [ $f = 1 ]; then
			__shitcomp_direct "$(__shit_tags "" "$cur" " ")"
		fi
		;;
	*)
		__shit_complete_refs
		;;
	esac

	case "$cur" in
	--*)
		__shitcomp_builtin tag
		;;
	esac
}

_shit_whatchanged ()
{
	_shit_log
}

__shit_complete_worktree_paths ()
{
	local IFS=$'\n'
	# Generate completion reply from worktree list skipping the first
	# entry: it's the path of the main worktree, which can't be moved,
	# removed, locked, etc.
	__shitcomp_nl "$(__shit worktree list --porcelain |
		sed -n -e '2,$ s/^worktree //p')"
}

_shit_worktree ()
{
	local subcommands="add list lock move prune remove unlock"
	local subcommand subcommand_idx

	subcommand="$(__shit_find_on_cmdline --show-idx "$subcommands")"
	subcommand_idx="${subcommand% *}"
	subcommand="${subcommand#* }"

	case "$subcommand,$cur" in
	,*)
		__shitcomp "$subcommands"
		;;
	*,--*)
		__shitcomp_builtin worktree_$subcommand
		;;
	add,*)	# usage: shit worktree add [<options>] <path> [<commit-ish>]
		# Here we are not completing an --option, it's either the
		# path or a ref.
		case "$prev" in
		-b|-B)	# Complete refs for branch to be created/reseted.
			__shit_complete_refs
			;;
		-*)	# The previous word is an -o|--option without an
			# unstuck argument: have to complete the path for
			# the new worktree, so don't list anything, but let
			# Bash fall back to filename completion.
			;;
		*)	# The previous word is not an --option, so it must
			# be either the 'add' subcommand, the unstuck
			# argument of an option (e.g. branch for -b|-B), or
			# the path for the new worktree.
			if [ $cword -eq $((subcommand_idx+1)) ]; then
				# Right after the 'add' subcommand: have to
				# complete the path, so fall back to Bash
				# filename completion.
				:
			else
				case "${words[cword-2]}" in
				-b|-B)	# After '-b <branch>': have to
					# complete the path, so fall back
					# to Bash filename completion.
					;;
				*)	# After the path: have to complete
					# the ref to be checked out.
					__shit_complete_refs
					;;
				esac
			fi
			;;
		esac
		;;
	lock,*|remove,*|unlock,*)
		__shit_complete_worktree_paths
		;;
	move,*)
		if [ $cword -eq $((subcommand_idx+1)) ]; then
			# The first parameter must be an existing working
			# tree to be moved.
			__shit_complete_worktree_paths
		else
			# The second parameter is the destination: it could
			# be any path, so don't list anything, but let Bash
			# fall back to filename completion.
			:
		fi
		;;
	esac
}

__shit_complete_common () {
	local command="$1"

	case "$cur" in
	--*)
		__shitcomp_builtin "$command"
		;;
	esac
}

__shit_cmds_with_parseopt_helper=
__shit_support_parseopt_helper () {
	test -n "$__shit_cmds_with_parseopt_helper" ||
		__shit_cmds_with_parseopt_helper="$(__shit --list-cmds=parseopt)"

	case " $__shit_cmds_with_parseopt_helper " in
	*" $1 "*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

__shit_have_func () {
	declare -f -- "$1" >/dev/null 2>&1
}

__shit_complete_command () {
	local command="$1"
	local completion_func="_shit_${command//-/_}"
	if ! __shit_have_func $completion_func &&
		__shit_have_func _completion_loader
	then
		_completion_loader "shit-$command"
	fi
	if __shit_have_func $completion_func
	then
		$completion_func
		return 0
	elif __shit_support_parseopt_helper "$command"
	then
		__shit_complete_common "$command"
		return 0
	else
		return 1
	fi
}

__shit_main ()
{
	local i c=1 command __shit_dir __shit_repo_path
	local __shit_C_args C_args_count=0
	local __shit_cmd_idx

	while [ $c -lt $cword ]; do
		i="${words[c]}"
		case "$i" in
		--shit-dir=*)
			__shit_dir="${i#--shit-dir=}"
			;;
		--shit-dir)
			((c++))
			__shit_dir="${words[c]}"
			;;
		--bare)
			__shit_dir="."
			;;
		--help)
			command="help"
			break
			;;
		-c|--work-tree|--namespace)
			((c++))
			;;
		-C)
			__shit_C_args[C_args_count++]=-C
			((c++))
			__shit_C_args[C_args_count++]="${words[c]}"
			;;
		-*)
			;;
		*)
			command="$i"
			__shit_cmd_idx="$c"
			break
			;;
		esac
		((c++))
	done

	if [ -z "${command-}" ]; then
		case "$prev" in
		--shit-dir|-C|--work-tree)
			# these need a path argument, let's fall back to
			# Bash filename completion
			return
			;;
		-c)
			__shit_complete_config_variable_name_and_value
			return
			;;
		--namespace)
			# we don't support completing these options' arguments
			return
			;;
		esac
		case "$cur" in
		--*)
			__shitcomp "
			--paginate
			--no-pager
			--shit-dir=
			--bare
			--version
			--exec-path
			--exec-path=
			--html-path
			--man-path
			--info-path
			--work-tree=
			--namespace=
			--no-replace-objects
			--help
			"
			;;
		*)
			if test -n "${shit_TESTING_PORCELAIN_COMMAND_LIST-}"
			then
				__shitcomp "$shit_TESTING_PORCELAIN_COMMAND_LIST"
			else
				local list_cmds=list-mainporcelain,others,nohelpers,alias,list-complete,config

				if test "${shit_COMPLETION_SHOW_ALL_COMMANDS-}" = "1"
				then
					list_cmds=builtins,$list_cmds
				fi
				__shitcomp "$(__shit --list-cmds=$list_cmds)"
			fi
			;;
		esac
		return
	fi

	__shit_complete_command "$command" && return

	local expansion=$(__shit_aliased_command "$command")
	if [ -n "$expansion" ]; then
		words[1]=$expansion
		__shit_complete_command "$expansion"
	fi
}

__shitk_main ()
{
	__shit_has_doubledash && return

	local __shit_repo_path
	__shit_find_repo_path

	local merge=""
	if __shit_pseudoref_exists MERGE_HEAD; then
		merge="--merge"
	fi
	case "$cur" in
	--*)
		__shitcomp "
			$__shit_log_common_options
			$__shit_log_shitk_options
			$merge
			"
		return
		;;
	esac
	__shit_complete_revlist
}

if [[ -n ${ZSH_VERSION-} && -z ${shit_SOURCING_ZSH_COMPLETION-} ]]; then
	echo "ERROR: this script is obsolete, please see shit-completion.zsh" 1>&2
	return
fi

__shit_func_wrap ()
{
	local cur words cword prev
	local __shit_cmd_idx=0
	_get_comp_words_by_ref -n =: cur words cword prev
	$1
}

___shit_complete ()
{
	local wrapper="__shit_wrap${2}"
	eval "$wrapper () { __shit_func_wrap $2 ; }"
	complete -o bashdefault -o default -o nospace -F $wrapper $1 2>/dev/null \
		|| complete -o default -o nospace -F $wrapper $1
}

# Setup the completion for shit commands
# 1: command or alias
# 2: function to call (e.g. `shit`, `shitk`, `shit_fetch`)
__shit_complete ()
{
	local func

	if __shit_have_func $2; then
		func=$2
	elif __shit_have_func __$2_main; then
		func=__$2_main
	elif __shit_have_func _$2; then
		func=_$2
	else
		echo "ERROR: could not find function '$2'" 1>&2
		return 1
	fi
	___shit_complete $1 $func
}

___shit_complete shit __shit_main
___shit_complete shitk __shitk_main

# The following are necessary only for Cygwin, and only are needed
# when the user has tab-completed the executable name and consequently
# included the '.exe' suffix.
#
if [ "$OSTYPE" = cygwin ]; then
	___shit_complete shit.exe __shit_main
fi
