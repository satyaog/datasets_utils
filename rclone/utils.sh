#!/bin/bash

function copy {
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

function mirror {
	local _LOCAL=0
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
			--dest) local _DEST="$1"; shift
			echo "dest = [${_DEST}]"
			;;
			--local) local _LOCAL=1
			echo "local = [${_LOCAL}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--remote REMOTE rclone remote"
			>&2 echo "--root GDRIVE_DIR_ID Google Drive root directory id"
			>&2 echo "--dest PATH destination"
			>&2 echo "[--local] destination is local"
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

	local _DEST_REMOTE=${_REMOTE}
	if [[ ${_LOCAL} == 1 ]]
	then
		local _DEST_REMOTE=
	fi

	while IFS= read -r _dir
	do
		rclone mkdir ${_DEST_REMOTE}${_DEST}/${_dir}
	done <<< $(rclone lsf --dirs-only --drive-root-folder-id ${_GDRIVE_DIR_ID} -R ${_REMOTE})
}


function trim_file_prefix {
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
			--prefix) local _PREFIX="$1"; shift
			echo "PREFIX = [${_PREFIX}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--remote REMOTE rclone remote"
			>&2 echo "--root GDRIVE_DIR_ID Google Drive root directory id"
			>&2 echo "--prefix STR"
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

	while IFS= read -r _file
	do
		local _renamed_file=${_file/#${_PREFIX}/}
		local _renamed_file=${_renamed_file/\/${_PREFIX}/\/}
		if [ "${_file}" != "${_renamed_file}" ]
		then
			echo "Renaming [${_file}] to [${_renamed_file}]"
			rclone moveto --drive-root-folder-id ${_GDRIVE_DIR_ID} ${_REMOTE}"${_file}" ${_REMOTE}"${_renamed_file}"
		fi
	done <<< $(rclone lsf --drive-root-folder-id ${_GDRIVE_DIR_ID} -R ${_REMOTE})
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
