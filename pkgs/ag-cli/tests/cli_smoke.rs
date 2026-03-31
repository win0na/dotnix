use assert_cmd::Command;

#[test]
fn setup_command_creates_workspace_files() {
    let dir = tempfile::tempdir().unwrap();
    Command::cargo_bin("ag-cli")
        .unwrap()
        .args(["--cwd", dir.path().to_str().unwrap(), "setup"])
        .assert()
        .success();

    assert!(dir.path().join("config.json").exists());
    assert!(dir.path().join("keys.json").exists());
}

#[test]
fn setup_command_prints_manual_oauth_steps() {
    let dir = tempfile::tempdir().unwrap();
    let output = Command::cargo_bin("ag-cli")
        .unwrap()
        .args(["--cwd", dir.path().to_str().unwrap(), "setup"])
        .assert()
        .success()
        .get_output()
        .stdout
        .clone();
    let stdout = String::from_utf8(output).unwrap();
    assert!(stdout.contains("OAuth clients page"));
    assert!(stdout.contains("paste CLIENT_ID and CLIENT_SECRET"));
    assert!(stdout.contains("login --no-browser"));
}

#[test]
fn status_command_runs_after_setup() {
    let dir = tempfile::tempdir().unwrap();
    Command::cargo_bin("ag-cli")
        .unwrap()
        .args(["--cwd", dir.path().to_str().unwrap(), "setup"])
        .assert()
        .success();
    Command::cargo_bin("ag-cli")
        .unwrap()
        .args(["--cwd", dir.path().to_str().unwrap(), "status"])
        .assert()
        .success();
}
