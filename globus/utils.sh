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
			--rw) local _RW=1;
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

function copy {
	local _HELP=$(
		echo "Options for ${FUNCNAME[0]} are:"
		echo "--src-id UUID source globus collection's uuid to copy from"
		echo "--base DIR source base path to omit when creating the files on --dst-base"
		echo "--src PATH source directory or file to copy, relative to --base"
		echo "--dst-id UUID destination globus collection's uuid to copy to"
		echo "[--dst-base DIR] destination base path in which the files will be copied (defaults to \$HOME on --dst-id)"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--id) local _SRC_ID="$1"; shift
			>&2 echo "src-id = [${_SRC_ID}]"
			;;
			--base) local _SRC_BASE="$1"; shift
			>&2 echo "base = [${_SRC_BASE}]"
			;;
			--src) local _SRC="$1"; shift
			>&2 echo "src = [${_SRC}]"
			;;
			--dest-id) local _DST_ID="$1"; shift
			>&2 echo "dest-id = [${_DST_ID}]"
			;;
			--dest-base) local _DST_BASE="$1"; shift
			>&2 echo "dest-base = [${_DST_BASE}]"
			;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 3
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done

	local _SRC_BASE=$(realpath -eL "${_SRC_BASE}")

	if [[ -z "${_SRC_ID}" ]] || [[ -z "${_SRC_BASE}" ]] || [[ -z "${_SRC}" ]] || [[ -z "${_DST_ID}" ]]
	then
		>&2 echo "Missing or invalid options"
		>&2 echo "${_HELP}"
		exit 1
	fi

	if [[ ! -z "${_DST_BASE}" ]]
	then
		local _DST_BASE=":${_DST_BASE}"
	fi

	(
		cd "${_SRC_BASE}" && find -L "${_SRC}" \
			-name ".*" -prune -or \
			-type f -printf "'%p' '%p'\n"
	) | globus transfer --preserve-mtime --sync-level mtime --batch - \
		"${_SRC_ID}:${_SRC_BASE}" "${_DST_ID}${_DST_BASE}"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
