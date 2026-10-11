#!/bin/bash
# Install EstonianSpeller.service and the Sõnastik menu bar app for the current user.
# No admin password.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

find_bundle() {
	local name="$1"
	if [[ -d "${here}/${name}" ]]; then
		echo "${here}/${name}"
	elif [[ -d "${here}/../dist/${name}" ]]; then
		echo "${here}/../dist/${name}"
	else
		return 1
	fi
}

src="$(find_bundle EstonianSpeller.service)" || {
	echo "install-dev: EstonianSpeller.service not found. Run ./scripts/build.sh, or unzip the spelling-service artifact and run this script there." >&2
	exit 1
}
app_src="$(find_bundle Sonastik.app)" || {
	echo "install-dev: Sonastik.app not found. Run ./scripts/build.sh, or unzip the spelling-service artifact and run this script there." >&2
	exit 1
}

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

app_dest="${HOME}/Applications"
mkdir -p "${app_dest}"
if pgrep -x Sonastik >/dev/null 2>&1; then
	pkill -x Sonastik || true
fi
rm -rf "${app_dest}/Sonastik.app"
ditto "${app_src}" "${app_dest}/Sonastik.app"
xattr -dr com.apple.quarantine "${app_dest}/Sonastik.app" || true
chmod +x "${app_dest}/Sonastik.app/Contents/MacOS/Sonastik"
if ! codesign --verify "${app_dest}/Sonastik.app" >/dev/null 2>&1; then
	codesign --force --sign - "${app_dest}/Sonastik.app"
fi

/System/Library/CoreServices/pbs -update
open -g "${app_dest}/Sonastik.app"

cat <<EOF
Installed ${dest}/EstonianSpeller.service
Installed ${app_dest}/Sonastik.app

The menu bar shows ET or EN. Open it to choose a language from the Spelling
Set Up list. The first four are in the menu, and the rest are under More.
The menu also shows whether Sõnastik is running and which version is installed.

If macOS asks before the icon stays after login, allow it in:
  System Settings → General → Login Items

The spelling language is also in:
  System Settings → Keyboard → Text Input → Spelling

The entry is Estonian, vendor Sonastik (language et). macOS picks the exact label.
An already-open window can keep the dictionary it started with. A new window follows the menu.
EOF
