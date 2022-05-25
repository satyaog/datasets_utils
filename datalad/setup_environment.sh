#!/bin/bash

pushd `dirname "${BASH_SOURCE[0]}"` >/dev/null
_SCRIPT_DIR=`pwd -P`
cd ..
_DS_UTILS_DIR=`pwd -P`
popd >/dev/null

source "${_DS_UTILS_DIR}/utils.sh" echo -n

set -o errexit -o pipefail

_ENV_NAME=datalad
_PYTHON_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get python.version || echo)
_ANNEX_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get git-annex.version || echo)
_DATALAD_VERSION=$(git config --file "${_SCRIPT_DIR}"/install_config --get datalad.version || echo)

while [[ $# -gt 0 ]]
do
	_arg="$1"; shift
	case "${_arg}" in
		-n | --name) _ENV_NAME="$1"; shift
		echo "env_name = [${_ENV_NAME}]"
		;;
		--python) _PYTHON_VERSION="$1"; shift
		echo "python_version = [${_PYTHON_VERSION}]"
		;;
		--annex) _ANNEX_VERSION="$1"; shift
		echo "annex_version = [${_ANNEX_VERSION}]"
		;;
		--datalad) _DATALAD_VERSION="$1"; shift
		echo "datalad_version = [${_DATALAD_VERSION}]"
		;;
		-h | --help | *)
		if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
		then
			>&2 echo "Unknown option [${_arg}]"
		fi
		>&2 echo "Options for $(basename ${BASH_SOURCE[0]}) are:"
		>&2 echo "-n | --name conda environment name"
		>&2 echo "--python version of python"
		>&2 echo "--annex version of git-annex"
		>&2 echo "--datalad version of datalad"
		exit 1
		;;
	esac
done

_GIT_ANNEX_ENV=${_ENV_NAME}_git-annex${_PYTHON_VERSION}
_DATALAD_ENV=datalad

init_conda_env --name ${_GIT_ANNEX_ENV} --prefix ~
conda install --yes --use-local --no-channel-priority python=${_PYTHON_VERSION} virtualenv
echo
echo "-- Install git-annex version ${_ANNEX_VERSION} and datalad version ${_DATALAD_VERSION}"
conda install --yes --use-local --no-channel-priority -c conda-forge git-annex=${_ANNEX_VERSION}
init_venv --name ${_GIT_ANNEX_ENV}/${_DATALAD_ENV} --prefix ~
python3 -m pip install datalad==${_DATALAD_VERSION}

# Global config
# Having both annex.thin and annex.hardlink prevents 
# hardlinks to be used inter datasets/cache
# git config --system annex.thin true
# git config --system annex.hardlink true
