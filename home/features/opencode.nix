/** Declarative OpenCode configuration for NixOS Home Manager profiles. */
{ config, lib, pkgs, ... }:
let
  patchedOhMyOpenagent = import ./opencode/oh-my-openagent-patched.nix { inherit pkgs; };
  baseOpencodeConfig = builtins.fromJSON (builtins.readFile ./opencode/opencode.json);
  opencodeDataDir = "${config.xdg.dataHome}/opencode";
  wrappedOpencode = pkgs.symlinkJoin {
    name = "opencode";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode \
        --set OPENCODE_DB opencode.db
    '';
  };
  opencodeConfig = baseOpencodeConfig // {
    plugin = map (
      plugin:
      if plugin == "oh-my-openagent@latest" then "file://${patchedOhMyOpenagent}" else plugin
    ) baseOpencodeConfig.plugin;
  };
in {
  xdg.enable = true;

  home.packages = [ wrappedOpencode ];

  home.sessionVariables = {
    OPENCODE_BASE_URL = "http://127.0.0.1:48317/v1";
    ALLYNX_BASE_URL = "http://127.0.0.1:48317/v1";
  };

  home.activation.ensureOpencodeDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 700 "${opencodeDataDir}"
  '';

  xdg.configFile = {
    "opencode/opencode.json".text = builtins.toJSON opencodeConfig;
    "opencode/oh-my-openagent.jsonc" = {
      force = true;
      source = ./opencode/oh-my-openagent.jsonc;
    };
    "opencode/dcp.json".source = ./opencode/dcp.json;
  };
}
