# sonastik-speller

Estonian spelling for macOS, using Filosoft's [Vabamorf](https://github.com/Filosoft/vabamorf) engine.

This milestone builds the engine only: a universal `libvabamorf.dylib` and a `vmspell` command. macOS does not yet offer Estonian ("eesti") as a system spelling language. That service comes in a later milestone. Firefox and Microsoft Word use their own checkers and will not use this one.

Our code is LGPL-2.1-or-later. See `NOTICE.md` for the Vabamorf license and the dictionary.

## English

### Build

You need macOS 13 or newer, the Xcode command-line tools, CMake, and stable Rust.

```sh
git clone --recurse-submodules https://github.com/madisvain/sonastik-speller.git
cd sonastik-speller
./scripts/build.sh
./scripts/check-words.sh
```

`./scripts/build.sh` writes `dist/`:

- `vmspell`, the command-line checker
- `libvabamorf.dylib`, the engine (Apple Silicon and Intel)
- `et.dct`, the spelling dictionary
- `LICENSE` and `NOTICE.md`

### Check a word

```sh
./dist/vmspell kõrgaridus
```

The first suggestion is `kõrgharidus`. `./dist/vmspell --version` prints the Vabamorf commit baked into the library.

`vmspell` looks for the dictionary in this order:

1. `--dict PATH`
2. the `VABAMORF_DICT` environment variable
3. `et.dct` in the current directory
4. `et.dct` next to the `vmspell` binary

The build copies the dictionary next to `dist/vmspell`, so the command above needs no extra path. A missing dictionary prints an error and exits with status 1. A misspelled word is still a successful run: the process exits 0 and prints suggestions.

### Download a build

GitHub Actions builds the same `dist/` directory on every push and pull request. Download the `engine-macos` artifact from the workflow run, unzip it, and in Terminal:

```sh
xattr -dr com.apple.quarantine .
./vmspell kõrgaridus
```

The artifact is unsigned. macOS may warn about a download that is not from an identified developer. That warning goes away in the signed-installer milestone. Clearing the quarantine flag is enough to run this one.

### Layout

`third_party/vabamorf` is a submodule pinned to a known commit. The C API in `engine/shim/vabamorf_c.h` is the only surface the rest of the program uses. `vmspell` is Rust and links only that API.

## Eesti keeles

See etapp ehitab ainult mootori: universaalse teegi `libvabamorf.dylib` ja käsureaprogrammi `vmspell`. macOS ei paku veel eesti keelt süsteemse õigekirjakontrollina. See teenus tuleb hilisemas etapis. Firefox ja Microsoft Word kasutavad oma kontrolli ega hakka seda teeki kasutama.

Meie kood on litsentsiga LGPL-2.1-or-later. Vabamorfi litsents ja sõnastik on kirjas failis `NOTICE.md`.

### Ehitamine

Vaja on macOS 13 või uuemat, Xcode'i käsureatööriistu, CMake'i ja Rusti stabiilset väljalaset.

```sh
git clone --recurse-submodules https://github.com/madisvain/sonastik-speller.git
cd sonastik-speller
./scripts/build.sh
./scripts/check-words.sh
```

`./scripts/build.sh` teeb kataloogi `dist/`:

- `vmspell`, käsurea kontrollija
- `libvabamorf.dylib`, mootor (Apple Silicon ja Intel)
- `et.dct`, õigekirjasõnastik
- `LICENSE` ja `NOTICE.md`

### Sõna kontroll

```sh
./dist/vmspell kõrgaridus
```

Esimene soovitus on `kõrgharidus`. `./dist/vmspell --version` trükib Vabamorfi commiti, millega teek kompileeriti.

`vmspell` otsib sõnastikku selles järjekorras:

1. `--dict PATH`
2. keskkonnamuutuja `VABAMORF_DICT`
3. `et.dct` jooksvas kataloogis
4. `et.dct` `vmspell` binaari kõrval

Ehitus kopeerib sõnastiku `dist/vmspell` kõrvale, nii et ülaltoodud käsk lisateed ei vaja. Puuduv sõnastik trükib vea ja lõpetab olekuga 1. Valesti kirjutatud sõna on ikka õnnestunud käivitus: protsess lõpetab olekuga 0 ja trükib soovitused.

### Valmis ehitis

GitHub Actions ehitab sama `dist/` kataloogi iga pushi ja pull requesti peal. Laadi töövoo jooksust alla artefakt `engine-macos`, paki see lahti ja käivita Terminalis:

```sh
xattr -dr com.apple.quarantine .
./vmspell kõrgaridus
```

Artefakt ei ole allkirjastatud. macOS võib hoiatada, et allalaaditud programm ei ole tuntud arendajalt. See hoiatus kaob allkirjastatud paigaldaja etapis. Karantiinilipu eemaldamisest piisab, et seda ehitist käivitada.

### Paigutus

`third_party/vabamorf` on alammoodul, mis on kinnitatud kindlale commitile. C-liides failis `engine/shim/vabamorf_c.h` on ainus pind, mida ülejäänud programm kasutab. `vmspell` on kirjutatud Rustis ja seob end ainult selle liidesega.
