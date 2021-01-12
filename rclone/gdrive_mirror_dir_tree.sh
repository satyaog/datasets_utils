#!/bin/bash

for ((i = 1; i <= ${#@}; i++))
do
	_arg=${!i}
	case ${_arg} in
		--remote)
		i=$((i+1))
		_REMOTE=${!i}
		echo "REMOTE = [${_REMOTE}]"
		;;
		--remote_root_dir)
		i=$((i+1))
		_REMOTE_FOLDER_ID=${!i}
		echo "REMOTE_FOLDER_ID = [${_REMOTE_FOLDER_ID}]"
		;;
		--dest)
		i=$((i+1))
		_DEST=${!i}
		echo "DEST = [${_DEST}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${_arg}]. Valid options are:"
		>&2 echo "--remote RCLONE_REMOTE_NAME"
		>&2 echo "--remote_root_dir GDRIVE_ROOT_DIR_ID"
		>&2 echo "--dest DEST"
		exit 1
		;;
	esac
done

if [ -z "${_REMOTE}" ] || [ -z "${_REMOTE_FOLDER_ID}" ] || [ -z "${_DEST}" ]
then
	>&2 echo "Missing --remote and/or --dest options"
	exit 1
fi

while IFS= read -r _dir
do
	rclone mkdir ${_DEST}/${_dir}
done <<< $(rclone lsf --dirs-only --drive-root-folder-id ${_REMOTE_FOLDER_ID} -R ${_REMOTE}:)
