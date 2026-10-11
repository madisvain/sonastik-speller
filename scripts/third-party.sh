#!/bin/bash
# Generate third-party license notices for the Rust crates linked into
# dist/sonastik. The notices list every normal and build dependency of the two
# macOS targets and embed the license texts shipped with those crates.
# Usage: scripts/third-party.sh [output-file]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="${root}/engine/cli/Cargo.toml"
out="${1:-${root}/dist/THIRD-PARTY.md}"

crates="$(
	cargo tree --manifest-path "$manifest" --target aarch64-apple-darwin --edges normal,build --prefix none --format '{p}'
	cargo tree --manifest-path "$manifest" --target x86_64-apple-darwin --edges normal,build --prefix none --format '{p}'
)"

CRATES="$crates" MANIFEST="$manifest" python3 - "$out" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys

out = sys.argv[1]
root_manifest = os.path.abspath(os.environ["MANIFEST"])
line_re = re.compile(r"^\S+ v\d+\.\d+\.\d+(?: \([^)]*\))?$")
crates = sorted({
	(line.rsplit(" v", 1)[0], line.rsplit(" v", 1)[1].split(" (", 1)[0])
	for line in os.environ["CRATES"].splitlines() if line_re.match(line)
})

meta = json.loads(subprocess.run(
	["cargo", "metadata", "--format-version", "1", "--manifest-path", os.environ["MANIFEST"]],
	capture_output=True, text=True, check=True).stdout)
packages = {(p["name"], p["version"]): p for p in meta["packages"]}

texts = {}  # sha -> {"title": str, "body": str, "also": [str]}
rows = []
missing = []

for name, version in crates:
	pkg = packages[(name, version)]
	if os.path.abspath(pkg["manifest_path"]) == root_manifest:
		continue
	license = pkg.get("license") or "NOASSERTION"
	rows.append((name, version, license))
	manifest_dir = os.path.dirname(pkg["manifest_path"])
	license_files = sorted(
		f for f in os.listdir(manifest_dir)
		if f.startswith(("LICENSE", "COPYING", "NOTICE"))
		and os.path.isfile(os.path.join(manifest_dir, f)))
	if not license_files:
		missing.append(f"{name} {version}: no license file in {manifest_dir}")
		continue
	for filename in license_files:
		with open(os.path.join(manifest_dir, filename), encoding="utf-8", errors="replace") as handle:
			body = handle.read()
		sha = hashlib.sha256(body.encode()).hexdigest()
		entry = texts.setdefault(sha, {"title": f"{filename} (from {name} {version})", "body": body, "also": []})
		if f"{name} {version}" not in entry["title"]:
			entry["also"].append(f"{name} {version}")

if missing:
	sys.exit("third-party: " + "; ".join(missing))

with open(out, "w", encoding="utf-8") as handle:
	handle.write("# Third-party notices\n\n")
	handle.write("The `sonastik` binary in this archive is statically linked with the following\n")
	handle.write("Rust crates. Each crate carries the license shown next to it; the license texts\n")
	handle.write("follow the list.\n\n")
	handle.write("| Crate | Version | License |\n")
	handle.write("|---|---|---|\n")
	for name, version, license in rows:
		handle.write(f"| {name} | {version} | {license} |\n")
	handle.write("\n")
	for entry in texts.values():
		handle.write(f"## {entry['title']}\n\n")
		if entry["also"]:
			handle.write("The same text applies to: " + ", ".join(sorted(set(entry["also"]))) + ".\n\n")
		handle.write(entry["body"].rstrip() + "\n\n")

print(f"third-party: {len(rows)} crates, {len(texts)} license texts -> {out}")
PY
