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

function get_options {
	set +o | cut -d' ' -f2- | while read set_option
	do
		echo "${set_option}"
	done
}

function set_options {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-o) set -o "$1"; shift ;;
			+o) set +o "$1"; shift ;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "-o OPTION [-o OPTION,...] option to be 'set -o'"
			>&2 echo "+o OPTION [+o OPTION,...] option to be 'set +o'"
			exit 1
			;;
		esac
	done
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

	local _opts=
	local _longopts=
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
	local _name=
	local _prefixroot=

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
	local _name=
	local _prefixroot=${HOME}
	local _py=
	local _script=

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
			--py) local _py="$1"; shift
			>&2 echo "py = [${_py}]"
			;;
			--script) local _script="$1"; shift
			>&2 echo "script = [${_script}]"
			;;
			--tmp) local _prefixroot="$1"; shift
			>&2 echo "Deprecated --tmp option. Use --prefix instead."
			>&2 echo "prefix = [${_prefixroot}]"
			;;
			--) break ;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR venv prefix name. If --name starts" \
				"with cp[0-9]+/, the venv will use a hatch" \
				"managed python binary with a python version" \
				"of [0-9].[0-9]+"
			>&2 echo "--prefix DIR directory to hold the virtualenv" \
				"prefix (default: '${HOME}')"
			>&2 echo "--py [0-9].[0-9]+ python version to prefer" \
				"for the script. The binary will be managed by" \
				"hatch"
			>&2 echo "--script FILE script path from which --name" \
				"and --prefix will be derived if empty"
			exit 1
			;;
		esac
	done

	install_hatch

	if [[ -z "${_name}" ]] && [[ ! -z "${_script}" ]]
	then
		local _prefix=$(dirname "${_script}")
		local _name=$(basename "${_script}")
		local _name=${_name%.*}
		local _name=$(basename "${_prefix}")/${_name}
		local _py_v=$(echo "$(basename "${_prefix}")/" | grep -Eo "^cp[0-9]+/" | cut -d"/" -f1 || echo "${_py}")

	else
		local _script="${_prefixroot}/venv/${_name}.py"
		local _prefix=$(dirname "${_script}")
		local _py_v="$(echo "${_name}" | grep -Eo "^cp[0-9]+/" | cut -d"/" -f1 || echo "${_py}")"
	fi

	if [[ ! -z "${_py_v}" ]]
	then
		_py=$_py_v
	fi

	if [[ ! -z "${_py}" ]]
	then
		local _PYTHON_VERSION=${_py/#cp/}
		local _PYTHON_VERSION=${_PYTHON_VERSION/./}
		local _PYTHON_VERSION=${_PYTHON_VERSION:0:1}.${_PYTHON_VERSION:1}

		>&2 hatch python install "${_PYTHON_VERSION}"
		export PATH="$(hatch python find --parent "${_PYTHON_VERSION}"):$PATH"
	fi

	if [[ -z "${_name}" ]] || [[ -z "${_prefix}" ]] || [[ -z "${_script}" ]]
	then
		exit_on_error_code --err 1 "--name=${_name} or --prefix=${_prefix} or --script=${_script} are empty"
	fi

	mkdir -p "${_prefix}"

	# Basic check to avoid a bit race conditions issues
	if [[ ! -e "${_script}" ]]
	then
		touch "${_script}"

		echo -n "
# /// script
# requires-python = '>=${_PYTHON_VERSION}'
# [tool.hatch]
# python = '${_PYTHON_VERSION}'
# python-sources = ['external', 'internal']
# installer = 'uv'
# path = '../$(basename "${_name}")'
# ///

import subprocess
import sys

print(sys.executable, file=sys.stderr)
if sys.argv[1:]:
    subprocess.run(sys.argv[1:], check=True)" \
		>"${_script}"
	fi

	while read envvar
	do
		if [[ "$envvar" != *"="* ]]
		then
			continue
		fi
		export "$(echo "$envvar" | cut -d"=" -f1)"="$(echo "$envvar" | cut -d"=" -f2-)" || echo -n
	done < <(hatch run "${_script}" bash -c printenv)

	exit_on_error_code "Failed to activate ${_name} venv"

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
	local _dir=
	local _cd=
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

function install_hatch {
	>&2 which hatch 2>/dev/null && >&2 hatch --version 2>/dev/null || export PATH="$PATH:$HOME/.local/bin"
	>&2 which hatch && >&2 hatch --version && return

	local _tmp_dir=$(mktemp -d)
	>&2 wget "https://github.com/pypa/hatch/releases/latest/download/hatch-x86_64-unknown-linux-gnu.tar.gz" -O "${_tmp_dir}"/hatch-x86_64-unknown-linux-gnu.tar.gz

	mkdir -p ~/.local/bin
	>&2 tar -xf "${_tmp_dir}"/hatch-x86_64-unknown-linux-gnu.tar.gz --directory ~/.local/bin/
	>&2 ~/.local/bin/hatch --version

	>&2 which hatch 2>/dev/null && >&2 hatch --version 2>/dev/null || export PATH="$PATH:$HOME/.local/bin"
	>&2 which hatch && >&2 hatch --version

	echo -e "Add '\$HOME/.local/bin' to your ~/.bashrc or ~/.profile and reload your terminal:
	echo 'export PATH=\"\$PATH:\$HOME/.local/bin\"' >>~/.bashrc
	echo 'export PATH=\"\$PATH:\$HOME/.local/bin\"' >>~/.profile"
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
