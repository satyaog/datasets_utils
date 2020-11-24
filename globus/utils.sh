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

	if [[ -e ./globusconnectpersonal-*/globusconnectpersonal ]]
	then
		./globusconnectpersonal-*/globusconnectpersonal -setup $setup_key
	else
		globusconnectpersonal -setup $setup_key
	fi
}
