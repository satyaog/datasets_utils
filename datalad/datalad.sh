#!/bin/bash

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )"; pwd -P)"

dlcreate()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		local _arg=${!i}
		case ${_arg} in
			-n | --name)
			i=$((i+1))
			local _NAME=${!i}
			echo "name = [${_NAME}]"
			;;
			-s | --sibling)
			i=$((i+1))
			local _SIBLING=${!i}
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

	python ${_DIR}/datalad_brf.py create ${_NAME} ${_SIBLING}
}

dlinst()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		local _arg=${!i}
		case ${_arg} in
			-n | --name)
			i=$((i+1))
			local _NAME=${!i}
			echo "name = [${_NAME}]"
			;;
			-s | --sibling)
			i=$((i+1))
			local _SIBLING=${!i}
			echo "sibling = [${_SIBLING}]"
			;;
			--url)
			i=$((i+1))
			local _URL=${!i}
			echo "url = [${_URL}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${_arg}]. Valid options are:"
			>&2 echo "--url url of the dataset to install"
			>&2 echo "[-n | --name] name of the dataset to install (optional)"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
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

	python ${_DIR}/datalad_brf.py install ${_URL} ${_NAME} ${_SIBLING}
}

dlinstsubds()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		local _arg=${!i}
		case ${_arg} in
			-s | --sibling)
			i=$((i+1))
			local _SIBLING=${!i}
			echo "sibling = [${_SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${_arg}]. Valid options are:"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python ${_DIR}/datalad_brf.py install_subdatasets ${_SIBLING}
}

dlpublish()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		local _arg=${!i}
		case ${_arg} in
			-p | --path)
			i=$((i+1))
			local _PATH=${!i}
			echo "path = [${_PATH}]"
			;;
			-s | --sibling)
			i=$((i+1))
			local _SIBLING=${!i}
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

	python ${_DIR}/datalad_brf.py publish ${_PATH} ${_SIBLING}
}

dlupdate()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		local _arg=${!i}
		case ${_arg} in
			-s | --sibling)
			i=$((i+1))
			local _SIBLING=${!i}
			echo "sibling = [${_SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${_arg}]. Valid options are:"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python ${_DIR}/datalad_brf.py update ${_SIBLING}
}

dlinitgithub()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		local _arg=${!i}
		case ${_arg} in
			-n | --name)
			i=$((i+1))
			local _NAME=${!i}
			echo "name = [${_NAME}]"
			;;
			-l | --login)
			i=$((i+1))
			local _LOGIN=${!i}
			echo "login = [${_LOGIN}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${_arg}]. valid options are:"
			>&2 echo "[-n | --name] name of the dataset to create (optional)"
			>&2 echo "[-l | --login] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python ${_DIR}/datalad_brf.py init_github ${_NAME} ${_LOGIN}
}
