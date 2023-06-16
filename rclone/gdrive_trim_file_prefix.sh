#!/bin/bash

for ((i = 1; i <= ${#@}; i++))
do
	_arg=${!i}
	case ${_arg} in
		--remote)
		i=$((i+1))
		_REMOTE=${!i}
		>&2 echo "REMOTE = [${_REMOTE}]"
		;;
		--remote_root_dir)
		i=$((i+1))
		_REMOTE_FOLDER_ID=${!i}
		>&2 echo "REMOTE_FOLDER_ID = [${_REMOTE_FOLDER_ID}]"
		;;
		--prefix)
		i=$((i+1))
		_PREFIX=${!i}
		>&2 echo "PREFIX = [${_PREFIX}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${_arg}]. Valid options are:"
		>&2 echo "--remote RCLONE_REMOTE_NAME"
		>&2 echo "--remote_root_dir GDRIVE_ROOT_DIR_ID"
		>&2 echo "--prefix PREFIX"
		exit 1
		;;
	esac
done

if [ -z "${_REMOTE}" ] || [ -z "${_REMOTE_FOLDER_ID}" ] || [ -z "${_PREFIX}" ]
then
	>&2 echo "Missing --remote, --remote_root_dir and/or --prefix options"
	exit 1
fi

while IFS= read -r _file
do
	_renamed_file=${_file/#${_PREFIX}/}
	_renamed_file=${_renamed_file/\/${_PREFIX}/\/}
	if [ "${_file}" != "${_renamed_file}" ]
	then
		echo "Renaming [${_file}] to [${_renamed_file}]"
		rclone moveto --drive-root-folder-id ${_REMOTE_FOLDER_ID} ${_REMOTE}:"${_file}" ${_REMOTE}:"${_renamed_file}"
	fi
done <<< $(rclone lsf --drive-root-folder-id ${_REMOTE_FOLDER_ID} -R ${_REMOTE}:)
