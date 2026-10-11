#!/bin/bash
# Build a universal libvabamorf.dylib and vmspell into dist/.
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

# vmspell is Rust. Cargo builds one architecture at a time; lipo joins them.
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
	engine/cli/target/aarch64-apple-darwin/release/vmspell \
	engine/cli/target/x86_64-apple-darwin/release/vmspell \
	-output dist/vmspell
cp -f vabamorf/dct/binary/et.dct dist/
cp -f LICENSE NOTICE.md dist/
chmod +x dist/vmspell

echo "built ${root}/dist/vmspell ($(dist/vmspell --version))"
