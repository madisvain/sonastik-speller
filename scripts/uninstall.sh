#!/bin/bash
# Remove the per-user Estonian spelling service and the Sõnastik menu bar app.
set -euo pipefail

app="${HOME}/Applications/Sonastik.app"
if [[ -x "${app}/Contents/MacOS/Sonastik" ]]; then
	"${app}/Contents/MacOS/Sonastik" --unregister || true
fi
if pgrep -x Sonastik >/dev/null 2>&1; then
	pkill -x Sonastik || true
fi
rm -rf "${app}"

dest="${HOME}/Library/Services/EstonianSpeller.service"
if pgrep -x EstonianSpeller >/dev/null 2>&1; then
	pkill -x EstonianSpeller || true
fi
rm -rf "${dest}"
/System/Library/CoreServices/pbs -update
echo "Removed ${dest}"
echo "Removed ${app}"
