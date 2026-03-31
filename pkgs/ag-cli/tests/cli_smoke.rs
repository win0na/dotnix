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
