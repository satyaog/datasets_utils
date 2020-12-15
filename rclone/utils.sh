#!/bin/bash

function rclone_copy {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--remote) REMOTE="$1"; shift
			echo "remote = [${REMOTE}]"
			;;
			--root) GDRIVE_DIR_ID="$1"; shift
			echo "root = [${GDRIVE_DIR_ID}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--root GDRIVE_DIR_ID Google Drive root directory id"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z ${REMOTE} ]] && [[ ${REMOTE: -1} != ':' ]]
	then
		REMOTE="${REMOTE}:"
	fi

	for src_w_dest in "$@"
	do
		src_w_dest=(${src_w_dest[@]})
		src=${src_w_dest[0]}
		dest=${src_w_dest[1]}
		rclone copy --progress --create-empty-src-dirs --copy-links \
			--drive-root-folder-id=${GDRIVE_DIR_ID} ${REMOTE}${src} ${dest}
	done
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
