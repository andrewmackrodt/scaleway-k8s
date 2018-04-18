#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

cat <<EOF
USER_DATA=1
USER_DATA_0=ssh-host-fingerprints
EOF
