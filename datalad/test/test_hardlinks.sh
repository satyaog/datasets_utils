#!/bin/bash

function clean_env {
	echo "-- Cleaning environment"
	echo "-- Remove test datasets"
	datalad remove --nocheck tmp/dataset*

	echo "-- Uninit and remove git-annex cache"
	(cd tmp/annex_${_ANNEX_VERSION}/.annex-cache/; git-annex uninit --force)
	rm -rf tmp/annex_${_ANNEX_VERSION}/.annex-cache/

	echo "-- Remove conda environment test_git_annex_${_ANNEX_VERSION}"
	conda deactivate
	conda env remove --name test_git_annex_${_ANNEX_VERSION}

	rm -rf tmp/
}

function exit_on_error_code {
	local _ERR=$?
	if [ ${_ERR} -ne 0 ]
	then
		>&2 echo "$(tput setaf 1)ERROR$(tput sgr0): $1: ${_ERR}"
		exit ${_ERR}
	fi
}

function assert_inodes_are_equal {
	origin_dataset_inodes=$(ls -liL tmp/dataset/file* | grep -o "[0-9]\{9\}")
	cloned_dataset_inodes=$(ls -liL tmp/dataset_clone/file* | grep -o "[0-9]\{9\}")
	if [ "${origin_dataset_inodes}" != "${cloned_dataset_inodes}" ]
	then
		>&2 echo "$(tput setaf 1)ASSERTION ERROR$(tput sgr0): Inodes in origal dataset don't match those in cloned dataset"
		>&2 echo "${origin_dataset_inodes}"
		>&2 echo " !="
		>&2 echo "${cloned_dataset_inodes}"
		exit 1
	else
		echo "$(tput setaf 2)Test passed$(tput sgr0)"
	fi
}

function test_inodes {
	local _COPY_FROM=$1

	echo "-- Clone test dataset"
	datalad install -s tmp/dataset tmp/dataset_clone
	(cd tmp/dataset_clone; \
	 git-annex get --fast --from ${_COPY_FROM}; \
	 git-annex list --fast)
	echo

	# Assert inodes of the file are the same
	echo "-- ls tmp/dataset/"
	ls -lhi tmp/dataset/file*
	ls -lhiL tmp/dataset/file*
	echo "-- ls tmp/dataset_clone/"
	ls -lhi tmp/dataset_clone/file*
	ls -lhiL tmp/dataset_clone/file*
	echo

	assert_inodes_are_equal
}

_ANNEX_VERSION=$(git config --file datalad/install_config --get git-annex.version)
_DATALAD_VERSION=$(git config --file datalad/install_config --get datalad.version)

for ((i = 1; i <= ${#@}; i++))
do
	_arg=${!i}
	case ${_arg} in
		--annex_version)
		i=$((i+1))
		_ANNEX_VERSION=${!i}
		echo "annex_version = [${_ANNEX_VERSION}]"
		;;
		--datalad_version)
		i=$((i+1))
		_DATALAD_VERSION=${!i}
		echo "datalad_version = [${_DATALAD_VERSION}]"
		;;
		-h | --help | *)
		>&2 echo "Unknown option [${_arg}]. Valid options are:"
		>&2 echo "--annex_version version of git-annex to test"
		>&2 echo "--datalad_version version of datalad to use in test"
		exit 1
		;;
	esac
done

if [ -z "${_ANNEX_VERSION}" ] || [ -z "${_DATALAD_VERSION}" ]
then
	>&2 echo "--annex_version version of git-annex to test"
	>&2 echo "--datalad_version version of datalad to use in test"
	>&2 echo Missing --annex_version and/or --datalad_version option
	exit 1
fi

./datalad/setup_environment.sh --name test_git_annex_${_ANNEX_VERSION} --annex_version ${_ANNEX_VERSION} --datalad_version ${_DATALAD_VERSION}
echo

trap clean_env EXIT

# Configure conda for bash shell
eval "$(conda shell.bash hook)"

conda activate test_git_annex_${_ANNEX_VERSION}

mkdir -p tmp/

echo "-- Create a git-annex cache"
mkdir -p tmp/annex_${_ANNEX_VERSION}/.annex-cache
./datalad/create_annex_cache.sh --location tmp/annex_${_ANNEX_VERSION}/ --name .annex-cache
exit_on_error_code "Failed to create git-annex cache"
echo

# Create test dataset
echo "-- Create test dataset"
datalad create tmp/dataset
(cd tmp/dataset; \
 mkdir scripts; \
 echo "#!/bin/bash" >> scripts/create_files.sh; \
 echo "dd if=/dev/zero of=file1 bs=1024 count=5120" >> scripts/create_files.sh; \
 echo "dd if=/dev/zero of=file2 bs=1024 count=5120" >> scripts/create_files.sh; \
 echo "echo 1 >> file2" >> scripts/create_files.sh; \
 chmod +x scripts/create_files.sh; \
 git -c annex.largefiles=nothing add scripts/create_files.sh; \
 git commit -m "Add scripts/create_files.sh"; \
 datalad run scripts/create_files.sh; \
 git-annex copy --to cache-0fea6a)
echo

echo "-- Test that inodes are the same when proxied through cache"
test_inodes cache-0fea6a
echo

echo "-- Test that inodes are the same when directly asking the origin dataset"
echo "-- Remove cloned dataset"
datalad remove --nocheck tmp/dataset_clone
test_inodes origin
echo
