#!/bin/bash

function jug_exec {
	JUG_ARGV=()
	while [[ $# -gt 0 ]]
	do
		arg=$1; shift
		case ${arg} in
			--) break ;;
			*) JUG_ARGV+=("${arg}") ;;
		esac
	done
	# Remove trailing '/' in argv before sending to jug
	scripts/jug_exec.py "${JUG_ARGV[@]%/}" -- "${@%/}"
	jug sleep-until "${JUG_ARGV[@]%/}" scripts/jug_exec.py -- "${@%/}"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi