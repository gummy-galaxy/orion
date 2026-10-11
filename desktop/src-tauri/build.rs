use std::process::Command;

fn main() {
    // The About panel names the commit Orion was built from. The reflog changes whenever HEAD
    // moves, so it tells Cargo when to look again.
    if let Some(reflog) = git(&["rev-parse", "--git-path", "logs/HEAD"]) {
        println!("cargo:rerun-if-changed={reflog}");
    }
    if let Some(commit) = git(&["rev-parse", "--short", "HEAD"]) {
        println!("cargo:rustc-env=ORION_COMMIT={commit}");
    }

    tauri_build::build()
}

fn git(args: &[&str]) -> Option<String> {
    let output = Command::new("git").args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }

    let text = String::from_utf8(output.stdout).ok()?.trim().to_string();
    (!text.is_empty()).then_some(text)
}
