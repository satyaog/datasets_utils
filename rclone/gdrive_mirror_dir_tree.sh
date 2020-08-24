#!/bin/bash

for ((i = 1; i <= ${#@}; i++))
do
	arg=${!i}
	case ${arg} in
		--remote)
		i=$((i+1))
		REMOTE=${!i}
		echo "REMOTE = [${REMOTE}]"
		;;
		--remote_root_dir)
		i=$((i+1))
		REMOTE_FOLDER_ID=${!i}
		echo "REMOTE_FOLDER_ID = [${REMOTE_FOLDER_ID}]"
		;;
		--dest)
		DEST=1
		echo "DEST = [${DEST}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${arg}]. Valid options are:"
		>&2 echo "--remote RCLONE_REMOTE_NAME"
		>&2 echo "--remote_root_dir GDRIVE_ROOT_DIR_ID"
		>&2 echo "--dest DEST"
		exit 1
		;;
	esac
done

if [ -z "${REMOTE}" ] || [ -z "${REMOTE_FOLDER_ID}" ] || [ -z "${DEST}" ]
then
	>&2 echo "Missing --remote and/or --dest options"
	exit 1
fi

while IFS= read -r dir
do
        rclone mkdir ${DEST}/${dir}
done <<< $(rclone lsf --dirs-only --remote_root_dir ${REMOTE_FOLDER_ID} -R ${REMOTE}:)
