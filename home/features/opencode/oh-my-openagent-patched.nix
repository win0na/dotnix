/**
  Patched oh-my-openagent package used to avoid zero-width agent-name prefixes
  that corrupt the OpenCode startup UI on NixOS terminals.
*/
{ pkgs }:
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "oh-my-openagent";
  version = "3.17.1-anix1";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/oh-my-openagent/-/oh-my-openagent-3.17.1.tgz";
    hash = "sha256-qh84qsP0O+DwdIK7qVtRVYIoqCCyo/pCXau5PfppLh4=";
  };

  nativeBuildInputs = [
    pkgs.gnutar
    pkgs.gzip
  ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    tar -xzf "$src" --strip-components=1 -C "$out"

    substituteInPlace "$out/dist/index.js" \
      --replace 'return prefix ? `${prefix}${displayName}` : displayName;' 'return displayName;'

    runHook postInstall
  '';
}
