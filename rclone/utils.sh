#!/bin/bash

function rclone_copy {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--remote) REMOTE="$1"; shift
			echo "remote = [${REMOTE}]"
			;;
			-d | --directory) GDRIVE_DIR_ID="$1"; shift
			echo "directory = [${GDRIVE_DIR_ID}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "-d | --directory GDRIVE_DIR_ID Google Drive root directory id"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	for src_w_file in "$@"
	do
		rclone copy --progress --create-empty-src-dirs --copy-links \
			--drive-root-folder-id=${GDRIVE_DIR_ID} ${REMOTE}:${src} ${file}
	done
}
