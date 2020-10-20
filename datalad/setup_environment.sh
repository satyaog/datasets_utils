#!/bin/bash

function exit_on_error_code {
	ERR=$?
	if [ $ERR -ne 0 ]
	then
		>&2 echo "$(tput setaf 1)ERROR$(tput sgr0): $1: $ERR"
		exit $ERR
	fi
}

ENV_NAME=datalad
ANNEX_VERSION=$(git config --file datalad/install_config --get git-annex.version)
DATALAD_VERSION=$(git config --file datalad/install_config --get datalad.version)

for ((i = 1; i <= ${#@}; i++))
do
	arg=${!i}
	case ${arg} in
		-n | --name)
		i=$((i+1))
		ENV_NAME=${!i}
		echo "env_name = [${ENV_NAME}]"
		;;
		--annex_version)
		i=$((i+1))
		ANNEX_VERSION=${!i}
		echo "annex_version = [${ANNEX_VERSION}]"
		;;
		--datalad_version)
		i=$((i+1))
		DATALAD_VERSION=${!i}
		echo "datalad_version = [${DATALAD_VERSION}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${arg}]. Valid options are:"
		>&2 echo "-n | --name conda environment name"
		>&2 echo "--annex_version version of git-annex to test"
		>&2 echo "--datalad_version version of datalad to use in test"
		exit 1
		;;
	esac
done

# Configure conda for bash shell
eval "$(conda shell.bash hook)"

if [[ -z "$(conda info --envs | grep -o "^${ENV_NAME}")" ]]
then
	echo "-- Creating a datalad conda environment"
	conda create --name ${ENV_NAME} --yes \
		--no-default-packages --use-local --no-channel-priority \
		python=$(python -V 2>&1 | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+")
	echo
fi

conda activate ${ENV_NAME}

echo "-- Install git-annex version ${ANNEX_VERSION} and datalad version ${DATALAD_VERSION}"
conda install --yes --use-local --no-channel-priority -c conda-forge \
	git-annex=${ANNEX_VERSION} datalad=${DATALAD_VERSION}
exit_on_error_code "Failed to install git-annex/datalad"

# Global config
# Having both annex.thin and annex.hardlink prevents 
# hardlinks to be used inter datasets/cache
# git config --system annex.thin true
git config --system annex.hardlink true
