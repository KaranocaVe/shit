# This shell scriplet is meant to be included by other shell scripts
# to set up some variables pointing at the normal shit directories and
# a few helper shell functions.

# Having this variable in your environment would break scripts because
# you would cause "cd" to be taken to unexpected places.  If you
# like CDPATH, define it for your interactive shell sessions without
# exporting it.
# But we protect ourselves from such a user mistake nevertheless.
unset CDPATH

# Similarly for IFS, but some shells (e.g. FreeBSD 7.2) are buggy and
# do not equate an unset IFS with IFS with the default, so here is
# an explicit SP HT LF.
IFS=' 	
'

shit_broken_path_fix () {
	case ":$PATH:" in
	*:$1:*) : ok ;;
	*)
		PATH=$(
			SANE_TOOL_PATH="$1"
			IFS=: path= sep=
			set x $PATH
			shift
			for elem
			do
				case "$SANE_TOOL_PATH:$elem" in
				(?*:/bin | ?*:/usr/bin)
					path="$path$sep$SANE_TOOL_PATH"
					sep=:
					SANE_TOOL_PATH=
				esac
				path="$path$sep$elem"
				sep=:
			done
			echo "$path"
		)
		;;
	esac
}

# @@BROKEN_PATH_FIX@@

# Source shit-sh-i18n for gettext support.
. "$(shit --exec-path)/shit-sh-i18n"

die () {
	die_with_status 1 "$@"
}

die_with_status () {
	status=$1
	shift
	printf >&2 '%s\n' "$*"
	exit "$status"
}

if test -n "$OPTIONS_SPEC"; then
	usage() {
		"$0" -h
		exit 1
	}

	parseopt_extra=
	[ -n "$OPTIONS_KEEPDASHDASH" ] &&
		parseopt_extra="--keep-dashdash"
	[ -n "$OPTIONS_STUCKLONG" ] &&
		parseopt_extra="$parseopt_extra --stuck-long"

	eval "$(
		echo "$OPTIONS_SPEC" |
			shit rev-parse --parseopt $parseopt_extra -- "$@" ||
		echo exit $?
	)"
else
	dashless=$(basename -- "$0" | sed -e 's/-/ /')
	usage() {
		die "$(eval_gettext "usage: \$dashless \$USAGE")"
	}

	if [ -z "$LONG_USAGE" ]
	then
		LONG_USAGE="$(eval_gettext "usage: \$dashless \$USAGE")"
	else
		LONG_USAGE="$(eval_gettext "usage: \$dashless \$USAGE

$LONG_USAGE")"
	fi

	case "$1" in
		-h)
		echo "$LONG_USAGE"
		exit
	esac
fi

# Set the name of the end-user facing command in the reflog when the
# script may update refs.  When shit_REFLOG_ACTION is already set, this
# will not overwrite it, so that a scripted Porcelain (e.g. "shit
# rebase") can set it to its own name (e.g. "rebase") and then call
# another scripted Porcelain (e.g. "shit am") and a call to this
# function in the latter will keep the name of the end-user facing
# program (e.g. "rebase") in shit_REFLOG_ACTION, ensuring whatever it
# does will be record as actions done as part of the end-user facing
# operation (e.g. "rebase").
#
# NOTE NOTE NOTE: consequently, after assigning a specific message to
# shit_REFLOG_ACTION when calling a "shit" command to record a custom
# reflog message, do not leave that custom value in shit_REFLOG_ACTION,
# after you are done.  Other callers of "shit" commands that rely on
# writing the default "program name" in reflog expect the variable to
# contain the value set by this function.
#
# To use a custom reflog message, do either one of these three:
#
# (a) use a single-shot export form:
#     shit_REFLOG_ACTION="$shit_REFLOG_ACTION: preparing frotz" \
#         shit command-that-updates-a-ref
#
# (b) save the original away and restore:
#     SAVED_ACTION=$shit_REFLOG_ACTION
#     shit_REFLOG_ACTION="$shit_REFLOG_ACTION: preparing frotz"
#     shit command-that-updates-a-ref
#     shit_REFLOG_ACITON=$SAVED_ACTION
#
# (c) assign the variable in a subshell:
#     (
#         shit_REFLOG_ACTION="$shit_REFLOG_ACTION: preparing frotz"
#         shit command-that-updates-a-ref
#     )
set_reflog_action() {
	if [ -z "${shit_REFLOG_ACTION:+set}" ]
	then
		shit_REFLOG_ACTION="$*"
		export shit_REFLOG_ACTION
	fi
}

shit_editor() {
	if test -z "${shit_EDITOR:+set}"
	then
		shit_EDITOR="$(shit var shit_EDITOR)" || return $?
	fi

	eval "$shit_EDITOR" '"$@"'
}

shit_pager() {
	if test -t 1
	then
		shit_PAGER=$(shit var shit_PAGER)
	else
		shit_PAGER=cat
	fi
	for vardef in @@PAGER_ENV@@
	do
		var=${vardef%%=*}
		eval ": \"\${$vardef}\" && export $var"
	done

	eval "$shit_PAGER" '"$@"'
}

is_bare_repository () {
	shit rev-parse --is-bare-repository
}

cd_to_toplevel () {
	cdup=$(shit rev-parse --show-toplevel) &&
	cd "$cdup" || {
		gettextln "Cannot chdir to \$cdup, the toplevel of the working tree" >&2
		exit 1
	}
}

require_work_tree_exists () {
	if test "z$(shit rev-parse --is-bare-repository)" != zfalse
	then
		program_name=$0
		die "$(eval_gettext "fatal: \$program_name cannot be used without a working tree.")"
	fi
}

require_work_tree () {
	test "$(shit rev-parse --is-inside-work-tree 2>/dev/null)" = true || {
		program_name=$0
		die "$(eval_gettext "fatal: \$program_name cannot be used without a working tree.")"
	}
}

require_clean_work_tree () {
	shit rev-parse --verify HEAD >/dev/null || exit 1
	shit update-index -q --ignore-submodules --refresh
	err=0

	if ! shit diff-files --quiet --ignore-submodules
	then
		action=$1
		case "$action" in
		"rewrite branches")
			gettextln "Cannot rewrite branches: You have unstaged changes." >&2
			;;
		*)
			eval_gettextln "Cannot \$action: You have unstaged changes." >&2
			;;
		esac
		err=1
	fi

	if ! shit diff-index --cached --quiet --ignore-submodules HEAD --
	then
		if test $err = 0
		then
			action=$1
			eval_gettextln "Cannot \$action: Your index contains uncommitted changes." >&2
		else
		    gettextln "Additionally, your index contains uncommitted changes." >&2
		fi
		err=1
	fi

	if test $err = 1
	then
		test -n "$2" && echo "$2" >&2
		exit 1
	fi
}

# Generate a sed script to parse identities from a commit.
#
# Reads the commit from stdin, which should be in raw format (e.g., from
# cat-file or "--pretty=raw").
#
# The first argument specifies the ident line to parse (e.g., "author"), and
# the second specifies the environment variable to put it in (e.g., "AUTHOR"
# for "shit_AUTHOR_*"). Multiple pairs can be given to parse author and
# committer.
pick_ident_script () {
	while test $# -gt 0
	do
		lid=$1; shift
		uid=$1; shift
		printf '%s' "
		/^$lid /{
			s/'/'\\\\''/g
			h
			s/^$lid "'\([^<]*\) <[^>]*> .*$/\1/'"
			s/.*/shit_${uid}_NAME='&'/p

			g
			s/^$lid "'[^<]* <\([^>]*\)> .*$/\1/'"
			s/.*/shit_${uid}_EMAIL='&'/p

			g
			s/^$lid "'[^<]* <[^>]*> \(.*\)$/@\1/'"
			s/.*/shit_${uid}_DATE='&'/p
		}
		"
	done
	echo '/^$/q'
}

# Create a pick-script as above and feed it to sed. Stdout is suitable for
# feeding to eval.
parse_ident_from_commit () {
	LANG=C LC_ALL=C sed -ne "$(pick_ident_script "$@")"
}

# Parse the author from a commit given as an argument. Stdout is suitable for
# feeding to eval to set the usual shit_* ident variables.
get_author_ident_from_commit () {
	encoding=$(shit config i18n.commitencoding || echo UTF-8)
	shit show -s --pretty=raw --encoding="$encoding" "$1" -- |
	parse_ident_from_commit author AUTHOR
}

# Generate a virtual base file for a two-file merge. Uses shit apply to
# remove lines from $1 that are not in $2, leaving only common lines.
create_virtual_base() {
	sz0=$(wc -c <"$1")
	@@DIFF@@ -u -La/"$1" -Lb/"$1" "$1" "$2" | shit apply --no-add
	sz1=$(wc -c <"$1")

	# If we do not have enough common material, it is not
	# worth trying two-file merge using common subsections.
	expr $sz0 \< $sz1 \* 2 >/dev/null || : >"$1"
}


# Platform specific tweaks to work around some commands
case $(uname -s) in
*MINGW*)
	# Windows has its own (incompatible) sort and find
	sort () {
		/usr/bin/sort "$@"
	}
	find () {
		/usr/bin/find "$@"
	}
	# shit sees Windows-style pwd
	pwd () {
		builtin pwd -W
	}
	is_absolute_path () {
		case "$1" in
		[/\\]* | [A-Za-z]:*)
			return 0 ;;
		esac
		return 1
	}
	;;
*)
	is_absolute_path () {
		case "$1" in
		/*)
			return 0 ;;
		esac
		return 1
	}
esac

# Make sure we are in a valid repository of a vintage we understand,
# if we require to be in a shit repository.
shit_dir_init () {
	shit_DIR=$(shit rev-parse --shit-dir) || exit
	if [ -z "$SUBDIRECTORY_OK" ]
	then
		test -z "$(shit rev-parse --show-cdup)" || {
			exit=$?
			gettextln "You need to run this command from the toplevel of the working tree." >&2
			exit $exit
		}
	fi
	test -n "$shit_DIR" && shit_DIR=$(cd "$shit_DIR" && pwd) || {
		gettextln "Unable to determine absolute path of shit directory" >&2
		exit 1
	}
	: "${shit_OBJECT_DIRECTORY="$(shit rev-parse --shit-path objects)"}"
}

if test -z "$NONshit_OK"
then
	shit_dir_init
fi

peel_committish () {
	case "$1" in
	:/*)
		peeltmp=$(shit rev-parse --verify "$1") &&
		shit rev-parse --verify "${peeltmp}^0"
		;;
	*)
		shit rev-parse --verify "${1}^0"
		;;
	esac
}
