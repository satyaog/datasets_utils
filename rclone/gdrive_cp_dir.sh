#!/bin/bash

function delete_remote {
	if [ ${_STORE_TOKEN} -ne 1 ]
	then
		echo "Deleting ${_REMOTE} access token"
		rclone config delete ${_REMOTE}
	fi
}

_REMOTE=gdrive_datasets
_STORE_TOKEN=0

for ((i = 1; i <= ${#@}; i++))
do
	_arg=${!i}
	case ${_arg} in
		-d | --dataset)
		i=$((i+1))
		_DATASET=${!i}
		>&2 echo "DATASET = [${_DATASET}]"
		if [ ! -d ${_DATASET} ]
		then
			>&2 echo --dataset path_to_dataset option must be an existing directory
			unset _DATASET
		fi
		;;
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
		--store_token)
		_STORE_TOKEN=1
		>&2 echo "STORE_TOKEN = [${_STORE_TOKEN}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${_arg}]. Valid options are:"
		>&2 echo "[-d | --dataset] path_to_dataset"
		>&2 echo "--remote rclone_remote_name (optional)"
		>&2 echo "--remote_root_dir gdrive_root_directory_id (optional)"
		>&2 echo "--store_token (optional)"
		exit 1
		;;
	esac
done

if [ -z "${_DATASET}" ]
then
	>&2 echo "[-d | --dataset] path_to_dataset option must be an existing directory"
	>&2 echo "Missing --dataset option"
	exit 1
fi

_DRIVE_DS=$(basename $(realpath ${_DATASET}))
echo ${_DRIVE_DS}

# Configured conda in bash shell
eval "$(conda shell.bash hook)"

if [ -z "$(conda info --envs | grep -o "^rclone_gdrive")" ]
then
	echo "Creating a rclone_gdrive conda environment"
	conda create --yes --no-channel-priority --name rclone_gdrive
fi

conda activate rclone_gdrive
conda install --yes --strict-channel-priority --use-local -c defaults -c conda-forge rclone=1.51.0

trap delete_remote EXIT

if [ -z "$(rclone listremotes | grep -o "^${_REMOTE}:")" ]
then
	if [ ${_STORE_TOKEN} -ne 1 ]
	then
		echo "Would you like to store the access token to skip the authentication process the next time this script is executed?"
		echo "y) Yes"
		echo "n) No (default)"
	fi
	while [ ${_STORE_TOKEN} -ne 1 ]
	do
		read -p "y/n> " answer

		case "${answer}" in
			[yY]*)
			_STORE_TOKEN=1
			break
			;;
			[nN]* | "")
			_STORE_TOKEN=0
			break
			;;
			*)
			;;
		esac
	done
	client_id=
	client_secret=
	if [ -z "${_REMOTE_FOLDER_ID}" ]
	then
		root_folder_id=
	else
		root_folder_id=${_REMOTE_FOLDER_ID}
	fi
	rclone config create ${_REMOTE} drive client_id ${client_id} \
		client_secret ${client_secret} \
		scope 'drive.file' \
		root_folder_id ${root_folder_id} \
		config_is_local false \
		config_refresh_token false
else
	_STORE_TOKEN=1
fi

if [ -z "$(rclone lsd --max-depth 1 ${_REMOTE}: | grep -o " ${_DRIVE_DS}$")" ]
then
	if [ -z "${_REMOTE_FOLDER_ID}" ]
	then
		rclone copy --progress --create-empty-src-dirs --drive-use-trash --drive-keep-revision-forever --copy-links \
			${_DATASET} ${_REMOTE}:${_DRIVE_DS}/
	else
		rclone copy --progress --create-empty-src-dirs --drive-use-trash --drive-keep-revision-forever --copy-links \
			--drive-root-folder-id=${_REMOTE_FOLDER_ID} ${_DATASET} ${_REMOTE}:${_DRIVE_DS}/
	fi
else
	>&2 echo Dataset [${_DRIVE_DS}] already exists on remote. Exiting now
	exit 1
fi
