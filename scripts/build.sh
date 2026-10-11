#!/bin/bash
# Build a universal libvabamorf.dylib and vmspell into dist/.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$(pwd)"

if [[ ! -f third_party/vabamorf/lib/proof/linguistic.h ]]; then
	echo "vabamorf submodule is missing. Run: git submodule update --init --recursive" >&2
	exit 1
fi

commit="$(git -C third_party/vabamorf rev-parse HEAD)"
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

mkdir -p dist
cp -f build/libvabamorf.dylib build/vmspell dist/
cp -f third_party/vabamorf/dct/binary/et.dct dist/
cp -f LICENSE NOTICE.md dist/
chmod +x dist/vmspell

echo "built ${root}/dist/vmspell ($(dist/vmspell --version))"
