{ rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "ag-cli";
  version = "0.1.0";
  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "ag-cli";
    mainProgram = "ag-cli";
  };
}
