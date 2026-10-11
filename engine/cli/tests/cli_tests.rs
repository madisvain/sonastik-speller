use std::path::PathBuf;

#[test]
fn cli_tests() {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let dylib_dir = manifest_dir
        .join("../../build")
        .canonicalize()
        .expect("build directory with libvabamorf.dylib");
    let dylib_dir = dylib_dir
        .to_str()
        .expect("dylib directory is UTF-8")
        .to_string();

    trycmd::TestCases::new()
        .default_bin_name("vmspell")
        .env("DYLD_LIBRARY_PATH", dylib_dir)
        .case("tests/cmd/*.toml");
}
