#!/bin/bash

function exit_on_error_code {
	local _ERR=$?
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--err)
			if [[ ${_ERR} -eq 0 ]]
			then
				_ERR=$1
			fi
			shift
			;;
			-h | --help)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "[--err INT] use this exit code if '\$?' is 0 (optional)"
			>&2 echo "ERROR_MESSAGE error message to print"
			exit 1
			;;
			*) set -- "${_arg}" "$@"; break ;;
		esac
	done

	if [[ ${_ERR} -ne 0 ]]
	then
		>&2 echo "$(tput setaf 1)ERROR$(tput sgr0): $1: ${_ERR}"
		exit ${_ERR}
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
	test_enhanced_getopt

	local _name=$0
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--opts) local _opts="$1"; shift ;;
			--longopts) local _longopts="$1"; shift ;;
			--name) local _name="$1"; shift ;;
			--) break ;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--opts OPTIONS short (one-character) options to be recognized"
			>&2 echo "--longopts LONGOPTIONS long (multi-character) options to be recognized"
			>&2 echo "--name STR name that will be used by the getopt routines when it reports errors"
			exit 1
			;;
		esac
	done

	local _parsed
	! _parsed=`getopt --options="${_opts}" --longoptions="${_longopts}" --name="${_name}" -- "$@"`
	if [[ ${PIPESTATUS[0]} -ne 0 ]]
	then
		exit 2
	fi

	echo "${_parsed}"
}

function init_conda_env {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _name="$1"; shift
			>&2 echo "name = [${_name}]"
			;;
			--prefix) local _prefixroot="$1"; shift
			>&2 echo "prefix = [${_prefixroot}]"
			;;
			--tmp) local _prefixroot="$1"; shift
			>&2 echo "Deprecated --tmp option. Use --prefix instead."
			>&2 echo "tmp = [${_prefixroot}]"
			;;
			--) break ;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR conda env prefix name"
			>&2 echo "--prefix DIR directory to hold the conda prefix"
			exit 1
			;;
		esac
	done

	local _CONDA_ENV=$CONDA_DEFAULT_ENV

	# Configure conda for bash shell
	(conda activate base 2>/dev/null && conda deactivate) || \
		eval "$(conda shell.bash hook)"
	if [[ ! -z ${_CONDA_ENV} ]]
	then
		# Stack previous conda env which gets cleared after
		# `eval "$(conda shell.bash hook)"`
		conda activate ${_CONDA_ENV}
		unset _CONDA_ENV
	fi

	if [[ ! -d "${_prefixroot}/env/${_name}/" ]]
	then
		conda create --prefix "${_prefixroot}/env/${_name}/" --yes --no-default-packages || \
		exit_on_error_code "Failed to create ${_name} conda env"
	fi

	conda activate "${_prefixroot}/env/${_name}/" && \
	exit_on_error_code "Failed to activate ${_name} conda env"

	"$@"
}

function init_venv {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _name="$1"; shift
			>&2 echo "name = [${_name}]"
			;;
			--prefix) local _prefixroot="$1"; shift
			>&2 echo "prefix = [${_prefixroot}]"
			;;
			--tmp) local _prefixroot="$1"; shift
			>&2 echo "Deprecated --tmp option. Use --prefix instead."
			>&2 echo "tmp = [${_prefixroot}]"
			;;
			--) break ;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR venv prefix name. If --name starts" \
				"with cp[0-9]+/, a conda env will be created in \~ with" \
				"a python version of [0-9].[0-9]+"
			>&2 echo "--prefix DIR directory to hold the virtualenv prefix"
			exit 1
			;;
		esac
	done

	py_env="$(echo "${_name}" | grep -Eo "^cp[0-9]+/" | cut -d"/" -f1 || echo "")"
	if [[ ! -z "${py_env}" ]] && [[ ! -z "$(conda env list)" ]] && [[ "$(conda env list | grep "\*" | cut -d" " -f1)" != "${py_env}" ]]
	then
		py_version=${py_env/#cp/}
		py_version=${py_version:0:1}.${py_version:1}
		init_conda_env --name "${py_env}" --prefix ~ --
		if [[ "$(python3 --version | cut -d" " -f2 | cut -d"." -f-2)" != "${py_version}" ]]
		then
			conda install python=${py_version} pip virtualenv || \
			exit_on_error_code "Failed to install python=${py_version} in conda env"
		fi
	fi

	if [[ ! -d "${_prefixroot}/venv/${_name}/" ]]
	then
		mkdir -p "${_prefixroot}/venv/${_name}/" && \
		python3 -m virtualenv --no-download "${_prefixroot}/venv/${_name}/" || \
		exit_on_error_code "Failed to create ${_name} venv"
	fi

	source "${_prefixroot}/venv/${_name}/bin/activate" || \
	exit_on_error_code "Failed to activate ${_name} venv"
	python3 -m pip install --no-index --upgrade pip

	"$@"
}

function unshare_mount {
	if [[ ${EUID} -ne 0 ]]
	then
		unshare -rm ./"${BASH_SOURCE[0]}" unshare_mount "$@" <&0
		exit $?
	fi

	if [[ -z ${_src} ]]
	then
		local _src=${PWD}
	fi
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--src) local _src="$1"; shift
			>&2 echo "src = [${_src}]"
			;;
			--dir) local _dir="$1"; shift
			>&2 echo "dir = [${_dir}]"
			;;
			--cd) local _cd=1
			>&2 echo "cd = [${_cd}]"
			;;
			--) break ;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "[--dir DIR] mount location"
			>&2 echo "[--src DIR] source dir (optional)"
			exit 1
			;;
		esac
	done

	mkdir -p ${_src}
	mkdir -p ${_dir}

	local _src=$(cd "${_src}" && pwd -P)
	local _dir=$(cd "${_dir}" && pwd -P)

	mount -o bind ${_src} ${_dir}
	exit_on_error_code "Could not mount directory"

	if [[ ! ${_cd} -eq 0 ]]
	then
		cd ${_dir}
	fi

	unshare -U ${SHELL} -s "$@" <&0
}

# function unshare_mount {
# 	if [[ ${EUID} -ne 0 ]]
# 	then
# 		unshare -rm ./"${BASH_SOURCE[0]}" unshare_mount "$@" <&0
# 		exit $?
# 	fi
#
# 	if [[ -z ${_src} ]]
# 	then
# 		local _src=${PWD}
# 	fi
# 	if [[ -z ${_dir} ]]
# 	then
# 		local _dir=${PWD}
# 	fi
# 	while [[ $# -gt 0 ]]
# 	do
# 		local _arg="$1"; shift
# 		case "${_arg}" in
# 			--src) local _src="$1"; shift
# 			>&2 echo "src = [${_src}]"
# 			;;
# 			--upper) local _upper="$1"; shift
# 			>&2 echo "upper = [${_upper}]"
# 			;;
# 			--dir) local _dir="$1"; shift
# 			>&2 echo "dir = [${_dir}]"
# 			;;
# 			--wd) local _wd="$1"; shift
# 			>&2 echo "wd = [${_wd}]"
# 			;;
# 			--cd) local _cd=1
# 			>&2 echo "cd = [${_cd}]"
# 			;;
# 	                --) break ;;
# 			-h | --help | *)
# 			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
# 			then
# 				>&2 echo "Unknown option [${_arg}]"
# 			fi
# 			>&2 echo "Options for ${FUNCNAME[0]} are:"
# 			>&2 echo "[--upper DIR] upper mount overlay"
# 			>&2 echo "[--wd DIR] overlay working directory"
# 			>&2 echo "[--src DIR] lower mount overlay (optional)"
# 			>&2 echo "[--dir DIR] mount location (optional)"
# 			exit 1
# 			;;
# 		esac
# 	done
#
# 	mkdir -p ${_src}
# 	mkdir -p ${_upper}
# 	mkdir -p ${_wd}
# 	mkdir -p ${_dir}
#
# 	local _src=$(cd "${_src}" && pwd -P) || echo "${_src}"
# 	local _upper=$(cd "${_upper}" && pwd -P)
# 	local _wd=$(cd "${_wd}" && pwd -P)
# 	local _dir=$(cd "${_dir}" && pwd -P)
#
# 	mount -t overlay overlay -o lowerdir="${_src}",upperdir="${_upper}",workdir="${_wd}" "${_dir}"
# 	exit_on_error_code "Could not mount overlay"
#
# 	if [[ ! ${_cd} -eq 0 ]]
# 	then
# 		cd ${_dir}
# 	fi
#
# 	unshare -U ${SHELL} -s "$@" <&0
# }

if [[ ! -z "$@" ]]
then
	"$@"
fi
