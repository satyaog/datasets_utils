#!/bin/bash

NAME=.annex-cache

for ((i = 1; i <= ${#@}; i++))
do
	arg=${!i}
	case ${arg} in
		-l | --location)
		i=$((i+1))
		LOCATION=${!i}
		echo "location = [${LOCATION}]"
		if [ ! -d ${LOCATION} ]
		then
			>&2 echo --location path_to_partent_dir option must be an existing directory
			unset LOCATION
		fi
		;;
		-n | --name)
		i=$((i+1))
		NAME=${!i}
		echo "name = [${NAME}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${arg}]. Valid options are:"
		>&2 echo "-l | --location path to parent dir where to setup the cache"
		>&2 echo "-n | --name name of the cache (optional)"
		exit 1
		;;
	esac
done

if [ -z "${LOCATION}" ] || [ -z "$NAME" ]
then
	>&2 echo --location path_to_partent_dir option must be an existing directory
	>&2 echo Missing --location option
	exit 1
fi

cd ${LOCATION}/

git init --bare ${NAME}
cd ${NAME}/
git-annex init

# Local config
git config annex.hardlink true

# Global config
git config --system remote.cache-0fea6a.url "$PWD"
git config --system remote.cache-0fea6a.fetch "+refs/heads/empty_branch:refs/remotes/cache-0fea6a/empty_branch"
git config --system remote.cache-0fea6a.annex-cost 70
git config --system remote.cache-0fea6a.annex-speculate-present true
git config --system remote.cache-0fea6a.annex-pull false
git config --system remote.cache-0fea6a.annex-push false

# Create an empty branch to avoid automatic fetch errors from git
cd ..

git clone ${NAME}/ annex-cache-to-del/
cd annex-cache-to-del
git checkout -b empty_branch
touch empty_file
git add empty_file
git commit -m "Empty commit"
git push origin empty_branch

cd ..

rm -rf annex-cache-to-del/

