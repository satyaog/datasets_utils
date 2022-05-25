#!/bin/bash

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )"; pwd -P)"

dlcreate()
{
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case ${_arg} in
			-n | --name) local _NAME="$1"; shift
			echo "name = [${_NAME}]"
			;;
			-s | --sibling) local _SIBLING="$1"; shift
			echo "sibling = [${_SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${_arg}]. valid options are:"
			>&2 echo "-n | --name name of the dataset to create"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	if [ -z "${_NAME}" ]
	then
		>&2 echo "[-n | --name] name of the dataset"
		>&2 echo missing --name option
		exit 1
	fi

	python3 ${_DIR}/datalad_brf.py create name=${_NAME} sibling=${_SIBLING}
}

dlinst()
{
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case ${_arg} in
			--url) local _URL="$1"; shift
			echo "url = [${_URL}]"
			;;
			-n | --name) local _NAME="$1"; shift
			echo "name = [${_NAME}]"
			;;
			-s | --sibling) local _SIBLING="$1"; shift
			echo "sibling = [${_SIBLING}]"
			;;
			-r | --recursive) local _RECURSIVE=1
			echo "recursive = [${_RECURSIVE}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${_arg}]. Valid options are:"
			>&2 echo "--url url of the dataset to install"
			>&2 echo "[-n | --name] name of the dataset to install (optional)"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			>&2 echo "[-r | --recursive] recursive install of the dataset and subdatasets (optional)"
			exit 1
			;;
		esac
	done

	if [ -z "${_URL}" ]
	then
		>&2 echo "--url url of the dataset to install"
		>&2 echo Missing --url option
		exit 1
	fi

	python3 ${_DIR}/datalad_brf.py install url=${_URL} name=${_NAME} sibling=${_SIBLING} recursive=${_RECURSIVE}
}

dlinstsubds()
{
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case ${_arg} in
			-s | --sibling) local _SIBLING="$1"; shift
			echo "sibling = [${_SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${_arg}]. Valid options are:"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python3 ${_DIR}/datalad_brf.py install_subdatasets sibling=${_SIBLING}
}

dlpublish()
{
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case ${_arg} in
			-p | --path) local _PATH="$1"; shift
			echo "path = [${_PATH}]"
			;;
			-s | --sibling) local _SIBLING="$1"; shift
			echo "sibling = [${_SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${_arg}]. valid options are:"
			>&2 echo "[-p | --name] name of the dataset to create (optional)"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python3 ${_DIR}/datalad_brf.py publish path=${_PATH} sibling=${_SIBLING}
}

dlupdate()
{
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case ${_arg} in
			-s | --sibling) local _SIBLING="$1"; shift
			echo "sibling = [${_SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${_arg}]. Valid options are:"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python3 ${_DIR}/datalad_brf.py update sibling=${_SIBLING}
}

dlinitgithub()
{
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case ${_arg} in
			-n | --name) local _NAME="$1"; shift
			echo "name = [${_NAME}]"
			;;
			-l | --login) local _LOGIN="$1"; shift
			echo "login = [${_LOGIN}]"
			;;
			-t | --token) local _TOKEN="$1"; shift
			echo "token = [${_TOKEN}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${_arg}]. valid options are:"
			>&2 echo "[-n | --name] name of the dataset to create (optional)"
			>&2 echo "[-l | --login] GitHub username (optional)"
			>&2 echo "[-l | --token] GitHub autorization token (optional)"
			exit 1
			;;
		esac
	done

	python3 ${_DIR}/datalad_brf.py init_github name=${_NAME} login=${_LOGIN} token=${_TOKEN}
}
