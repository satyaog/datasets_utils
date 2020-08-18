#!/bin/bash

function delete_remote {
	if [ ${STORE_TOKEN} -ne 1 ]
	then
		echo "Deleting ${REMOTE} access token"
		rclone config delete ${REMOTE}
	fi
}

REMOTE=rclone_gdrive_datasets
STORE_TOKEN=0

for ((i = 1; i <= ${#@}; i++))
do
	arg=${!i}
	case ${arg} in
		-d | --dataset)
		i=$((i+1))
		DATASET=${!i}
		echo "DATASET = [${DATASET}]"
		if [ ! -d ${DATASET} ]
		then
			>&2 echo --dataset path_to_dataset option must be an existing directory
			unset DATASET
		fi
		;;
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
		--store_token)
		STORE_TOKEN=1
		echo "STORE_TOKEN = [${STORE_TOKEN}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${arg}]. Valid options are:"
		>&2 echo "[-d | --dataset] path_to_dataset"
		>&2 echo "--remote rclone_remote_name (optional)"
		>&2 echo "--remote_root_dir gdrive_root_directory_id (optional)"
		>&2 echo "--store_token (optional)"
		exit 1
		;;
	esac
done

if [ -z "${DATASET}" ]
then
	>&2 echo [-d | --dataset] path_to_dataset option must be an existing directory
	>&2 echo Missing --dataset option
	exit 1
fi

DRIVE_DS=$(basename $(realpath ${DATASET}))
echo ${DRIVE_DS}

# Configured conda in bash shell
eval "$(conda shell.bash hook)"

if [ -z "$(conda info --envs | grep -o "^rclone_gdrive")" ]
then
	echo "Creating a rclone_gdrive conda environment"
	conda create --yes --no-channel-priority --name rclone_gdrive
fi

conda activate rclone_gdrive
conda install --yes --use-local --no-channel-priority -c conda-forge rclone=1.51.0

trap delete_remote EXIT

if [ -z "$(rclone listremotes | grep -o "^${REMOTE}:")" ]
then
	if [ ${STORE_TOKEN} -ne 1 ]
	then
		echo "Would you like to store the access token to skip the authentication process the next time this script is executed?"
		echo "y) Yes"
		echo "n) No (default)"
	fi
	while [ ${STORE_TOKEN} -ne 1 ]
	do
		read -p "y/n> " answer

		case "${answer}" in
			[yY]*)
			STORE_TOKEN=1
			break
			;;
			[nN]* | "")
			STORE_TOKEN=0
			break
			;;
			*)
			;;
		esac
	done
	client_id=
	client_secret=
	if [ -z "${REMOTE_FOLDER_ID}" ]
	then
		root_folder_id=
	else
		root_folder_id=${REMOTE_FOLDER_ID}
	fi
	rclone config create ${REMOTE} drive client_id ${client_id} \
		client_secret ${client_secret} \
		scope 'drive.file' \
		root_folder_id ${root_folder_id} \
		config_is_local false \
		config_refresh_token false
else
	STORE_TOKEN=1
fi

if [ -z "$(rclone lsd --max-depth 1 ${REMOTE}: | grep -o " ${DRIVE_DS}$")" ]
then
	if [ -z "${REMOTE_FOLDER_ID}" ]
	then
		rclone copy --progress --create-empty-src-dirs --drive-use-trash --drive-keep-revision-forever --copy-links \
			${DATASET} ${REMOTE}:${DRIVE_DS}/
	else
		rclone copy --progress --create-empty-src-dirs --drive-use-trash --drive-keep-revision-forever --copy-links \
			--drive-root-folder-id=${REMOTE_FOLDER_ID} ${DATASET} ${REMOTE}:${DRIVE_DS}/
	fi
else
	>&2 echo Dataset [${DRIVE_DS}] already exists on remote. Exiting now
	exit 1
fi
