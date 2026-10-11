# sonastik-speller

Estonian spelling for macOS, using Filosoft's [Vabamorf](https://github.com/Filosoft/vabamorf) engine.

The build produces a universal `libvabamorf.dylib`, a `sonastik` command, `EstonianSpeller.service`, and `Sonastik.app`. The service is a background app with no window. The menu bar app shows **ET** or **EN** and switches the spelling language. After the service is installed, System Settings lists Estonian from Sonastik, and TextEdit, Notes, Safari, and Chrome underline Estonian misspellings. Firefox and Microsoft Word use their own checkers and will not use this one.

Our code is LGPL-2.1-or-later. See `NOTICE.md` for the Vabamorf license and the dictionary.

## English

### Build

You need macOS 13 or newer, the Xcode command-line tools, CMake, stable Rust, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
git clone --recurse-submodules https://github.com/madisvain/sonastik-speller.git
cd sonastik-speller
./scripts/build.sh
./scripts/check-words.sh
```

`./scripts/build.sh` runs `cargo test`, which checks the word list in `engine/cli/tests/cmd/words.toml`. `./scripts/check-words.sh` checks the universal binaries in `dist/`.

`./scripts/build.sh` writes `dist/`:

- `sonastik`, the command-line checker
- `libvabamorf.dylib`, the engine (Apple Silicon and Intel)
- `et.dct`, the spelling dictionary
- `LICENSE`, `NOTICE.md`, and `THIRD-PARTY.md` (license notices for the Rust crates linked into `sonastik`)
- `EstonianSpeller.service`, the background spelling service
- `Sonastik.app`, the menu bar switch
- `install-dev.sh` and `uninstall.sh`

### Check a word

```sh
./dist/sonastik kõrgaridus
```

The first suggestion is `kõrgharidus`. `./dist/sonastik --version` prints the Vabamorf commit baked into the library.

`sonastik` looks for the dictionary in this order:

1. `--dict PATH`
2. the `VABAMORF_DICT` environment variable
3. `et.dct` in the current directory
4. `et.dct` next to the `sonastik` binary

The build copies the dictionary next to `dist/sonastik`, so the command above needs no extra path. A missing dictionary prints an error and exits with status 1. A misspelled word is still a successful run: the process exits 0 and prints suggestions.

### Download a build

GitHub Actions builds the same `dist/` directory on every push and pull request. Download the `engine-macos` artifact from the workflow run, unzip it, and in Terminal:

```sh
xattr -dr com.apple.quarantine .
./sonastik kõrgaridus
```

The command-line artifact is ad-hoc signed at most, and it is not notarized. macOS may warn about a download that is not from an identified developer. That warning goes away in the signed-installer milestone. Clearing the quarantine flag is enough to run the command.

### Install the spelling service

The service has no window and no dock icon. macOS draws the underline and the suggestion menu. `Sonastik.app` is a second app: a menu bar item, not a package. From a checkout, after `./scripts/build.sh`:

```sh
./scripts/install-dev.sh
```

GitHub Actions also uploads a `spelling-service` artifact. Unzip it and run `./install-dev.sh` in that directory. The script copies `EstonianSpeller.service` to `~/Library/Services/` and `Sonastik.app` to `~/Applications/` for the current user, clears the quarantine flag, re-signs a copy ad hoc if the signature did not survive the copy, and asks macOS to rescan services. It does not ask for an admin password. It does not write to the system `/Applications` folder or to `/Library`.

The menu bar then shows **ET** or **EN**. Open it and choose a language from the Spelling Set Up list. The first four are in the menu. The rest are under **More**. The menu also says whether Sõnastik is running and shows the installed version (`Version 1.0` and the `vabamorf` commit from `./dist/sonastik --version`). **Start Sõnastik** launches the service when it is installed and stopped. **Quit Sõnastik** closes the menu bar app and leaves the spelling process running. macOS may ask you to allow the login item under System Settings → General → Login Items.

The same language is in System Settings → Keyboard → Text Input → Spelling. Choose the Estonian entry whose vendor is Sonastik. The registration is language `et` and vendor `Sonastik`. macOS picks the exact label.

In TextEdit, type `raamtukogu`. It is underlined, and the first suggestion is `raamatukogu`. The same word works in Notes, Safari, and Chrome. A window that is already open can keep the dictionary it started with; open a new window after switching. Signal keeps its own checker.

Remove both with `./scripts/uninstall.sh`, or with `./uninstall.sh` next to the unzipped artifact.

Hyphenated words, abbreviations, and URLs are still split into letter runs. `e-post` can flag `e`. ALL-CAPS words are checked. Those rules come in a later milestone. The build is ad-hoc signed, not notarized.

### Troubleshooting

- The language does not appear after install. Run `/System/Library/CoreServices/pbs -update`, then log out and back in.
- macOS says the bundle is from an unidentified developer, or that it is damaged. Run `install-dev.sh` again. It clears `com.apple.quarantine` and signs the bundle ad hoc.
- Startup messages are in Console.app. Filter on `ee.madisvain.estonianspeller`. The menu bar app uses `ee.madisvain.sonastik`.
- The menu bar icon disappears after login. Allow Sõnastik under System Settings → General → Login Items, or open `~/Applications/Sonastik.app`.

### Layout

`vabamorf` is a submodule pinned to a known commit. The C API in `engine/shim/vabamorf_c.h` is the only surface the rest of the program uses. `sonastik` is Rust and links only that API.

## Eesti keeles

Ehitus teeb universaalse teegi `libvabamorf.dylib`, käsureaprogrammi `sonastik`, teenuse `EstonianSpeller.service` ja rakenduse `Sonastik.app`. Teenus on taustarakendus ega ava oma akent. Menüüribal näitab rakendus **ET** või **EN** ja vahetab õigekirjakeelt. Pärast teenuse paigaldamist näitab süsteemiseadete loend eesti keelt pakkujalt Sonastik ning TextEdit, Notes, Safari ja Chrome tõmbavad vigased sõnad alla. Firefox ja Microsoft Word kasutavad oma kontrolli ega hakka seda teenust kasutama.

Meie kood on litsentsiga LGPL-2.1-or-later. Vabamorfi litsents ja sõnastik on kirjas failis `NOTICE.md`.

### Ehitamine

Vaja on macOS 13 või uuemat, Xcode'i käsureatööriistu, CMake'i, Rusti stabiilset väljalaset ja [XcodeGeni](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
git clone --recurse-submodules https://github.com/madisvain/sonastik-speller.git
cd sonastik-speller
./scripts/build.sh
./scripts/check-words.sh
```

`./scripts/build.sh` käivitab `cargo test`, mis kontrollib sõnaloendit failis `engine/cli/tests/cmd/words.toml`. `./scripts/check-words.sh` kontrollib universaalseid binaare kataloogis `dist/`.

`./scripts/build.sh` teeb kataloogi `dist/`:

- `sonastik`, käsurea kontrollija
- `libvabamorf.dylib`, mootor (Apple Silicon ja Intel)
- `et.dct`, õigekirjasõnastik
- `LICENSE`, `NOTICE.md` ja `THIRD-PARTY.md` (litsentsiteated Rusti kastide kohta, mis on `sonastik`-i sisse lingitud)
- `EstonianSpeller.service`, taustal töötav õigekirjateenus
- `Sonastik.app`, menüüriba lüliti
- `install-dev.sh` ja `uninstall.sh`

### Sõna kontroll

```sh
./dist/sonastik kõrgaridus
```

Esimene soovitus on `kõrgharidus`. `./dist/sonastik --version` trükib Vabamorfi commiti, millega teek kompileeriti.

`sonastik` otsib sõnastikku selles järjekorras:

1. `--dict PATH`
2. keskkonnamuutuja `VABAMORF_DICT`
3. `et.dct` jooksvas kataloogis
4. `et.dct` `sonastik` binaari kõrval

Ehitus kopeerib sõnastiku `dist/sonastik` kõrvale, nii et ülaltoodud käsk lisateed ei vaja. Puuduv sõnastik trükib vea ja lõpetab olekuga 1. Valesti kirjutatud sõna on ikka õnnestunud käivitus: protsess lõpetab olekuga 0 ja trükib soovitused.

### Valmis ehitis

GitHub Actions ehitab sama `dist/` kataloogi iga pushi ja pull requesti peal. Laadi töövoo jooksust alla artefakt `engine-macos`, paki see lahti ja käivita Terminalis:

```sh
xattr -dr com.apple.quarantine .
./sonastik kõrgaridus
```

Käsurea artefakt on kõige rohkem ad-hoc allkirjastatud ja ei ole notariseeritud. macOS võib hoiatada, et allalaaditud programm ei ole tuntud arendajalt. See hoiatus kaob allkirjastatud paigaldaja etapis. Karantiinilipu eemaldamisest piisab, et käsku käivitada.

### Õigekirjateenuse paigaldamine

Teenusel ei ole akent ega dokiikooni. Allajoonimise ja soovituste menüü joonistab macOS. `Sonastik.app` on teine rakendus: menüüriba ikoon, mitte paigalduspakett. Pärast `./scripts/build.sh` käivita hoidlast:

```sh
./scripts/install-dev.sh
```

GitHub Actions laadib üles ka artefakti `spelling-service`. Paki see lahti ja käivita selles kataloogis `./install-dev.sh`. Skript kopeerib `EstonianSpeller.service` praeguse kasutaja kausta `~/Library/Services/` ja `Sonastik.app` kausta `~/Applications/`, eemaldab karantiinilipu, allkirjastab koopia ad-hoc, kui kopeerimine allkirja lõhkus, ja palub macOS-il teenused uuesti üle vaadata. Administraatori parooli ei küsita. Süsteemi kausta `/Applications` ega kausta `/Library` ei kirjutata.

Menüüribal on seejärel **ET** või **EN**. Ava see ja vali keel õigekirja seadistuse nimekirjast. Neli esimest on menüüs. Ülejäänud on alammenüüs **More**. Menüü ütleb ka, kas Sõnastik taustal töötab, ja näitab paigaldatud versiooni (`Version 1.0` ning `vabamorf` commiti, mille trükib `./dist/sonastik --version`). **Start Sõnastik** käivitab teenuse, kui see on paigaldatud, aga seisab. **Quit Sõnastik** sulgeb menüüribal rakenduse ja jätab õigekirjaprotsessi tööle. macOS võib küsida luba sisselogimisüksusele: Süsteemi seaded → Üldine → Sisselogimisüksused.

Sama keel on Süsteemi seaded → Klaviatuur → Tekstisisestus → Õigekiri. Vali eesti keele kirje, mille pakkuja on Sonastik. Registreeritud keel on `et` ja pakkuja `Sonastik`. Täpse sildi valib macOS.

TextEditis kirjuta `raamtukogu`. Sõna tõmmatakse alla ja esimene soovitus on `raamatukogu`. Sama sõna töötab Notesis, Safaris ja Chromes. Juba avatud aken võib alles hoida sõnastiku, millega see algas. Pärast vahetamist ava uus aken. Signal kasutab oma kontrolli.

Mõlema eemaldamiseks käivita `./scripts/uninstall.sh` või lahtipakitud artefakti kõrval `./uninstall.sh`.

Sidekriipsuga sõnad, lühendid ja veebiaadressid jagatakse ikka tähejadadeks. `e-post` võib märkida `e` vigaseks. Läbiva suurtähega sõnu kontrollitakse. Need reeglid tulevad hilisemas etapis. Ehitus on allkirjastatud ad-hoc, mitte notariseeritud.

### Tõrkeotsing

- Keel ei ilmu pärast paigaldamist. Käivita `/System/Library/CoreServices/pbs -update` ja logi välja ning tagasi sisse.
- macOS ütleb, et pakett on tundmatult arendajalt või rikutud. Käivita `install-dev.sh` uuesti. See eemaldab `com.apple.quarantine` ja allkirjastab paketi ad-hoc.
- Käivituslogid on rakenduses Console. Filtreeri `ee.madisvain.estonianspeller`. Menüüribal rakendus kasutab `ee.madisvain.sonastik`.
- Menüüriba ikoon kaob pärast sisselogimist. Luba Sõnastik jaotises Süsteemi seaded → Üldine → Sisselogimisüksused või ava `~/Applications/Sonastik.app`.

### Paigutus

`vabamorf` on alammoodul, mis on kinnitatud kindlale commitile. C-liides failis `engine/shim/vabamorf_c.h` on ainus pind, mida ülejäänud programm kasutab. `sonastik` on kirjutatud Rustis ja seob end ainult selle liidesega.
