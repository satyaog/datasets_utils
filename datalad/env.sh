#!/bin/bash

pushd `dirname "${BASH_SOURCE[0]}"` >/dev/null
_SCRIPT_DIR=`pwd -P`
cd ..
_DS_UTILS_DIR=`pwd -P`
popd >/dev/null

source "${_DS_UTILS_DIR}/utils.sh" echo -n

_options=$(get_options)
set -o errexit -o pipefail

_ENV_NAME=
_PYTHON_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get python.version || echo)
_ANNEX_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get git-annex.version || echo)
_DATALAD_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get datalad.version || echo)
_PREFIXROOT=~

_ACTIVATE_ANNEX=0
_ACTIVATE_DATALAD=0

while [[ $# -gt 0 ]]
do
	_arg="$1"; shift
	case "${_arg}" in
		-n | --name) _ENV_NAME="$1"; shift
		>&2 echo "env_name = [${_ENV_NAME}]"
		;;
		--py) _PYTHON_VERSION="$1"; shift
		>&2 echo "python_version = [${_PYTHON_VERSION}]"
		;;
		--annex) _ACTIVATE_ANNEX=1
		case "$1" in
			"" | -* | --*) ;;
			*) _ANNEX_VERSION="$1"; shift
			>&2 echo "annex_version = [${_ANNEX_VERSION}]"
			;;
		esac
		;;
		--datalad) _ACTIVATE_DATALAD=1
		case "$1" in
			"" | -* | --*) ;;
			*) _DATALAD_VERSION="$1"; shift
			>&2 echo "datalad_version = [${_DATALAD_VERSION}]"
			;;
		esac
		;;
		--prefix) _PREFIXROOT="$1"; shift
		>&2 echo "prefix = [${_PREFIXROOT}]"
		;;
		--) break ;;
		-h | --help | *)
		if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
		then
			>&2 echo "Unknown option [${_arg}]"
		fi
		>&2 echo "Options for $(basename ${BASH_SOURCE[0]}) are:"
		>&2 echo "-n | --name environment name"
		>&2 echo "--py VERSION of python"
		>&2 echo "--annex VERSION of git-annex"
		>&2 echo "--datalad VERSION of datalad"
		>&2 echo "--prefix DIR directory to hold the env and venv prefix"
		exit 1
		;;
	esac
done

if [[ ${_ACTIVATE_ANNEX} -eq 1 ]]
then
	_GIT_ANNEX_ENV=$(echo "$([[ ! -z ${_ENV_NAME} ]] && echo "${_ENV_NAME}_")git-annex")
	_annex_install_args=(--yes --use-local --no-channel-priority -c conda-forge git-annex=${_ANNEX_VERSION})

	>&2 init_conda_env --name ${_GIT_ANNEX_ENV} --prefix "${_PREFIXROOT}"
	>&2 echo "-- Install git-annex version ${_ANNEX_VERSION}"
	>&2 conda install "${_annex_install_args[@]}"
fi

if [[ ${_ACTIVATE_DATALAD} -eq 1 ]] && [[ ! -z ${_DATALAD_VERSION} ]]
then
	_prefix="${_SCRIPT_DIR}/.versions"
	_name="cp${_PYTHON_VERSION/./}/datalad_${_DATALAD_VERSION}"
	mkdir -p "$(dirname "${_prefix}/venv/${_name}.py")"

	# Basic check to avoid a bit race conditions issues
	if [[ ! -e "${_prefix}/venv/${_name}.py" ]]
	then
		touch "${_prefix}/venv/${_name}.py"

		echo -n "
# /// script
# requires-python = '>=${_PYTHON_VERSION}'
# dependencies = [
#   'datalad==${_DATALAD_VERSION}',
# ]
# [tool.hatch]
# python = '${_PYTHON_VERSION}'
# python-sources = ['external', 'internal']
# installer = 'uv'
# path = '../$(basename "${_name}")'
# ///

import subprocess
import sys

print(sys.executable, file=sys.stderr)
if sys.argv[1:]:
    subprocess.run(sys.argv[1:], check=True)" \
		>"${_prefix}/venv/${_name}.py"
	fi

	init_venv --name ${_name} --prefix "${_prefix}"
fi

# Global config
# Having both annex.thin and annex.hardlink prevents 
# hardlinks to be used inter datasets/cache
# git config --system annex.thin true
# git config --system annex.hardlink true

set_options $_options
unset _options

"$@"
