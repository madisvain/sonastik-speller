#!/bin/bash
# Install EstonianSpeller.service for the current user. No admin password.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "${here}/EstonianSpeller.service" ]]; then
	src="${here}/EstonianSpeller.service"
elif [[ -d "${here}/../dist/EstonianSpeller.service" ]]; then
	src="${here}/../dist/EstonianSpeller.service"
else
	echo "install-dev: EstonianSpeller.service not found. Run ./scripts/build.sh, or unzip the spelling-service artifact and run this script there." >&2
	exit 1
fi

dest="${HOME}/Library/Services"
mkdir -p "${dest}"
if pgrep -x EstonianSpeller >/dev/null 2>&1; then
	pkill -x EstonianSpeller || true
fi
rm -rf "${dest}/EstonianSpeller.service"
ditto "${src}" "${dest}/EstonianSpeller.service"
xattr -dr com.apple.quarantine "${dest}/EstonianSpeller.service" || true
chmod +x "${dest}/EstonianSpeller.service/Contents/MacOS/EstonianSpeller"

if ! codesign --verify "${dest}/EstonianSpeller.service" >/dev/null 2>&1; then
	codesign --force --sign - "${dest}/EstonianSpeller.service/Contents/Frameworks/libvabamorf.dylib"
	codesign --force --sign - "${dest}/EstonianSpeller.service"
fi

/System/Library/CoreServices/pbs -update

cat <<EOF
Installed ${dest}/EstonianSpeller.service

Choose the language in:
  System Settings → Keyboard → Text Input → Spelling

The entry is Estonian, vendor Sonastik (language et). macOS picks the exact label.
EOF
