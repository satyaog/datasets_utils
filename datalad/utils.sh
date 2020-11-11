#!/bin/bash

function copy_datalad_dataset {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--src) SRC="$1"; shift
			echo "src = [${SRC}]"
			;;
			--dest) DEST="$1"; shift
			echo "dest = [${DEST}]"
			;;
			--super-ds) SUPER_DS="$1"; shift
			echo "super-ds = [${SUPER_DS}]"
			;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--src {DIR|DATASET} source dataset directory or name"
			>&2 echo "--dest DIR ddestination directory"
			>&2 echo "--super-ds DIR super dataset directory"
			exit 1
			;;
		esac
	done

	if [[ ! -d "${SRC}" ]]
	then
		SRC=${SUPER_DS}/${SRC}
	fi

	mkdir -p ${DEST}

	! datalad install -s ${SRC}/ ${DEST}/
	(cd ${DEST}/ && \
	 link_cache_0fea6a ${SUPER_DS}/.annex-cache && \
	 git-annex get --fast --from cache-0fea6a || \
	 git-annex get --fast) || \
	exit_on_error_code "Failed to copy dataset ${SRC}"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
