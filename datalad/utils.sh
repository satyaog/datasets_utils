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
	git -C ${DEST} config remote.cache-0fea6a.url ${SUPER_DS}/.annex-cache
	git -C ${DEST} config remote.cache-0fea6a.fetch \
		+refs/heads/empty_branch:refs/remotes/cache-0fea6a/empty_branch
	git -C ${DEST} config remote.cache-0fea6a.annex-speculate-present true
	git -C ${DEST} config remote.cache-0fea6a.annex-pull false
	git -C ${DEST} config remote.cache-0fea6a.annex-push false
	(cd ${DEST}/ && \
	 git-annex get --fast --from cache-0fea6a || \
	 git-annex get --fast --from origin || \
	 git-annex get --fast) || \
	exit_on_error_code "Failed to copy dataset ${SRC}"
}

function print_annex_checksum {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			-c | --checksum) CHECKSUM="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[-c | --checksum CHECKSUM] checksum to print"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	for file in "$@"
	do
		annex_file=`ls -l -- "${file}" | grep -o ".git/annex/objects/.*/${CHECKSUM}.*"`
		if [[ ! -f "${annex_file}" ]]
		then
			continue
		fi
		checksum=`echo "${annex_file%.*}" | xargs basename | grep -oEe"--.*"`
		echo "${checksum:2}  ${file}"
	done
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
