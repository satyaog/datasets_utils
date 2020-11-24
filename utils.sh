#!/bin/bash

function exit_on_error_code {
	ERR=$?
	if [[ ${ERR} -ne 0 ]]
	then
		>&2 echo "$(tput setaf 1)ERROR$(tput sgr0): $1: ${ERR}"
		exit ${ERR}
	fi
}

function test_enhanced_getopt {
	! getopt --test > /dev/null
	if [[ ${PIPESTATUS[0]} -ne 4 ]]
	then
		>&2 echo "enhanced getopt is not available in this environment"
		exit 1
	fi
}

function enhanced_getopt {
	NAME=$0
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--options) OPTIONS="$1"; shift ;;
			--longoptions) LONGOPTIONS="$1"; shift ;;
			--name) NAME="$1"; shift ;;
			--) break ;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--options OPTIONS The short (one-character) options to be recognized"
			>&2 echo "--longoptions LONGOPTIONS The long (multi-character) options to be recognized"
			>&2 echo "--name NAME name that will be used by the getopt routines when it reports errors"
			exit 1
			;;
		esac
	done

	PARSED=`getopt --options="${OPTIONS}" --longoptions="${LONGOPTIONS}" --name="${NAME}" -- "$@"`
	if [[ ${PIPESTATUS[0]} -ne 0 ]]
	then
		exit 2
	fi

	echo "${PARSED}"
}

function init_conda_env {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--name) NAME="$1"; shift
			echo "name = [${NAME}]"
			;;
			--tmp) TMPDIR="$1"; shift
			echo "tmp = [${TMPDIR}]"
			;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--name NAME conda env prefix name"
			>&2 echo "--tmp DIR tmp dir to hold the conda prefix"
			exit 1
			;;
		esac
	done

	# Configure conda for bash shell
	eval "$(conda shell.bash hook)"

	if [[ ! -d "${TMPDIR}/env/${NAME}/" ]]
	then
		conda create --prefix "${TMPDIR}/env/${NAME}/" --yes --no-default-packages || \
		exit_on_error_code "Failed to create ${NAME} conda env"
	fi

	conda activate "${TMPDIR}/env/${NAME}/" && \
	exit_on_error_code "Failed to activate ${NAME} conda env"
}

function init_venv {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--name) NAME="$1"; shift
			echo "name = [${NAME}]"
			;;
			--tmp) TMPDIR="$1"; shift
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

	if [[ ! -d "${TMPDIR}/venv/${NAME}/" ]]
	then
		mkdir -p "${TMPDIR}/venv/${NAME}/" && \
		virtualenv --no-download "${TMPDIR}/venv/${NAME}/" || \
		exit_on_error_code "Failed to create ${NAME} venv"
	fi

	source "${TMPDIR}/venv/${NAME}/bin/activate" || \
	exit_on_error_code "Failed to activate ${NAME} venv"
	python3 -m pip install --no-index --upgrade pip
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
