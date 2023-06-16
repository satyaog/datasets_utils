#!/bin/bash
set -o errexit -o pipefail -o noclobber

_DS_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd -P)"
_USER_INSTALL=0

while [[ $# -gt 0 ]]
do
	_arg="$1"; shift
	case "${_arg}" in
		--venv) _VENV_LOCATION="$1"; shift
		>&2 echo "venv = [${_VENV_LOCATION}]"
		;;
		--user) _USER_INSTALL=1; shift
		>&2 echo "user = [${_USER_INSTALL}]"
		;;
		--user) _USER_INSTALL=1; shift
		>&2 echo "user = [${_USER_INSTALL}]"
		;;
		-h | --help)
		>&2 echo "Options for $(basename "$0") are:"
		>&2 echo "[--venv DIR] dir to hold the globus venv (optional)"
		>&2 echo "[--user] install to user space (optional)"
		>&2 echo "--user or --venv must be specified"
		exit 1
		;;
		--) break ;;
		*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
	esac
done

source ${_DS_UTILS_DIR}/utils.sh echo -n

if [[ ! ${_USER_INSTALL} -eq 0 ]]
then
	# Installing the Command Line Interface (CLI): https://docs.globus.org/cli/installation/
	python3 -m pip install --upgrade --user globus-cli

	# Add pip --user installs to your PATH: https://docs.globus.org/cli/installation/prereqs/#add_pip_user_installs_to_your_path
	_GLOBUS_CLI_INSTALL_DIR="$(python3 -c 'import site; print(site.USER_BASE)')/bin"
	echo "GLOBUS_CLI_INSTALL_DIR = [${_GLOBUS_CLI_INSTALL_DIR}]"

	mkdir -p ~/bin
	wget https://downloads.globus.org/globus-connect-personal/linux/stable/globusconnectpersonal-latest.tgz \
		-O ~/bin/globusconnectpersonal-latest.tgz
	tar xzf ~/bin/globusconnectpersonal-latest.tgz

	export PATH="${PATH}:${_GLOBUS_CLI_INSTALL_DIR}:${HOME}/bin/globusconnectpersonal-*/"
	echo '# Globus path' >> "${HOME}/.bashrc"
	echo "export PATH=\"\${PATH}:${_GLOBUS_CLI_INSTALL_DIR}:\${HOME}/bin/globusconnectpersonal-*/\"" >> "${HOME}/.bashrc"
else
	init_venv --name globus --tmp ${_VENV_LOCATION}
	python3 -m pip install --upgrade globus-cli
	mkdir -p ${_VENV_LOCATION}/bin
	wget https://downloads.globus.org/globus-connect-personal/linux/stable/globusconnectpersonal-latest.tgz \
		-O ${_VENV_LOCATION}/bin/globusconnectpersonal-latest.tgz
	tar xzf ${_VENV_LOCATION}/bin/globusconnectpersonal-latest.tgz
fi

globus whoami || globus login
