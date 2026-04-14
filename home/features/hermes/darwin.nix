/**
  Darwin-only Hermes glue. Upstream Hermes CLI owns launchd on macOS.
*/
{
  config,
  lib,
  pkgs,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };
  hermesConfig = import ./config.nix {
    homeDirectory = config.home.homeDirectory;
  };
in
lib.mkIf pkgs.stdenv.isDarwin {
  home.sessionVariables.HERMES_HOME = "${config.home.homeDirectory}/.hermes";

  home.file.".hermes/config.yaml".source = yamlFormat.generate "hermes-config.yaml" hermesConfig;

  home.activation.hermesDarwinGuidance = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ! command -v hermes >/dev/null 2>&1; then
      printf '%s\n' 'anix: Hermes is not installed on amac; use the upstream macOS workflow, then run "hermes gateway install".'
    elif [ ! -f "$HOME/Library/LaunchAgents/ai.hermes.gateway.plist" ]; then
      printf '%s\n' 'anix: Hermes config is managed declaratively; run "hermes gateway install" to create the macOS launchd agent.'
    fi
  '';
}
