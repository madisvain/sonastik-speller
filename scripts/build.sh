#!/bin/bash
# Build a universal libvabamorf.dylib, sonastik, and EstonianSpeller.service into dist/.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$(pwd)"

if [[ ! -f vabamorf/lib/proof/linguistic.h ]]; then
	echo "vabamorf submodule is missing. Run: git submodule update --init --recursive" >&2
	exit 1
fi

commit="$(git -C vabamorf rev-parse HEAD)"
if command -v ninja >/dev/null 2>&1; then
	generator=(-G Ninja)
else
	generator=(-G "Unix Makefiles")
fi

cmake -S engine -B build "${generator[@]}" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
	-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
	-DVM_VABAMORF_COMMIT="${commit}"

cmake --build build --parallel

# sonastik is Rust. Cargo builds one architecture at a time; lipo joins them.
# @loader_path is how the binary finds libvabamorf.dylib next to itself.
export MACOSX_DEPLOYMENT_TARGET=13.0
# One rpath entry. The finished binary finds the dylib next to itself.
case " ${RUSTFLAGS:-} " in
*" -C link-arg=-Wl,-rpath,@loader_path "*) ;;
*) export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-Wl,-rpath,@loader_path" ;;
esac
export VABAMORF_LIB_DIR="${root}/build"
rustup show >/dev/null
cargo fmt --check --manifest-path engine/cli/Cargo.toml
cargo clippy --release --manifest-path engine/cli/Cargo.toml -- -D warnings
# The test harness is not the dist binary, so @loader_path does not see the dylib.
DYLD_LIBRARY_PATH="${root}/build${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
	cargo test --release --manifest-path engine/cli/Cargo.toml
cargo build --release --manifest-path engine/cli/Cargo.toml --target aarch64-apple-darwin
cargo build --release --manifest-path engine/cli/Cargo.toml --target x86_64-apple-darwin

mkdir -p dist
cp -f build/libvabamorf.dylib dist/
lipo -create \
	engine/cli/target/aarch64-apple-darwin/release/sonastik \
	engine/cli/target/x86_64-apple-darwin/release/sonastik \
	-output dist/sonastik
cp -f vabamorf/dct/binary/et.dct dist/
cp -f LICENSE NOTICE.md dist/
scripts/third-party.sh dist/THIRD-PARTY.md
chmod +x dist/sonastik

echo "built ${root}/dist/sonastik ($(dist/sonastik --version))"

if ! command -v xcodegen >/dev/null 2>&1; then
	echo "xcodegen is missing. Install it with: brew install xcodegen" >&2
	exit 1
fi

# The test host loads this dylib. Sign it before xcodebuild.
codesign --force --sign - build/libvabamorf.dylib

xcodegen generate --spec service/project.yml --project service

xcodebuild \
	-project service/EstonianSpeller.xcodeproj \
	-scheme EstonianSpeller \
	-configuration Release \
	-destination 'platform=macOS' \
	-derivedDataPath service/DerivedData \
	ARCHS="arm64 x86_64" \
	ONLY_ACTIVE_ARCH=NO \
	test

product="${root}/service/DerivedData/Build/Products/Release/EstonianSpeller.service"
[[ -d "${product}" ]] || {
	echo "missing ${product}" >&2
	exit 1
}
rm -rf dist/EstonianSpeller.service
ditto "${product}" dist/EstonianSpeller.service
# Inside out. --deep would re-sign nested code with the wrong options.
codesign --force --sign - dist/EstonianSpeller.service/Contents/Frameworks/libvabamorf.dylib
codesign --force --sign - dist/EstonianSpeller.service
codesign --verify --verbose=2 dist/EstonianSpeller.service
info="dist/EstonianSpeller.service/Contents/Info.plist"
[[ "$(plutil -extract NSServices.0.NSSpellChecker raw -o - "${info}")" == "Sonastik" ]]
[[ "$(plutil -extract NSServices.0.NSExecutable raw -o - "${info}")" == "EstonianSpeller" ]]
[[ "$(plutil -extract NSServices.0.NSPortName raw -o - "${info}")" == "EstonianSpeller" ]]
[[ "$(plutil -extract NSServices.0.NSLanguages.0 raw -o - "${info}")" == "et" ]]
[[ "$(plutil -extract LSBackgroundOnly raw -o - "${info}")" == "true" ]]
[[ "$(plutil -extract LSUIElement raw -o - "${info}")" == "true" ]]
cp -f scripts/install-dev.sh scripts/uninstall.sh dist/
chmod +x dist/install-dev.sh dist/uninstall.sh

service_bin="dist/EstonianSpeller.service/Contents/MacOS/EstonianSpeller"
service_info="$(lipo -info "${service_bin}")"
echo "${service_info}"
echo "${service_info}" | grep -q arm64
echo "${service_info}" | grep -q x86_64
[[ -f dist/EstonianSpeller.service/Contents/Resources/et.dct ]]
[[ -f dist/EstonianSpeller.service/Contents/Frameworks/libvabamorf.dylib ]]
otool -l "${service_bin}" | grep -q '@executable_path/../Frameworks'

echo "built ${root}/dist/EstonianSpeller.service"
