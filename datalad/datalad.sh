#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )"; pwd -P)"

dlcreate()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		arg=${!i}
		case ${arg} in
			-n | --name)
			i=$((i+1))
			NAME=${!i}
			echo "name = [${NAME}]"
			;;
			-s | --sibling)
			i=$((i+1))
			SIBLING=${!i}
			echo "sibling = [${SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${arg}]. valid options are:"
			>&2 echo "-n | --name name of the dataset to create"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	if [ -z "${name}" ]
	then
		>&2 echo "[-n | --name] name of the dataset"
		>&2 echo missing --name option
		exit 1
	fi

	python $DIR/datalad_brf.py create $NAME $SIBLING
}

dlinst()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		arg=${!i}
		case ${arg} in
			-n | --name)
			i=$((i+1))
			NAME=${!i}
			echo "name = [${NAME}]"
			;;
			-s | --sibling)
			i=$((i+1))
			SIBLING=${!i}
			echo "sibling = [${SIBLING}]"
			;;
			--url)
			i=$((i+1))
			URL=${!i}
			echo "url = [${URL}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${arg}]. Valid options are:"
			>&2 echo "--url url of the dataset to install"
			>&2 echo "[-n | --name] name of the dataset to install (optional)"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	if [ -z "$URL" ]
	then
		>&2 echo "--url url of the dataset to install"
		>&2 echo Missing --url option
		exit 1
	fi

	python $DIR/datalad_brf.py install $URL $NAME $SIBLING
}

dlinstsubds()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		arg=${!i}
		case ${arg} in
			-s | --sibling)
			i=$((i+1))
			SIBLING=${!i}
			echo "sibling = [${SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${arg}]. Valid options are:"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python $DIR/datalad_brf.py install_subdatasets $SIBLING
}

dlpublish()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		arg=${!i}
		case ${arg} in
			-p | --path)
			i=$((i+1))
			PATH=${!i}
			echo "path = [${PATH}]"
			;;
			-s | --sibling)
			i=$((i+1))
			SIBLING=${!i}
			echo "sibling = [${SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${arg}]. valid options are:"
			>&2 echo "[-p | --name] name of the dataset to create (optional)"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python $DIR/datalad_brf.py publish $path $sibling
}

dlupdate()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		arg=${!i}
		case ${arg} in
			-s | --sibling)
			i=$((i+1))
			SIBLING=${!i}
			echo "sibling = [${SIBLING}]"
			;;
			-h | --help | *)
			>&2 echo "Unknown option [${arg}]. Valid options are:"
			>&2 echo "[-s | --sibling] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python $DIR/datalad_brf.py update $SIBLING
}

dlinitgithub()
{
	for ((i = 1; i <= ${#@}; i++))
	do
		arg=${!i}
		case ${arg} in
			-n | --name)
			i=$((i+1))
			NAME=${!i}
			echo "name = [${NAME}]"
			;;
			-l | --login)
			i=$((i+1))
			LOGIN=${!i}
			echo "login = [${LOGIN}]"
			;;
			-h | --help | *)
			>&2 echo "unknown option [${arg}]. valid options are:"
			>&2 echo "[-n | --name] name of the dataset to create (optional)"
			>&2 echo "[-l | --login] name of the sibling (optional)"
			exit 1
			;;
		esac
	done

	python $DIR/datalad_brf.py init_github $NAME $LOGIN
}
