#!/bin/bash

function copy_datalad_dataset {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--src) local _SRC="$1"; shift
			echo "src = [${_SRC}]"
			;;
			--dest) local _DEST="$1"; shift
			echo "dest = [${_DEST}]"
			;;
			--super-ds) local _SUPER_DS="$1"; shift
			echo "super-ds = [${_SUPER_DS}]"
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
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			-c | --checksum) local _CHECKSUM="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[-c | --checksum CHECKSUM] checksum to print"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done

	for _file in "$@"
	do
		annex_file=`ls -l -- "${_file}" | grep -o ".git/annex/objects/.*/${_CHECKSUM}.*"`
		if [[ ! -f "${annex_file}" ]]
		then
			continue
		fi
		checksum=`echo "${annex_file}" | xargs basename | grep -oEe"--.*"`
		echo "${checksum:2}  ${_file}"
	done
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
