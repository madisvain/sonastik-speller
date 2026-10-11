# Notices

## This project

`sonastik-speller` is licensed under the GNU Lesser General Public License, version 2.1 or later (LGPL-2.1-or-later). The license text is in `LICENSE`. "Or later" is this project's own grant: you may use our code under LGPL-2.1 or any later version published by the Free Software Foundation.

## Vabamorf

The spelling engine is [Filosoft Vabamorf](https://github.com/Filosoft/vabamorf), included as a git submodule at `vabamorf`.

- Copyright (c) 2015, Filosoft.
- The upstream `LICENSE` file says only: "Tarkvara on litsentseeritud LGPL alustel. Software is licensed under LGPL." It does not name a version.
- An unversioned LGPL grant lets the recipient choose any published version of the GNU LGPL. That is the Free Software Foundation's reading of a library that says it is under "the LGPL" without a version number (see the FSF FAQ, "If a library says it's released under the LGPL, but doesn't specify a version"). We choose LGPL-2.1-or-later, the same grant as our own code.
- The submodule is pinned to commit `a1defeb38fc581712537ceb35ab2a5cef8e3f068` (2026-10-08). Do not edit it in this repository. Changes to Vabamorf belong upstream, or in `patches/` applied by the build.

Vabamorf is built as a separate dynamic library, `libvabamorf.dylib`. The command-line tool links it at runtime through `@rpath`, and `EstonianSpeller.service` loads its own copy from `Contents/Frameworks` the same way. Replacing either copy does not require rebuilding `sonastik` or the service.

## Dictionary

Spelling uses the binary lexicon `dct/binary/et.dct` from the pinned Vabamorf commit (about 2.4 MB). That file is built from the source lexicon data in the same repository. `et3.dct` is the analyzer and disambiguator lexicon and is not used.

`vm_version()` reports the Vabamorf commit the library was compiled against.

## Third-party Rust crates

The `sonastik` command statically links Rust crates from crates.io. They are permissive licenses: MIT OR Apache-2.0, except `unicode-ident`, which is `(MIT OR Apache-2.0) AND Unicode-3.0`. MIT and Apache-2.0 require that redistributed binaries carry the license notices.

`scripts/third-party.sh` runs during `scripts/build.sh` and writes `dist/THIRD-PARTY.md`: the crate list with each license expression, followed by the license texts shipped with those crates. The file is generated from the dependency graph at build time, so it stays in sync with `engine/cli/Cargo.lock`.
