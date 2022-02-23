#!/bin/bash

pushd `dirname "${BASH_SOURCE[0]}"` >/dev/null
_SCRIPT_DIR=`pwd -P`
cd ..
_DS_UTILS_DIR=`pwd -P`
popd >/dev/null

function jug_exec {
	if [[ -z ${_jug_exec} ]]
	then
		local _jug_exec=${_SCRIPT_DIR}/jug_exec.py
	fi
	local _jug_argv=()
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--script | -s) local _jug_exec="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "[--script | -s JUG_EXEC] path to the jug wrapper script (default: '${_jug_exec}')"
			${_jug_exec} --help
			exit
			;;
			--) break ;;
			*) _jug_argv+=("${_arg}") ;;
		esac
	done
	# Remove trailing '/' in argv before sending to jug
	${_jug_exec} "${_jug_argv[@]%/}" -- "${@%/}"
	jug sleep-until "${_jug_argv[@]%/}" ${_jug_exec} -- "${@%/}"
}

function tmp_jug_exec {
	source ${_DS_UTILS_DIR}/utils.sh echo -n

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--tmp) local _tmpdir="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--tmp DIR tmp dir to hold the temporary jug venv"
			exit
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done
	which python3 || module load python/3.6
	which virtualenv || module load python/3.6
	mkdir -p ${_tmpdir}
	_tmpjug=`mktemp -d -p ${_tmpdir}`
	trap "rm -rf ${_tmpjug}" EXIT
	init_venv --name jug --tmp "${_tmpjug}"
	python3 -m pip install -r ${_SCRIPT_DIR}/requirements_jug.txt
	jug_exec "$@"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
