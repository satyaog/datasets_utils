#!/bin/bash

DS_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd -P)"

function jug_exec {
	if [[ -z ${JUG_EXEC} ]]
	then
		JUG_EXEC=${DS_UTILS_DIR}/jug/jug_exec.py
	fi
	JUG_ARGV=()
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--script | -s) JUG_EXEC="$1"; shift
			echo "script = [${JUG_EXEC}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[--script | -s JUG_EXEC] path to the jug wrapper script (optional)"
			exit 1
			;;
			--) break ;;
			*) JUG_ARGV+=("${arg}") ;;
		esac
	done
	# Remove trailing '/' in argv before sending to jug
	${JUG_EXEC} "${JUG_ARGV[@]%/}" -- "${@%/}"
	jug sleep-until "${JUG_ARGV[@]%/}" ${JUG_EXEC} -- "${@%/}"
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
			>&2 echo "--tmp DIR tmp dir to hold the temporary jug venv"
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
