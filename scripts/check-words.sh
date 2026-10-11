#!/bin/bash
# Layout check for the universal dist/ binaries. The word list is
# engine/cli/tests/cmd/words.toml and runs under cargo test.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$(pwd)"
vm="${1:-${root}/dist/vmspell}"
dylib="${root}/dist/libvabamorf.dylib"
dict="${root}/dist/et.dct"
commit="$(git -C vabamorf rev-parse HEAD)"

fail() {
	echo "check-words: $*" >&2
	exit 1
}

[[ -x "$vm" ]] || fail "missing $vm (run scripts/build.sh)"
[[ -f "$dylib" ]] || fail "missing $dylib"
[[ -f "$dict" ]] || fail "missing $dict"

for binary in "$vm" "$dylib"; do
	info="$(lipo -info "$binary")"
	echo "$info"
	echo "$info" | grep -q 'arm64' || fail "$binary is not arm64"
	echo "$info" | grep -q 'x86_64' || fail "$binary is not x86_64"
done

otool -L "$vm" | grep -q '@rpath/libvabamorf.dylib' || fail "vmspell is not linked with @rpath/libvabamorf.dylib"
otool -D "$dylib" | grep -q '@rpath/libvabamorf.dylib' || fail "dylib install name is not @rpath/libvabamorf.dylib"
otool -l "$vm" | grep -q '@loader_path' || fail "vmspell has no @loader_path rpath"

version="$("$vm" --version)"
echo "$version"
echo "$version" | grep -q "$commit" || fail "vm_version does not contain $commit"

set +e
"$vm" --dict /nonexistent/et.dct tere >/tmp/vmspell-missing.out 2>/tmp/vmspell-missing.err
status=$?
set -e
[[ "$status" -ne 0 && "$status" -lt 128 ]] || fail "missing dictionary exited $status"
grep -q . /tmp/vmspell-missing.err || fail "missing dictionary produced no error"

# Dictionary lookup must work from another directory, using et.dct beside the binary.
beside="$(cd /tmp && "$vm" kõrgaridus)"
echo "$beside"
[[ "$beside" == "kõrgaridus -- Vigane, soovitan: "* ]] || fail "lookup beside the binary failed: $beside"
first="${beside#kõrgaridus -- Vigane, soovitan: }"
first="${first%% *}"
[[ "$first" == "kõrgharidus" ]] || fail "beside-binary run suggested '$first'"

echo "check-words: ok"
