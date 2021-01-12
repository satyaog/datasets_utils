#!/bin/bash

function rclone_copy {
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--remote) local _REMOTE="$1"; shift
			echo "remote = [${_REMOTE}]"
			;;
			--root) local _GDRIVE_DIR_ID="$1"; shift
			echo "root = [${_GDRIVE_DIR_ID}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--root GDRIVE_DIR_ID Google Drive root directory id"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${_arg}]"; exit 3 ;;
		esac
	done

	if [[ ! -z ${_REMOTE} ]] && [[ ${_REMOTE: -1} != ':' ]]
	then
		local _REMOTE="${_REMOTE}:"
	fi

	for src_w_dest in "$@"
	do
		local src_w_dest=(${src_w_dest[@]})
		local src=${src_w_dest[0]}
		local dest=${src_w_dest[1]}
		rclone copy --progress --create-empty-src-dirs --copy-links \
			--drive-root-folder-id=${_GDRIVE_DIR_ID} ${_REMOTE}${src} ${dest}
	done
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
