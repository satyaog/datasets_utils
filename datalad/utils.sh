#!/bin/bash

pushd `dirname "${BASH_SOURCE[0]}"` >/dev/null
_SCRIPT_DIR=`pwd -P`
cd ..
_DS_UTILS_DIR=`pwd -P`
popd >/dev/null

function copy_dataset {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--src) local _SRC="$1"; shift
			>&2 echo "src = [${_SRC}]"
			;;
			--dest) local _DEST="$1"; shift
			>&2 echo "dest = [${_DEST}]"
			;;
			--super-ds) local _SUPER_DS="$1"; shift
			>&2 echo "super-ds = [${_SUPER_DS}]"
			;;
			-h | --help | *)
			if [[ "${_arg}" != "-h" ]] && [[ "${_arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${_arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--src {DIR|DATASET} source dataset directory or name"
			>&2 echo "--dest DIR ddestination directory"
			>&2 echo "--super-ds DIR super dataset directory"
			exit 1
			;;
		esac
	done

	if [[ ! -d "${_SRC}" ]]
	then
		local _SRC=${_SUPER_DS}/${_SRC}
	fi

	mkdir -p ${_DEST}

	! datalad install -s ${_SRC}/ ${_DEST}/
	git -C ${_DEST} config remote.cache-0fea6a.url ${_SUPER_DS}/.annex-cache
	git -C ${_DEST} config remote.cache-0fea6a.fetch \
		+refs/heads/empty_branch:refs/remotes/cache-0fea6a/empty_branch
	git -C ${_DEST} config remote.cache-0fea6a.annex-speculate-present true
	git -C ${_DEST} config remote.cache-0fea6a.annex-pull false
	git -C ${_DEST} config remote.cache-0fea6a.annex-push false
	(cd ${_DEST}/ && \
	 git-annex get --fast --from cache-0fea6a || \
	 git-annex get --fast --from origin || \
	 git-annex get --fast) || \
	exit_on_error_code "Failed to copy dataset ${_SRC}"
}

function print_annex_checksum {
	local _CHECKSUM=MD5
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-c | --checksum) local _CHECKSUM="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[-c | --checksum CHECKSUM] checksum to print (default: MD5)"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	for _file in "$@"
	do
		local _annex_file=`ls -l -- "${_file}" | grep -o ".git/annex/objects/.*/${_CHECKSUM}.*"`
		if [[ ! -f "${_annex_file}" ]]
		then
			continue
		fi
		local _checksum=`echo "${_annex_file}" | xargs basename`
		local _checksum=${_checksum##*--}
		echo "${_checksum%%.*}  ${_file}"
	done
}

function subdatasets {
	local _VAR=0
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--var) local _VAR=1 ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--var also list datasets variants"
			>&2 echo "then following --"
			datalad subdatasets --help
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ${_VAR} != 0 ]]
	then
		datalad subdatasets $@ | grep -o ": .* (dataset)" | grep -o " .* " | grep -o "[^ ]*" | \
		while read subds
		do
			echo ${subds}
			for _d in "${subds}.var"/*
			do
				if [[ -d "$_d" ]]
				then
					echo $_d
				fi
			done
		done
	else
		datalad subdatasets $@ | grep -o ": .* (dataset)" | grep -o " .* " | grep -o "[^ ]*"
	fi
}

function list {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[-d | --dataset PATH] dataset location"
			git-annex list --help >&2
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z "${_DATASET}" ]]
	then
		pushd "${_DATASET}" >/dev/null || exit 1
	fi

	git-annex list "$@" | grep -o " .*" | grep -Eo "[^ ]+.*"

	if [[ ! -z "${_DATASET}" ]]
	then
		popd >/dev/null
	fi
}

function validate {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[-d | --dataset PATH] dataset location"
			print_annex_checksum --help
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z "${_DATASET}" ]]
	then
		pushd "${_DATASET}" >/dev/null || exit 1
	fi

	local _exit_code=0

	list -- --fast | while read f
	do
		[[ ! -z "${_DATASET}" ]] && echo -n "${_DATASET}/"
		echo -n "${f} ... "
		if [[ "$(print_annex_checksum -c MD5 -- "${f}")" == "$(md5sum "${f}")" ]]
		then
			echo "ok"
		else
			echo "failed"
			local _exit_code=1
		fi
	done

	if [[ ! -z "${_DATASET}" ]]
	then
		popd >/dev/null
	fi

	exit ${_exit_code}
}

function create_ds {
	local -
	set -o errexit -o pipefail

	local _SUPER_DS=/network/datasets
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-n | --name STR] dataset name"
		echo "[--super-ds PATH] super dataset location (default: ${_SUPER_DS})"
		echo "[--tmp PATH] temporary directory to work on the dataset (default: '')"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-n | --name) local _NAME="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$1"; shift ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	>&2 _create_dataset_or_weights -n "${_NAME}" --super-ds "${_SUPER_DS}" --tmp "${_TMP_DIR}"

	pwd -P
}

function create_weights {
	local -
	set -o errexit -o pipefail

	local _SUPER_DS=/network/datasets/.weights
	local _EXPOSED_SUPER_DS=/network/weights
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-n | --name STR] dataset name"
		echo "[--super-ds PATH] super dataset location (default: ${_SUPER_DS})"
		echo "[--exposed-super-ds PATH] public facing super dataset location (default: ${_EXPOSED_SUPER_DS})"
		echo "[--tmp PATH] temporary directory to work on the dataset (default: '')"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-n | --name) local _NAME="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--exposed-super-ds) local _EXPOSED_SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$1"; shift ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	>&2 _create_dataset_or_weights -n "${_NAME}" --super-ds "${_SUPER_DS}" --exposed-super-ds "${_EXPOSED_SUPER_DS}" --tmp "${_TMP_DIR}"

	pwd -P
}

function create_var_ds {
	local -
	set -o errexit -o pipefail

	local _SUPER_DS=/network/datasets
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-d | --dataset PATH] dataset path from which --name can be derived if empty. (default: '${_DATASET}')"
		echo "[-n | --name STR] dataset name (default: '${_NAME}')"
		echo "[-v | --var STR] dataset variation name, i.e. 'VAR' in 'NAME_VAR' (default: '${_VAR}')"
		echo "[--super-ds PATH] super dataset location (default: '${_SUPER_DS}')"
		echo "[--tmp PATH] temporary directory to work on the dataset (default: '${_TMP_DIR}')"
		# echo "[--force] Do not ask to execute changes (default: ${_FORCE})"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			-n | --name) local _NAME="$1"; shift ;;
			-v | --var) local _VAR="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$(realpath "$1")"; shift ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	>&2 _create_variation_dataset_or_weights -d "${_DATASET}" -n "${_NAME}" -v "${_VAR}" --super-ds "${_SUPER_DS}" --tmp "${_TMP_DIR}"

	pwd -P
}

function create_var_weights {
	local -
	set -o errexit -o pipefail

	local _SUPER_DS=/network/datasets/.weights
	local _EXPOSED_SUPER_DS=/network/weights
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-d | --dataset PATH] dataset path from which --name can be derived if empty. (default: '${_DATASET}')"
		echo "[-n | --name STR] dataset name (default: '${_NAME}')"
		echo "[-v | --var STR] dataset variation name, i.e. 'VAR' in 'NAME_VAR' (default: '${_VAR}')"
		echo "[--super-ds PATH] super dataset location (default: '${_SUPER_DS}')"
		echo "[--exposed-super-ds PATH] public facing super dataset location (default: ${_EXPOSED_SUPER_DS})"
		echo "[--tmp PATH] temporary directory to work on the dataset (default: '${_TMP_DIR}')"
		# echo "[--force] Do not ask to execute changes (default: ${_FORCE})"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			-n | --name) local _NAME="$1"; shift ;;
			-v | --var) local _VAR="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--exposed-super-ds) local _EXPOSED_SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$(realpath "$1")"; shift ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	>&2 _create_variation_dataset_or_weights -d "${_DATASET}" -n "${_NAME}" -v "${_VAR}" --super-ds "${_SUPER_DS}" --exposed-super-ds "${_EXPOSED_SUPER_DS}" --tmp "${_TMP_DIR}"

	pwd -P
}

function finish_ds {
	local -
	set -o errexit -o pipefail

	local _SUPER_DS=/network/datasets
	# local _FORCE=0
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-d | --dataset PATH] dataset path from which --name and --var can be derived if empty. (default: '${_DATASET}')"
		echo "[-n | --name STR] dataset name (default: '${_NAME}')"
		echo "[-v | --var STR] dataset variation name, i.e. 'VAR' in 'NAME_VAR' (default: '${_VAR}')"
		echo "[--super-ds PATH] super dataset location (default: '${_SUPER_DS}')"
		echo "[--tmp PATH] temporary directory to work on the dataset (default: '${_TMP_DIR}')"
		# echo "[--force] Do not ask to execute changes (default: ${_FORCE})"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			-n | --name) local _NAME="$1"; shift ;;
			-v | --var) local _VAR="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$1"; shift ;;
			# --force) local _FORCE=1 ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	>&2 _finish_dataset_or_weights -d "${_DATASET}" -n "${_NAME}" -v "${_VAR}" --super-ds "${_SUPER_DS}" --tmp "${_TMP_DIR}"
}

function finish_weights {
	local -
	set -o errexit -o pipefail

	local _SUPER_DS=/network/datasets/.weights
	# local _FORCE=0
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-d | --dataset PATH] dataset path from which --name and --var can be derived if empty. (default: '${_DATASET}')"
		echo "[-n | --name STR] dataset name (default: '${_NAME}')"
		echo "[-v | --var STR] dataset variation name, i.e. 'VAR' in 'NAME_VAR' (default: '${_VAR}')"
		echo "[--super-ds PATH] super dataset location (default: '${_SUPER_DS}')"
		echo "[--tmp PATH] temporary directory to work on the dataset (default: '${_TMP_DIR}')"
		# echo "[--force] Do not ask to execute changes (default: ${_FORCE})"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			-n | --name) local _NAME="$1"; shift ;;
			-v | --var) local _VAR="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$1"; shift ;;
			# --force) local _FORCE=1 ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	>&2 _finish_dataset_or_weights -d "${_DATASET}" -n "${_NAME}" -v "${_VAR}" --super-ds "${_SUPER_DS}" --tmp "${_TMP_DIR}"
}

function fix_remote_log {
	local -
	set -o errexit -o pipefail

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	pushd "${_DATASET}"

	mkdir -p .tmp
	git worktree add .tmp/remote git-annex
	pushd .tmp/remote

	touch remote.log
	git add remote.log

	[[ -z "$(git diff --cached -- remote.log)" ]] || git commit -m "Fix missing remote.log" --no-verify -- remote.log

	popd

	git worktree remove .tmp/remote
}

function fix_dataset_path {
	local -
	set -o errexit -o pipefail

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$1"; shift ;;
			--ds-prefix) local _DS_PREFIX="$1"; shift ;;
			--ds-prefix-corrected) local _DS_PREFIX_CORRECTED="$1"; shift ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	[[ "$(realpath --relative-to "${_DS_PREFIX}" "${_DS_PREFIX_CORRECTED}")" != "." ]] || return 0

	pushd "${_DATASET}"

	mkdir -p .tmp
	git worktree add .tmp/uuid git-annex
	pushd .tmp/uuid

	while read l
	do
		echo "${l/$_DS_PREFIX/$_DS_PREFIX_CORRECTED}"
	done <uuid.log | sort -u >_uuid.log
	mv _uuid.log uuid.log
	touch remote.log
	git add uuid.log remote.log

	git commit -m "Fix dataset path" --no-verify -- uuid.log remote.log

	popd

	git worktree remove .tmp/uuid
}

function offload_data {
	local -
	set -o errexit -o pipefail

	local _DATASET=
	local _DIR=
	local _SUPER_DS=
	local _HELP=$(
		echo "Options for $(basename "$0") are:"
		echo "[-d | --dataset PATH] dataset path"
		echo "[--data PATH] relative data path"
		echo "[--super-ds PATH] super dataset location"
	)

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$(realpath "${1%/}")"; shift ;;
			--data) local _DATA="${1%/}"; shift ;;
			--super-ds) local _SUPER_DS="${1%/}"; shift ;;
			-h | --help)
			>&2 echo "${_HELP}"
			exit 1
			;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	[[ -d "${_DATASET}" ]] || \
	${_DS_UTILS_DIR}/utils.sh exit_on_error_code --err $? \
	  "Invalid --dataset dir. Got [${_DATASET}]"

	[[ -d "${_DATASET}/${_DATA}" ]] && [[ ! -L "${_DATASET}/${_DATA}" ]] && \
		[[ "$(realpath --relative-to "${_DATASET}" "${_DATASET}/${_DATA}")" != "." ]] || \
	${_DS_UTILS_DIR}/utils.sh exit_on_error_code --err $? \
	  "Invalid --data dir. Got [${_DATA}]"

	if [[ "${_SUPER_DS}" == "/network/datasets" ]] && \
		[[ "$(realpath --relative-to "/network/datasets" "${_DATASET}")" != ".."* ]] && \
		[[ "$(realpath --relative-to "/network/datasets" "${_DATASET}")" != ".weights"* ]]
	then
		# Pass
		echo >/dev/null
	elif [[ "${_SUPER_DS}" == "/network/datasets/.weights" ]] && \
		[[ "$(realpath --relative-to "/network/datasets/.weights" "${_DATASET}")" != ".."* ]]
	then
		# Pass
		echo >/dev/null
	else
		(exit 1)
	fi || \
	${_DS_UTILS_DIR}/utils.sh exit_on_error_code --err $? \
	  "Invalid --super-ds dir. Got [${_SUPER_DS}]"

	local _DATASET=$(realpath --relative-to "${_SUPER_DS}" "${_DATASET}")
	local _STAGED_DATASET=${_SUPER_DS}/staged_for_removal/${_DATASET}

	echo mkdir -p "$(dirname "${_STAGED_DATASET}/${_DATA}")"
	mkdir -p "$(dirname "${_STAGED_DATASET}/${_DATA}")"

	echo mv -T "${_SUPER_DS}/${_DATASET}/${_DATA}" "${_STAGED_DATASET}/${_DATA}"
	mv -T "${_SUPER_DS}/${_DATASET}/${_DATA}" "${_STAGED_DATASET}/${_DATA}"

	echo ln -sT "${_STAGED_DATASET}/${_DATA}" "${_SUPER_DS}/${_DATASET}/${_DATA}"
	ln -sT "${_STAGED_DATASET}/${_DATA}" "${_SUPER_DS}/${_DATASET}/${_DATA}"

	! git update-index --assume-unchanged "${_SUPER_DS}/${_DATASET}/${_DATA}"
}

function _create_dataset_or_weights {
	local _EXPOSED_SUPER_DS=

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-n | --name) local _NAME="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--exposed-super-ds) local _EXPOSED_SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$(realpath "$1")"; shift ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ -z "${_EXPOSED_SUPER_DS}" ]]
	then
		local _EXPOSED_SUPER_DS="${_SUPER_DS}"
	fi

	pushd "${_SUPER_DS}"

	[[ ! "${_NAME}" == *"_"* ]] || \
	$(${_DS_UTILS_DIR}/utils.sh exit_on_error_code --err $? \
	  "Only a variation dataset can include '_' in its name. Dataset name: [${_NAME}]")

	datalad create -d . "${_NAME}"

	if [[ ! -z "${_TMP_DIR}" ]]
	then
		[[ -d "${_TMP_DIR}" ]]
		mv "${_NAME}" "${_TMP_DIR}"
		cd "${_TMP_DIR}"
	fi

	cd "${_NAME}"

	fix_dataset_path -d . --ds-prefix "${_SUPER_DS}" --ds-prefix-corrected "${_EXPOSED_SUPER_DS}"

	# git config annex.hardlink true # not applicable on bgfs
	git fetch -v dataset_template
	git merge --allow-unrelated-histories \
		--strategy recursive --strategy-option theirs \
		--no-edit dataset_template/master

	pwd -P
}

function _create_variation_dataset_or_weights {
	local _EXPOSED_SUPER_DS=

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$(realpath "$1")"; shift ;;
			-n | --name) local _NAME="$1"; shift ;;
			-v | --var) local _VAR="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--exposed-super-ds) local _EXPOSED_SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$(realpath "$1")"; shift ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z "${_DATASET}" ]] && [[ -z "${_NAME}" ]]
	then
		local _NAME="$(basename "${_DATASET}")"
	fi

	[[ "$(realpath --relative-to "${_SUPER_DS}" "${_SUPER_DS}/${_NAME}")" != "." ]]
	[[ ! -z "${_VAR}" ]]

	if [[ -z "${_EXPOSED_SUPER_DS}" ]]
	then
		local _EXPOSED_SUPER_DS="${_SUPER_DS}"
	fi

	>&2 pushd "${_SUPER_DS}/${_NAME}"

	>&2 fix_remote_log -d .

	mkdir -p "${PWD}".var/
	>&2 pushd "${PWD}".var/
	>&2 datalad install -s "$(dirs +1)" "$(basename $(dirs +1))_${_VAR}"

	if [[ ! -z "${_TMP_DIR}" ]]
	then
		[[ -d "${_TMP_DIR}" ]]
		mv "$(basename $(dirs +1))_${_VAR}" "${_TMP_DIR}"
		cd "${_TMP_DIR}"
	fi

	cd "$(basename $(dirs +1))_${_VAR}/"

	>&2 fix_dataset_path -d . --ds-prefix "${_SUPER_DS}" --ds-prefix-corrected "${_EXPOSED_SUPER_DS}"

	# git config annex.hardlink true # non-applicable sur bgfs
	>&2 git checkout -b "var/${_VAR}"
	>&2 git branch -d master
}

function _finish_dataset_or_weights {
	# local _FORCE=0

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-d | --dataset) local _DATASET="$(realpath "$1")"; shift ;;
			-n | --name) local _NAME="$1"; shift ;;
			-v | --var) local _VAR="$1"; shift ;;
			--super-ds) local _SUPER_DS="$1"; shift ;;
			--tmp) local _TMP_DIR="$(realpath "$1")"; shift ;;
			# --force) local _FORCE=1 ;;
			*) >&2 echo "Unknown option [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z "${_DATASET}" ]] && [[ -z "${_NAME}" ]] && [[ -z "${_VAR}" ]]
	then
		local _NAME="$(basename "${_DATASET}")"
		if [[ "var/${_NAME#*_}" == "$(git rev-parse --abbrev-ref HEAD)" ]]
		then
			local _VAR="${_NAME#*_}"
			local _NAME="${_NAME%%_*}"
		fi
	fi

	[[ "$(realpath --relative-to "${_SUPER_DS}" "${_SUPER_DS}/${_NAME}")" != "." ]]

	if [[ ! -z "${_VAR}" ]]
	then
		local _VAR_PREFIX="${_NAME}.var/"
		local _NAME="${_NAME}_${_VAR}"
	fi

	pushd "${_SUPER_DS}"
	if [[ ! -z "${_TMP_DIR}" ]]
	then
		[[ -d "${_TMP_DIR}" ]]
		cd "${_TMP_DIR}"
	fi

	cd "${_NAME}"

	git-annex unused --used-refspec +HEAD | tee /dev/tty | grep NUMBER >/dev/null || local _NO_UNUSED=1
	if [[ -z "${_NO_UNUSED}" ]]
	then
		echo -n "Entre NUMBER to be used in the command 'git-annex dropunused NUMBER': "
		read indices
		[[ -z "${indices}" ]] || git-annex dropunused --force "${indices}"
	fi

	[[ ! -e .tmp/ ]] || rm -r .tmp/

	if [[ ! -z "${_TMP_DIR}" ]]
	then
		mkdir -p "${_SUPER_DS}/${_VAR_PREFIX}"
		cp -RT "$PWD" "${_SUPER_DS}/${_VAR_PREFIX}.${_NAME}" && \
			diff -r "$PWD" "${_SUPER_DS}/${_VAR_PREFIX}.${_NAME}" && \
			mv "${_SUPER_DS}/${_VAR_PREFIX}.${_NAME}" "${_SUPER_DS}/${_VAR_PREFIX}${_NAME}"
	fi

	chown -R :2001 "${_SUPER_DS}/${_VAR_PREFIX}${_NAME}"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
