#!/bin/bash

_DS_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd -P)"

function jug_exec {
	if [[ -z ${_JUG_EXEC} ]]
	then
		local _JUG_EXEC=${_DS_UTILS_DIR}/jug/jug_exec.py
	fi
	local _JUG_ARGV=()
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--script | -s) local _JUG_EXEC="$1"; shift
			echo "script = [${_JUG_EXEC}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[--script | -s JUG_EXEC] path to the jug wrapper script (optional)"
			exit 1
			;;
			--) break ;;
			*) JUG_ARGV+=("${_arg}") ;;
		esac
	done
	# Remove trailing '/' in argv before sending to jug
	${_JUG_EXEC} "${JUG_ARGV[@]%/}" -- "${@%/}"
	jug sleep-until "${JUG_ARGV[@]%/}" ${_JUG_EXEC} -- "${@%/}"
}

function tmp_jug_exec {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--tmp) local _TMPDIR="$1"; shift
			echo "tmp = [${_TMPDIR}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--tmp DIR tmp dir to hold the temporary jug venv"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done
	which python3 || module load python/3.6
	which virtualenv || module load python/3.6
	_tmpjug=`mktemp -d -p ${_TMPDIR}`
	trap "rm -rf ${_tmpjug}" EXIT
	init_venv --name jug --tmp "${_tmpjug}"
	python3 -m pip install -r scripts/requirements_jug.txt
	jug_exec "$@"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
