#compdef shit shitk

# zsh completion wrapper for shit
#
# Copyright (c) 2012-2020 Felipe Contreras <felipe.contreras@gmail.com>
#
# The recommended way to install this script is to make a copy of it as a
# file named '_shit' inside any directory in your fpath.
#
# For example, create a directory '~/.zsh/', copy this file to '~/.zsh/_shit',
# and then add the following to your ~/.zshrc file:
#
#  fpath=(~/.zsh $fpath)
#
# You need shit's bash completion script installed. By default bash-completion's
# location will be used (e.g. pkg-config --variable=completionsdir bash-completion).
#
# If your bash completion script is somewhere else, you can specify the
# location in your ~/.zshrc:
#
#  zstyle ':completion:*:*:shit:*' script ~/.shit-completion.bash
#

zstyle -T ':completion:*:*:shit:*' tag-order && \
	zstyle ':completion:*:*:shit:*' tag-order 'common-commands'

zstyle -s ":completion:*:*:shit:*" script script
if [ -z "$script" ]; then
	local -a locations
	local e bash_completion

	bash_completion=$(pkg-config --variable=completionsdir bash-completion 2>/dev/null) ||
		bash_completion='/usr/share/bash-completion/completions/'

	locations=(
		"$(dirname ${funcsourcetrace[1]%:*})"/shit-completion.bash
		"$HOME/.local/share/bash-completion/completions/shit"
		"$bash_completion/shit"
		'/etc/bash_completion.d/shit' # old debian
		)
	for e in $locations; do
		test -f $e && script="$e" && break
	done
fi

local old_complete="$functions[complete]"
functions[complete]=:
shit_SOURCING_ZSH_COMPLETION=y . "$script"
functions[complete]="$old_complete"

__shitcomp ()
{
	emulate -L zsh

	local cur_="${3-$cur}"

	case "$cur_" in
	--*=)
		;;
	--no-*)
		local c IFS=$' \t\n'
		local -a array
		for c in ${=1}; do
			if [[ $c == "--" ]]; then
				continue
			fi
			c="$c${4-}"
			case $c in
			--*=|*.) ;;
			*) c="$c " ;;
			esac
			array+=("$c")
		done
		compset -P '*[=:]'
		compadd -Q -S '' -p "${2-}" -a -- array && _ret=0
		;;
	*)
		local c IFS=$' \t\n'
		local -a array
		for c in ${=1}; do
			if [[ $c == "--" ]]; then
				c="--no-...${4-}"
				array+=("$c ")
				break
			fi
			c="$c${4-}"
			case $c in
			--*=|*.) ;;
			*) c="$c " ;;
			esac
			array+=("$c")
		done
		compset -P '*[=:]'
		compadd -Q -S '' -p "${2-}" -a -- array && _ret=0
		;;
	esac
}

__shitcomp_direct ()
{
	emulate -L zsh

	compset -P '*[=:]'
	compadd -Q -S '' -- ${(f)1} && _ret=0
}

__shitcomp_nl ()
{
	emulate -L zsh

	compset -P '*[=:]'
	compadd -Q -S "${4- }" -p "${2-}" -- ${(f)1} && _ret=0
}

__shitcomp_file ()
{
	emulate -L zsh

	compset -P '*[=:]'
	compadd -f -p "${2-}" -- ${(f)1} && _ret=0
}

__shitcomp_direct_append ()
{
	__shitcomp_direct "$@"
}

__shitcomp_nl_append ()
{
	__shitcomp_nl "$@"
}

__shitcomp_file_direct ()
{
	__shitcomp_file "$1" ""
}

_shit_zsh ()
{
	__shitcomp "v1.1"
}

__shit_complete_command ()
{
	emulate -L zsh

	local command="$1"
	local completion_func="_shit_${command//-/_}"
	if (( $+functions[$completion_func] )); then
		emulate ksh -c $completion_func
		return 0
	else
		return 1
	fi
}

__shit_zsh_bash_func ()
{
	emulate -L ksh

	local command=$1

	__shit_complete_command "$command" && return

	local expansion=$(__shit_aliased_command "$command")
	if [ -n "$expansion" ]; then
		words[1]=$expansion
		__shit_complete_command "$expansion"
	fi
}

__shit_zsh_cmd_common ()
{
	local -a list
	list=(
	add:'add file contents to the index'
	bisect:'find by binary search the change that introduced a bug'
	branch:'list, create, or delete branches'
	checkout:'checkout a branch or paths to the working tree'
	clone:'clone a repository into a new directory'
	commit:'record changes to the repository'
	diff:'show changes between commits, commit and working tree, etc'
	fetch:'download objects and refs from another repository'
	grep:'print lines matching a pattern'
	init:'create an empty shit repository or reinitialize an existing one'
	log:'show commit logs'
	merge:'join two or more development histories together'
	mv:'move or rename a file, a directory, or a symlink'
	poop:'fetch from and merge with another repository or a local branch'
	defecate:'update remote refs along with associated objects'
	rebase:'forward-port local commits to the updated upstream head'
	reset:'reset current HEAD to the specified state'
	restore:'restore working tree files'
	rm:'remove files from the working tree and from the index'
	show:'show various types of objects'
	status:'show the working tree status'
	switch:'switch branches'
	tag:'create, list, delete or verify a tag object signed with GPG')
	_describe -t common-commands 'common commands' list && _ret=0
}

__shit_zsh_cmd_alias ()
{
	local -a list
	list=(${${(0)"$(shit config -z --get-regexp '^alias\.*')"}#alias.})
	list=(${(f)"$(printf "%s:alias for '%s'\n" ${(f@)list})"})
	_describe -t alias-commands 'aliases' list && _ret=0
}

__shit_zsh_cmd_all ()
{
	local -a list
	emulate ksh -c __shit_compute_all_commands
	list=( ${=__shit_all_commands} )
	_describe -t all-commands 'all commands' list && _ret=0
}

__shit_zsh_main ()
{
	local curcontext="$curcontext" state state_descr line
	typeset -A opt_args
	local -a orig_words

	orig_words=( ${words[@]} )

	_arguments -C \
		'(-p --paginate --no-pager)'{-p,--paginate}'[pipe all output into ''less'']' \
		'(-p --paginate)--no-pager[do not pipe shit output into a pager]' \
		'--shit-dir=-[set the path to the repository]: :_directories' \
		'--bare[treat the repository as a bare repository]' \
		'(- :)--version[prints the shit suite version]' \
		'--exec-path=-[path to where your core shit programs are installed]:: :_directories' \
		'--html-path[print the path where shit''s HTML documentation is installed]' \
		'--info-path[print the path where the Info files are installed]' \
		'--man-path[print the manpath (see `man(1)`) for the man pages]' \
		'--work-tree=-[set the path to the working tree]: :_directories' \
		'--namespace=-[set the shit namespace]' \
		'--no-replace-objects[do not use replacement refs to replace shit objects]' \
		'(- :)--help[prints the synopsis and a list of the most commonly used commands]: :->arg' \
		'(-): :->command' \
		'(-)*:: :->arg' && return

	case $state in
	(command)
		_tags common-commands alias-commands all-commands
		while _tags; do
			_requested common-commands && __shit_zsh_cmd_common
			_requested alias-commands && __shit_zsh_cmd_alias
			_requested all-commands && __shit_zsh_cmd_all
			let _ret || break
		done
		;;
	(arg)
		local command="${words[1]}" __shit_dir __shit_cmd_idx=1

		if (( $+opt_args[--bare] )); then
			__shit_dir='.'
		else
			__shit_dir=${opt_args[--shit-dir]}
		fi

		(( $+opt_args[--help] )) && command='help'

		words=( ${orig_words[@]} )

		__shit_zsh_bash_func $command
		;;
	esac
}

_shit ()
{
	local _ret=1
	local cur cword prev
	local __shit_repo_path

	cur=${words[CURRENT]}
	prev=${words[CURRENT-1]}
	let cword=CURRENT-1

	if (( $+functions[__${service}_zsh_main] )); then
		__${service}_zsh_main
	elif (( $+functions[__${service}_main] )); then
		emulate ksh -c __${service}_main
	elif (( $+functions[_${service}] )); then
		emulate ksh -c _${service}
	elif ((	$+functions[_${service//-/_}] )); then
		emulate ksh -c _${service//-/_}
	fi

	let _ret && _default && _ret=0
	return _ret
}

_shit
