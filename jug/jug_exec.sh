#!/bin/bash

_DS_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd -P)"

source ${_DS_UTILS_DIR}/jug/utils.sh echo -n

jug_exec "$@"