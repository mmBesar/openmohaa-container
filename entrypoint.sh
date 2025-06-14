#!/usr/bin/env bash
set -euo pipefail

export LD_LIBRARY_PATH="/opt/openmohaa/lib:$LD_LIBRARY_PATH"
exec /opt/openmohaa/bin/openmohaa-dedicated "$@"
