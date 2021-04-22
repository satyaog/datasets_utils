#!/bin/bash

pushd `dirname "${BASH_SOURCE[0]}"` >/dev/null
_SCRIPT_DIR=`pwd -P`
cd ..
_DS_UTILS_DIR=`pwd -P`
popd >/dev/null

_MINIO_CONFIG=${_SCRIPT_DIR}/config
_MINIO_ALIAS=`git config --file "${_MINIO_CONFIG}" --get minio.alias`
_MINIO_MC=`git config --file "${_MINIO_CONFIG}" --get minio.mc`
_MINIO_TEMPLATES_DIR=`git config --file "${_MINIO_CONFIG}" --get minio.templates-dir`
if [[ -z ${_MINIO_ALIAS} ]]
then
	_MINIO_ALIAS=mila
fi
if [[ -z ${_MINIO_MC} ]]
then
	_MINIO_MC=mc
fi

function _print_shared_help {
	>&2 echo "[--alias ALIAS] MinIO server alias (defaults to '${_MINIO_ALIAS}')"
	>&2 echo "[--mc FILE] MinIO client binary to use (defaults to '${_MINIO_MC}')"
}

function add_bucket {
	source ${_DS_UTILS_DIR}/utils.sh echo -n

	local _quota=`git config --file "${_MINIO_CONFIG}" --get minio.quota`
	local _daily_quota=`git config --file "${_MINIO_CONFIG}" --get minio.daily-quota`
	local _min_time_to_live=`git config --file "${_MINIO_CONFIG}" --get minio.min-time-to-live`

	local _opts=h
	local _longopts=name:,data-size:,daily-quota:,force,alias:,mc:,help
	local _parsed
	_parsed=`enhanced_getopt --opts "${_opts}" --longopts "${_longopts}" \
		--name "${FUNCNAME[0]}" -- "$@"`
	exit_on_error_code
	eval set -- "${_parsed}"

	local _force=0
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _name="$1"; shift ;;
			--data-size) local _data_size="$1"; shift ;;
			--daily-quota) local _daily_quota="$1"; shift ;;
			--force) local _force=1; shift ;;
			--alias) local _MINIO_ALIAS="$1"; shift ;;
			--mc) local _MINIO_MC="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR bucket name"
			>&2 echo "--data-size INT expected data size in MB to be uploaded (defaults to ${_quota})"
			>&2 echo "--daily-quota INT expected average data size in MB to be uploaded in a day (defaults to ${_daily_quota})"
			_print_shared_help
			exit 1
			;;
		esac
	done

	if [[ -z ${_name} ]]
	then
		>&2 echo "Missing --name option"
		>&2 echo "Options for ${FUNCNAME[0]} are:"
		>&2 echo "--name STR bucket name"
		_print_shared_help
		exit 1
	fi

	if [[ ${_force} -ne 1 ]] && [[ ! -z `${_MINIO_MC} ls ${_MINIO_ALIAS} --json | grep -Eo \"key\":\"${_name}/?\"` ]]
	then
		>&2 echo "Bucket [${_name}] already exists. Use '--force' to assign new quota and time-to-live"
		return
	fi

	if [[ ! -z ${_data_size} ]]
	then
		_quota=$((${_data_size} * 1.25))
	fi

	local _time_to_live=$((${_quota} / ${_daily_quota}))
	_time_to_live=$(((${_time_to_live} * 2) / 7 + 1))
	_time_to_live=$((${_time_to_live} * 7 + ${_min_time_to_live}))

	if [[ ${_time_to_live} -lt ${_min_time_to_live} ]]
	then
		_time_to_live=${_min_time_to_live}
	fi

	echo $_name $_data_size $_daily_quota $_quota $_time_to_live
	${_MINIO_MC} mb ${_MINIO_ALIAS}/${_name}
	${_MINIO_MC} admin bucket quota ${_MINIO_ALIAS}/${_name} --hard ${_quota}MB
	${_MINIO_MC} ilm add --expiry-days ${_time_to_live} ${_MINIO_ALIAS}/${_name}
}

function add_user {
	source ${_DS_UTILS_DIR}/utils.sh echo -n
	local _opts=h
	local _longopts=name:,groups:,force,alias:,mc:,help
	local _parsed
	_parsed=`enhanced_getopt --opts "${_opts}" --longopts "${_longopts}" \
		--name "${FUNCNAME[0]}" -- "$@"`
	exit_on_error_code
	eval set -- "${_parsed}"

	local _force=0
	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _name="$1"; shift ;;
			--groups) local _groups="$1"; shift ;;
			--force) local _force=1; shift ;;
			--alias) local _MINIO_ALIAS="$1"; shift ;;
			--mc) local _MINIO_MC="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR user name"
			>&2 echo "[--groups STR[,STR...]] comma-separated list of groups to include user (optional)"
			>&2 echo "[--force] reset password"
			_print_shared_help
			exit 1
			;;
		esac
	done

	if [[ -z ${_name} ]]
	then
		>&2 echo "Missing --name option"
		>&2 echo "Options for ${FUNCNAME[0]} are:"
		>&2 echo "--name str user name"
		>&2 echo "[--groups str[,str...]] comma-separated list of groups to include user (optional)"
		_print_shared_help
		exit 1
	fi

	if [[ ${_force} -ne 1 ]] && [[ ! -z `${_MINIO_MC} admin user list ${_MINIO_ALIAS} --json | grep -Eo \"accessKey\":\"${_name}\"` ]]
	then
		>&2 echo "User [${_name}] already exists. Use '--force' to reset the password"
		return
	fi

	${_MINIO_MC} admin user add ${_MINIO_ALIAS} ${_name} \
		|| exit_on_error_code "Failed to create user [${_name}]"
	if [[ ! -z ${_groups} ]]
	then
		IFS=',' read -ra _groups <<< "${_groups}"
		for _g in "${_groups[@]}"
		do
			${_MINIO_MC} admin group add ${_MINIO_ALIAS} ${_g} ${_name} \
				|| exit_on_error_code "Failed to add user [${_name}] to group [${_g}]"
		done
	fi
}

function add_group {
	source ${_DS_UTILS_DIR}/utils.sh echo -n
	local _opts=h
	local _longopts=name:,user:,policy:,alias:,mc:,help
	local _parsed
	_parsed=`enhanced_getopt --opts "${_opts}" --longopts "${_longopts}" \
		--name "${FUNCNAME[0]}" -- "$@"`
	exit_on_error_code
	eval set -- "${_parsed}"

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _name="$1"; shift ;;
			--user) local _user="$1"; shift ;;
			--policy) local _policy="$1"; shift ;;
			--alias) local _MINIO_ALIAS="$1"; shift ;;
			--mc) local _MINIO_MC="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR group name"
			>&2 echo "--user STR user name to add in the group"
			>&2 echo "[--policy STR] policy to assign to group (optional)"
			_print_shared_help
			exit 1
			;;
		esac
	done

	if [[ -z ${_name} ]] || [[ -z ${_user} ]]
	then
		>&2 echo "Missing --name and/or --user options"
		>&2 echo "Options for ${FUNCNAME[0]} are:"
		>&2 echo "--name STR group name"
		>&2 echo "--user STR user name to add in the group"
		>&2 echo "[--policy STR] policy to assign to group (optional)"
		_print_shared_help
		exit 1
	fi
	${_MINIO_MC} admin group add ${_MINIO_ALIAS} ${_name} ${_user} \
		|| exit_on_error_code "Failed to create group [${_name}]"
	if [[ ! -z ${_policy} ]]
	then
		${_MINIO_MC} admin policy set ${_MINIO_ALIAS} ${_policy} group=${_name} \
			|| exit_on_error_code "Failed to assign policy [${_policy}] to group [${_name}]"
	fi
}

function add_policy_from_template {
	source ${_DS_UTILS_DIR}/utils.sh echo -n
	local _opts=h
	local _longopts=name:,template:,alias:,mc:,help
	local _parsed
	_parsed=`enhanced_getopt --opts "${_opts}" --longopts "${_longopts}" \
		--name "${FUNCNAME[0]}" -- "$@"`
	exit_on_error_code
	eval set -- "${_parsed}"

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--name) local _name="$1"; shift ;;
			--template) local _template="$1"; shift ;;
			--alias) local _MINIO_ALIAS="$1"; shift ;;
			--mc) local _MINIO_MC="$1"; shift ;;
			--) break ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--name STR policy name"
			>&2 echo "--template FILE json file containing '{{TOKEN}}' placeholders to be replaced"
			_print_shared_help
			>&2 echo "-- TOKEN VALUE [TOKEN VALUE...] space-separated token/value pairs. Each tokens will be replaced by their associated value in the template file"
			exit 1
			;;
		esac
	done

	if [[ -z ${_name} ]] || [[ -z ${_template} ]]
	then
		>&2 echo "Missing --name and/or --template options"
		>&2 echo "Options for ${FUNCNAME[0]} are:"
		>&2 echo "--name STR policy name"
		>&2 echo "--template FILE json file containing '{{TOKEN}}' placeholders to be replaced"
		_print_shared_help
		>&2 echo "-- TOKEN VALUE [TOKEN VALUE...] space-separated token/value pairs. Each tokens will be replaced by their associated value in the template file"
		exit 1
	fi

	if [[ ! -f ${_template} ]]
	then
		>&2 echo "Could not find [${_template}]. Will look in '${_MINIO_TEMPLATES_DIR}' for the file."
		_template=${_MINIO_TEMPLATES_DIR}/${_template}
	fi
	if [[ ! -f ${_template} ]]
	then
		exit_on_error_code --err 1 "[${_template}] template file does not exists"
	fi
	if (($# % 2))
	then
		exit_on_error_code --err 1 "Invalid number of positional arguments [$#]. Each TOKEN must be paired to a VALUE"
	fi

	local _tmp=`mktemp`
	trap "rm -rf ${_tmp}" EXIT

	cp -a ${_template} ${_tmp}
	while [[ $# -gt 0 ]]
	do
		local _key="$1"; shift
		case "${_key}" in
			*) sed -i "s/{{${_key}}}/"$1"/g" ${_tmp}; shift ;;
		esac
	done
	cat ${_tmp}
	${_MINIO_MC} admin policy add ${_MINIO_ALIAS} ${_name} ${_tmp}
}

function run_recipe {
	source ${_DS_UTILS_DIR}/utils.sh echo -n
	local _opts=h
	local _longopts=recipe:,project:,group:,bucket:,user:,policy:,policy-template:,alias:,mc:,help
	local _pre_parsed
	_pre_parsed=`enhanced_getopt --opts "${_opts}" --longopts "${_longopts}" \
		--name "${FUNCNAME[0]}" -- "$@"`
	exit_on_error_code
	eval set -- "${_pre_parsed}"

	while [[ $# -gt 0 ]]
	do
		local _arg="$1"; shift
		case "${_arg}" in
			--recipe) local _recipe="$1"; shift ;;
			--project) local _project="$1"; shift ;;
			--group) local _group="$1"; shift ;;
			--bucket) local _bucket="$1"; shift ;;
			--user) local _user="$1"; shift ;;
			--policy) local _policy="$1"; shift ;;
			--policy-template) local _policy_template="$1"; shift ;;
			--alias) local _MINIO_ALIAS="$1"; shift ;;
			--mc) local _MINIO_MC="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "--recipe STR label of the recipe to be read from '${_MINIO_CONFIG}'"
			>&2 echo "--project STR project name"
			>&2 echo "[--group STR] group name (optional)"
			>&2 echo "[--bucket STR] bucket name (optional)"
			>&2 echo "[--user STR] user name (optional)"
			>&2 echo "[--policy STR] policy name (optional)"
			>&2 echo "[--policy-template FILE] json file containing '{{TOKEN}}' placeholders to be replaced (optional)"
			_print_shared_help
			exit 1
			;;
		esac
	done

	if [[ -z ${_recipe} ]] || [[ -z ${_project} ]]
	then
		>&2 echo "Missing --recipe and/or --project options"
		>&2 echo "Options for ${FUNCNAME[0]} are:"
		>&2 echo "--recipe STR label of the recipe to be read from '${_MINIO_CONFIG}'"
		>&2 echo "--project STR project name"
		>&2 echo "[--group STR] group name (optional)"
		>&2 echo "[--bucket STR] bucket name (optional)"
		>&2 echo "[--user STR] user name (optional)"
		>&2 echo "[--policy STR] policy name (optional)"
		>&2 echo "[--policy-template FILE] json file containing '{{TOKEN}}' placeholders to be replaced (optional)"
		_print_shared_help
		exit 1
	fi

	if [[ ! ${_project: -2} =~ ^[0-9]+$ ]]
	then
		exit_on_error_code --err 1 "Project [${_project}] must end with at least two digits"
	fi

	if [[ -z ${_group} ]]
	then
		local _group=`git config --file "${_MINIO_CONFIG}" --get recipe.${_recipe}.group`
	fi
	if [[ -z ${_bucket} ]]
	then
		local _bucket=`git config --file "${_MINIO_CONFIG}" --get recipe.${_recipe}.bucket`
	fi
	if [[ -z ${_user} ]]
	then
		local _user=`git config --file "${_MINIO_CONFIG}" --get recipe.${_recipe}.user`
	fi
	if [[ -z ${_policy} ]]
	then
		local _policy=`git config --file "${_MINIO_CONFIG}" --get recipe.${_recipe}.policy`
	fi
	if [[ -z ${_policy_template} ]]
	then
		local _policy_template=`git config --file "${_MINIO_CONFIG}" --get recipe.${_recipe}.policy-template`
	fi

	if [[ -z ${_group} ]] || [[ -z ${_bucket} ]] || [[ -z ${_policy} ]] \
		|| [[ -z ${_policy_template} ]]
	then
		>&2 echo "Missing --group, --bucket, --policy and/or --policy-template options. Those options need to be set or found in the '${_recipe}' recipe of '${_MINIO_CONFIG}'"
		exit 1
	fi

	_pre_parsed=`enhanced_getopt --opts "${_opts}" --longopts "${_longopts}" \
		--name "${FUNCNAME[0]}" -- \
		--recipe "${_recipe}" \
		--project "${_project}" \
		--group "${_group}" \
		--bucket "${_bucket}" \
		--user "${_user}" \
		--policy "${_policy}" \
		--policy-template "${_policy_template}" \
		--alias "${_MINIO_ALIAS}" \
		--mc "${_MINIO_MC}"`
	exit_on_error_code

	_parsed=${_pre_parsed//\{\{PROJECT\}\}/${_project}}
	_parsed=${_parsed//\{\{GROUP\}\}/${_group}}
	_parsed=${_parsed//\{\{BUCKET\}\}/${_bucket}}

	if [[ "${_parsed}" != "${_pre_parsed}" ]]
	then
		eval set -- "${_parsed}"
		run_recipe "$@"
		exit $?
	fi

	add_bucket --name "${_bucket}"
	if [[ ! -z ${_user} ]]
	then
		echo "Adding user '${_user}'"
		add_user --name "${_user}" --alias "${_MINIO_ALIAS}" --mc "${_MINIO_MC}"
	fi
	add_policy_from_template --name "${_policy}" --template "${_policy_template}" \
		--alias "${_MINIO_ALIAS}" --mc "${_MINIO_MC}" -- \
		PROJECT "${_project}" GROUP "${_group}" BUCKET "${_bucket}"
	add_group --name "${_group}" --user "${_user}" --policy "${_policy}" \
		--alias "${_MINIO_ALIAS}" --mc "${_MINIO_MC}"
}

function add_generic_extern_policy {
	set -- BUCKET '${aws:username}' "$@"

	for _arg in "$@"
	do
		case "${_arg}" in
			--) break ;;
			-h | --help)
			>&2 echo "Options for ${FUNCNAME[0]} are:"
			>&2 echo "Same as add_policy_from_template with 'GROUP \${aws:username}' prepended to the list of tokens values"
			break
			;;
		esac
	done

	add_policy_from_template "$@"
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
