#!/bin/bash

function add_endpoint {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--name) NAME="$1"; shift
			echo "name = [${NAME}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--name NAME endpoint name"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	# Install Globus Connect Personal for Linux: https://docs.globus.org/how-to/globus-connect-personal-linux/#globus-connect-personal-cli
	globus endpoint create --personal ${NAME}

	# read -p "Paste the endpoint id : " endpoint
	read -p "Paste the setup key : " setup_key

	GLOBUS_PERSONAL=(`which globusconnectpersonal` globusconnectpersonal-*/globusconnectpersonal)
	GLOBUS_PERSONAL=${GLOBUS_PERSONAL[-1]}

	./${GLOBUS_PERSONAL} -setup $setup_key
}

function start_endpoint {
	RW=0
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--dir) DIR="$1"; shift
			echo "dir = [${DIR}]"
			;;
			--rw) RW=1; shift
			echo "rw = [${RW}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--dir DIR directory accessible by the endpoint"
			>&2 echo "[--rw] read-write (optional)"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	if [[ ! ${RW} -eq 0 ]]
	then
		DIR=rw${DIR#rw}/
	else
		DIR=r${DIR#r}/
	fi

	GLOBUS_PERSONAL=(`which globusconnectpersonal` globusconnectpersonal-*/globusconnectpersonal)
	GLOBUS_PERSONAL=${GLOBUS_PERSONAL[-1]}

	./${GLOBUS_PERSONAL} -start -restrict-paths ${DIR}
}
