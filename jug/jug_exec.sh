#!/bin/bash

DS_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd -P)"

source ${DS_UTILS_DIR}/jug/utils.sh echo -n

jug_exec "$@"