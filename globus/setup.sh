#!/bin/bash
set -o errexit -o pipefail -o noclobber

DS_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd -P)"

while [[ $# -gt 0 ]]
do
    arg="$1"; shift
    case "${arg}" in
        --install_location) INSTALL_LOCATION="$1"; shift
        echo "install_location = [${INSTALL_LOCATION}]"
        ;;
        -h | --help)
        >&2 echo "Options for $(basename "$0") are:"
        >&2 echo "--install_location INSTALL_LOCATION dir to hold the globus venv"
        exit 1
        ;;
        --) break ;;
        *) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
    esac
done

source ${DS_UTILS_DIR}/utils.sh echo -n

init_venv --name globus --tmp ${INSTALL_LOCATION}

# Installing the Command Line Interface (CLI): https://docs.globus.org/cli/installation/
python3 -m pip install --upgrade globus-cli

# Add pip --user installs to your PATH: https://docs.globus.org/cli/installation/prereqs/#add_pip_user_installs_to_your_path
GLOBUS_CLI_INSTALL_DIR="$(python3 -c 'import site; print(site.USER_BASE)')/bin"
echo "GLOBUS_CLI_INSTALL_DIR = [$GLOBUS_CLI_INSTALL_DIR]"

export PATH="$GLOBUS_CLI_INSTALL_DIR:$PATH"
echo '# Globus installation path' >> "$HOME/.bashrc"
echo 'export PATH="'"$GLOBUS_CLI_INSTALL_DIR"':$PATH"' >> "$HOME/.bashrc"

globus login
