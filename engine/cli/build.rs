use std::env;
use std::path::PathBuf;

fn main() {
    let dir = env::var_os("VABAMORF_LIB_DIR").map_or_else(
        || {
            PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR"))
                .join("../../build")
        },
        PathBuf::from,
    );
    let dylib = dir.join("libvabamorf.dylib");
    if !dylib.is_file() {
        panic!(
            "libvabamorf.dylib not found in {}. Run ./scripts/build.sh from the repository root.",
            dir.display()
        );
    }

    println!("cargo:rustc-link-search=native={}", dir.display());
    println!("cargo:rustc-link-lib=dylib=vabamorf");
    println!("cargo:rerun-if-env-changed=VABAMORF_LIB_DIR");
    println!("cargo:rerun-if-changed={}", dylib.display());
}
