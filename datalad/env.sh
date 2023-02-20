#!/bin/bash

pushd `dirname "${BASH_SOURCE[0]}"` >/dev/null
_SCRIPT_DIR=`pwd -P`
cd ..
_DS_UTILS_DIR=`pwd -P`
popd >/dev/null

source "${_DS_UTILS_DIR}/utils.sh" echo -n

set -o errexit -o pipefail

_ENV_NAME=
_PYTHON_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get python.version || echo)
_ANNEX_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get git-annex.version || echo)
_DATALAD_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get datalad.version || echo)
_PREFIXROOT=~

_ACTIVATE_PYTHON=0
_ACTIVATE_ANNEX=0
_ACTIVATE_DATALAD=0

while [[ $# -gt 0 ]]
do
	_arg="$1"; shift
	case "${_arg}" in
		-n | --name) _ENV_NAME="$1"; shift
		echo "env_name = [${_ENV_NAME}]"
		;;
		--py) _ACTIVATE_PYTHON=1
		case "$1" in
			"" | -* | --*) ;;
			*)  _PYTHON_VERSION="$1"; shift
			echo "python_version = [${_PYTHON_VERSION}]"
			;;
		esac
		;;
		--annex) _ACTIVATE_ANNEX=1
		case "$1" in
			"" | -* | --*) ;;
			*) _ANNEX_VERSION="$1"; shift
			echo "annex_version = [${_ANNEX_VERSION}]"
			;;
		esac
		;;
		--datalad) _ACTIVATE_DATALAD=1
		case "$1" in
			"" | -* | --*) ;;
			*) _DATALAD_VERSION="$1"; shift
			echo "datalad_version = [${_DATALAD_VERSION}]"
			;;
		esac
		;;
		--prefix) _PREFIXROOT="$1"; shift
		echo "prefix = [${_PREFIXROOT}]"
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

if [[ ${_ACTIVATE_PYTHON} -eq 1 ]] || [[ ${_ACTIVATE_ANNEX} -eq 1 ]]
then
	_GIT_ANNEX_ENV=$(echo "$([[ ! -z ${_ENV_NAME} ]] && echo "${_ENV_NAME}_")git-annex_cp${_PYTHON_VERSION/\./}")
	_py_install_args=(--yes --use-local --no-channel-priority python=${_PYTHON_VERSION} virtualenv)
	_annex_install_args=(--yes --use-local --no-channel-priority -c conda-forge git-annex=${_ANNEX_VERSION})

	init_conda_env --name ${_GIT_ANNEX_ENV} --prefix "${_PREFIXROOT}"
	if [[ ! -z "$(conda install --dry-run "${_py_install_args[@]}" 2>/dev/null |
		grep -E "::python-${_PYTHON_VERSION}|::virtualenv-")" ]] || \
		( [[ ${_ACTIVATE_ANNEX} -eq 1 ]] &&
			[[ ! -z "$(conda install --dry-run "${_annex_install_args[@]}" 2>/dev/null |
				grep -E " conda-forge(/.*)?::")" ]] )
	then
		_install_needed=1
	fi
	if [[ ${_install_needed} -eq 1 ]]
	then
		conda install "${_py_install_args[@]}"
	fi
	if [[ ${_ACTIVATE_ANNEX} -eq 1 ]] && [[ ${_install_needed} -eq 1 ]]
	then
		echo "-- Install git-annex version ${_ANNEX_VERSION}"
		conda install "${_annex_install_args[@]}"
	fi
fi

if [[ ${_ACTIVATE_DATALAD} -eq 1 ]] && [[ ! -z ${_DATALAD_VERSION} ]]
then
	_DATALAD_ENV=$(echo "$([[ ! -z ${_GIT_ANNEX_ENV} ]] && echo "${_GIT_ANNEX_ENV}/")datalad")

	echo "-- Install datalad version ${_DATALAD_VERSION}"
	init_venv --name ${_DATALAD_ENV} --prefix "${_PREFIXROOT}"
	if [[ ! -z ${_DATALAD_VERSION} ]]
	then
		python3 -m pip install datalad==${_DATALAD_VERSION}
	fi
fi

# Global config
# Having both annex.thin and annex.hardlink prevents 
# hardlinks to be used inter datasets/cache
# git config --system annex.thin true
# git config --system annex.hardlink true

"$@"
