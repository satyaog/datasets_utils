#!/bin/bash

function add_endpoint {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _NAME="$1"; shift
			>&2 echo "name = [${_NAME}]"
			;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name NAME endpoint name"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z "$(globus endpoint search --filter-scope "my-gcp-endpoints" | cut -d"|" -f3 | grep -E "\s${_NAME}\s")" ]]
	then
		>&2 echo "GCP endpoint ${_NAME} already exists. Please remove the endpoint if you wish to readd the endpoint: https://app.globus.org/collections?scope=administered-by-me"
		return
	fi

	# Install Globus Connect Personal for Linux: https://docs.globus.org/how-to/globus-connect-personal-linux/#globus-connect-personal-cli
	globus gcp create mapped ${_NAME}

	read -p "Paste the setup key : " _setup_key

	globusconnectpersonal -setup --setup-key ${_setup_key}
}

function start_endpoint {
	local _RW=0
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--dir) local _DIR="$1"; shift
			>&2 echo "dir = [${_DIR}]"
			;;
			--rw) local _RW=1; shift
			>&2 echo "rw = [${_RW}]"
			;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--dir DIR directory accessible by the endpoint"
			>&2 echo "[--rw] read-write (optional)"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! ${_RW} -eq 0 ]]
	then
		local _DIR=rw${_DIR#rw}/
	else
		local _DIR=r${_DIR#r}/
	fi

	globusconnectpersonal -start -restrict-paths ${_DIR}
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
