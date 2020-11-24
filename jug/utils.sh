#!/bin/bash

function jug_exec {
	JUG_ARGV=()
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--) break ;;
			*) JUG_ARGV+=("${arg}") ;;
		esac
	done
	# Remove trailing '/' in argv before sending to jug
	scripts/jug_exec.py "${JUG_ARGV[@]%/}" -- "${@%/}"
	jug sleep-until "${JUG_ARGV[@]%/}" scripts/jug_exec.py -- "${@%/}"
}

function tmp_jug_exec {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--tmp) TMPDIR="$1"; shift
			echo "tmp = [${TMPDIR}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--tmp DIR tmp dir to hold conda, virtualenv prefixes and datasets"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done
	which python3 || module load python/3.6
	which virtualenv || module load python/3.6
	_tmpjug=`mktemp -d -p ${TMPDIR}`
	trap "rm -rf ${_tmpjug}" EXIT
	init_venv --name jug --tmp "${_tmpjug}"
	python3 -m pip install -r scripts/requirements_jug.txt
	jug_exec "$@"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi