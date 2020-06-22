#!/bin/bash

function delete_remote {
        if [ ${STORE_TOKEN} -ne 1 ]
        then
                echo "Deleting ${RCLONE_REMOTE_NAME} access token"
                rclone config delete ${RCLONE_REMOTE_NAME}
        fi
}

RCLONE_REMOTE_NAME=rclone_gdrive_datasets
STORE_TOKEN=0

for i in "$@"
do
        case ${i} in
                --dataset=*)
                DATASET="${i#*=}"
                echo "DATASET = [${DATASET}]"
                if [ ! -d ${DATASET} ]
                then
                        >&2 echo --dataset=path_to_dataset option must be an existing directory
                        unset DATASET
                fi
                ;;
                --store_token)
                STORE_TOKEN=1
                echo "STORE_TOKEN = [${STORE_TOKEN}]"
                ;;
                *)
                >&2 echo Unknown option [${i}]
                exit 1
                ;;
        esac
done

if [ -z "${DATASET}" ]
then
        >&2 echo --dataset=path_to_dataset option must be an existing directory
        >&2 echo Missing --dataset option
        exit 1
fi

DRIVE_DS=$(basename ${DATASET})
echo ${DRIVE_DS}

# Configured conda in bash shell
eval "$(conda shell.bash hook)"

if [ -z "$(conda info --envs | grep -o "^rclone_gdrive")" ]; then
        echo "Creating a rclone_gdrive conda environment"
        conda create --yes --no-channel-priority --name rclone_gdrive
fi

conda activate rclone_gdrive
conda install --yes --use-local --no-channel-priority -c conda-forge rclone=1.51.0

trap delete_remote EXIT

if [ -z "$(rclone listremotes | grep -o "^${RCLONE_REMOTE_NAME}:")" ]; then
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
        root_folder_id=
        rclone config create ${RCLONE_REMOTE_NAME} drive client_id ${client_id} \
                client_secret ${client_secret} \
                scope 'drive.file' \
                root_folder_id ${root_folder_id} \
                config_is_local false \
                config_refresh_token false
else
        STORE_TOKEN=1
fi

if [ -z "$(rclone lsd --max-depth 1 ${RCLONE_REMOTE_NAME}: | grep -o " ${DRIVE_DS}$")" ]; then
        rclone copy --progress --create-empty-src-dirs --drive-use-trash --drive-keep-revision-forever \
                ${DATASET} ${RCLONE_REMOTE_NAME}:${DRIVE_DS}/
else
        >&2 echo Dataset [${DRIVE_DS}] already exists on remote. Exiting now
        exit 1
fi
