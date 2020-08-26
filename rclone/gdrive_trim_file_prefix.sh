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
		--prefix)
		i=$((i+1))
		PREFIX=${!i}
		echo "PREFIX = [${PREFIX}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${arg}]. Valid options are:"
		>&2 echo "--remote RCLONE_REMOTE_NAME"
		>&2 echo "--remote_root_dir GDRIVE_ROOT_DIR_ID"
		>&2 echo "--prefix PREFIX"
		exit 1
		;;
	esac
done

if [ -z "${REMOTE}" ] || [ -z "${REMOTE_FOLDER_ID}" ] || [ -z "${PREFIX}" ]
then
	>&2 echo "Missing --remote, --remote_root_dir and/or --prefix options"
	exit 1
fi

while IFS= read -r file
do
	renamed_file=${file/#${PREFIX}/}
	renamed_file=${renamed_file/\/${PREFIX}/\/}
	if [ "${file}" != "${renamed_file}" ]
	then
		echo "Renaming [${file}] to [${renamed_file}]"
		rclone moveto --drive-root-folder-id ${REMOTE_FOLDER_ID} ${REMOTE}:"${file}" ${REMOTE}:"${renamed_file}"
	fi
done <<< $(rclone lsf --drive-root-folder-id ${REMOTE_FOLDER_ID} -R ${REMOTE}:)
