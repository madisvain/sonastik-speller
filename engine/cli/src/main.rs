// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (c) 2026 Madis Väin

use std::ffi::CString;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::{CommandFactory, Parser};

mod ffi;

#[derive(Parser)]
#[command(
    name = "vmspell",
    about = "Check Estonian spelling with Vabamorf",
    disable_version_flag = true
)]
struct Cli {
    /// Print the Vabamorf commit baked into the library and exit.
    #[arg(long)]
    version: bool,

    /// Dictionary path. Overrides VABAMORF_DICT and ./et.dct.
    #[arg(long)]
    dict: Option<String>,

    words: Vec<String>,
}

struct DictionaryQuery<'a> {
    flag: Option<&'a Path>,
    env: Option<&'a str>,
    cwd_has_dictionary: bool,
    beside_executable: Option<&'a Path>,
}

fn resolve_dictionary(query: DictionaryQuery<'_>) -> Result<PathBuf, &'static str> {
    if let Some(path) = query.flag {
        return Ok(path.to_path_buf());
    }
    if let Some(value) = query.env.filter(|value| !value.is_empty()) {
        return Ok(PathBuf::from(value));
    }
    if query.cwd_has_dictionary {
        return Ok(PathBuf::from("et.dct"));
    }
    query
        .beside_executable
        .map(Path::to_path_buf)
        .ok_or("dictionary not found")
}

fn dictionary_beside_executable() -> Option<PathBuf> {
    let executable = std::env::current_exe().ok()?;
    let executable = std::fs::canonicalize(executable).ok()?;
    Some(executable.parent()?.join("et.dct"))
}

fn path_bytes(path: &Path) -> Result<CString, String> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        ffi::c_string(path.as_os_str().as_bytes())
            .map_err(|()| "dictionary path contains a NUL byte".to_string())
    }
    #[cfg(not(unix))]
    {
        let text = path
            .to_str()
            .ok_or_else(|| "dictionary path is not UTF-8".to_string())?;
        ffi::c_string(text.as_bytes())
            .map_err(|()| "dictionary path contains a NUL byte".to_string())
    }
}

fn check_word(speller: &ffi::Speller, word: &str) -> Result<(), ffi::CheckFailure> {
    let c_word = CString::new(word).map_err(|_| ffi::CheckFailure::Spell)?;
    if speller.spell(&c_word)? {
        println!("{word} -- OK");
        return Ok(());
    }
    let suggestions = speller.suggest(&c_word)?;
    print!("{word} -- Vigane, soovitan:");
    for suggestion in suggestions {
        print!(" {suggestion}");
    }
    println!();
    Ok(())
}

fn run() -> ExitCode {
    let cli = Cli::parse();
    if cli.version {
        println!("{}", ffi::version());
        return ExitCode::SUCCESS;
    }
    if cli.words.is_empty() {
        Cli::command()
            .error(
                clap::error::ErrorKind::MissingRequiredArgument,
                "the following required arguments were not provided:\n  [WORD]...",
            )
            .exit();
    }

    let from_env = std::env::var("VABAMORF_DICT").ok();
    let beside = dictionary_beside_executable();
    let dictionary = match resolve_dictionary(DictionaryQuery {
        flag: cli.dict.as_deref().map(Path::new),
        env: from_env.as_deref(),
        cwd_has_dictionary: Path::new("et.dct").is_file(),
        beside_executable: beside.as_deref(),
    }) {
        Ok(path) => path,
        Err(message) => {
            eprintln!("vmspell: {message}");
            return ExitCode::from(1);
        }
    };

    let c_dictionary = match path_bytes(&dictionary) {
        Ok(path) => path,
        Err(message) => {
            eprintln!("vmspell: {message}");
            return ExitCode::from(1);
        }
    };
    let speller = match ffi::Speller::open(&c_dictionary) {
        Ok(speller) => speller,
        Err(message) => {
            eprintln!("vmspell: {message}");
            return ExitCode::from(1);
        }
    };

    for word in &cli.words {
        if let Err(failure) = check_word(&speller, word) {
            let verb = match failure {
                ffi::CheckFailure::Spell => "check",
                ffi::CheckFailure::Suggest => "suggest for",
            };
            eprintln!("vmspell: cannot {verb} '{word}'");
            return ExitCode::from(1);
        }
    }
    ExitCode::SUCCESS
}

fn main() -> ExitCode {
    run()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flag_overrides_environment_and_cwd() {
        let path = resolve_dictionary(DictionaryQuery {
            flag: Some(Path::new("/given/et.dct")),
            env: Some("/env/et.dct"),
            cwd_has_dictionary: true,
            beside_executable: Some(Path::new("/beside/et.dct")),
        })
        .unwrap();
        assert_eq!(path, PathBuf::from("/given/et.dct"));
    }

    #[test]
    fn environment_overrides_cwd_when_nonempty() {
        let path = resolve_dictionary(DictionaryQuery {
            flag: None,
            env: Some("/env/et.dct"),
            cwd_has_dictionary: true,
            beside_executable: Some(Path::new("/beside/et.dct")),
        })
        .unwrap();
        assert_eq!(path, PathBuf::from("/env/et.dct"));
    }

    #[test]
    fn empty_environment_falls_through_to_cwd() {
        let path = resolve_dictionary(DictionaryQuery {
            flag: None,
            env: Some(""),
            cwd_has_dictionary: true,
            beside_executable: None,
        })
        .unwrap();
        assert_eq!(path, PathBuf::from("et.dct"));
    }

    #[test]
    fn beside_executable_is_the_fallback() {
        let path = resolve_dictionary(DictionaryQuery {
            flag: None,
            env: None,
            cwd_has_dictionary: false,
            beside_executable: Some(Path::new("/beside/et.dct")),
        })
        .unwrap();
        assert_eq!(path, PathBuf::from("/beside/et.dct"));
    }

    #[test]
    fn missing_everywhere_is_an_error() {
        let error = resolve_dictionary(DictionaryQuery {
            flag: None,
            env: Some(""),
            cwd_has_dictionary: false,
            beside_executable: None,
        })
        .unwrap_err();
        assert_eq!(error, "dictionary not found");
    }
}
