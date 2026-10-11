#!/bin/bash
# Remove the per-user Estonian spelling service.
set -euo pipefail

dest="${HOME}/Library/Services/EstonianSpeller.service"
if pgrep -x EstonianSpeller >/dev/null 2>&1; then
	pkill -x EstonianSpeller || true
fi
rm -rf "${dest}"
/System/Library/CoreServices/pbs -update
echo "Removed ${dest}"
