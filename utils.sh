#!/bin/bash

function exit_on_error_code {
	ERR=$?
	if [[ ${ERR} -ne 0 ]]
	then
		>&2 echo "$(tput setaf 1)ERROR$(tput sgr0): $1: ${ERR}"
		exit ${ERR}
	fi
}

function init_venv {
	while [[ $# -gt 0 ]]
	do
		arg=$1
		shift # past argument
		case ${arg} in
			--name) NAME="$1"; shift # past value
			echo "name = [${NAME}]"
			;;
			--tmp) TMPDIR="$1"; shift # past value
			echo "tmp = [${TMPDIR}]"
			;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--name NAME venv prefix name"
			>&2 echo "--tmp DIR tmp dir to hold the virtualenv prefix"
			exit 1
			;;
		esac
	done

	if [[ -z "${NAME}" ]]
	then
		>&2 echo "--name NAME venv prefix name"
		>&2 echo "--tmp DIR tmp dir to hold the virtualenv prefix"
		>&2 echo "Missing --name and/or --tmp options"
		exit 1
	fi

	if [[ ! -d "${TMPDIR}/venv/${NAME}/" ]]
	then
		mkdir -p "${TMPDIR}/venv/${NAME}/" && \
		virtualenv --no-download "${TMPDIR}/venv/${NAME}/" || \
		exit_on_error_code "Failed to create ${NAME} venv"
	fi

	source "${TMPDIR}/venv/${NAME}/bin/activate" || \
	exit_on_error_code "Failed to activate ${NAME} venv"
	python -m pip install --no-index --upgrade pip
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
