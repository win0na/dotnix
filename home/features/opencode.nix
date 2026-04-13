/** Declarative OpenCode configuration for NixOS Home Manager profiles. */
{ pkgs, ... }:
let
  patchedOhMyOpenagent = import ./opencode/oh-my-openagent-patched.nix { inherit pkgs; };
  baseOpencodeConfig = builtins.fromJSON (builtins.readFile ./opencode/opencode.json);
  opencodeConfig = baseOpencodeConfig // {
    plugin = map (
      plugin:
      if plugin == "oh-my-openagent@latest" then "file://${patchedOhMyOpenagent}" else plugin
    ) baseOpencodeConfig.plugin;
  };
in {
  xdg.enable = true;

  home.packages = with pkgs; [ opencode ];

  home.sessionVariables = {
    OPENCODE_BASE_URL = "http://127.0.0.1:48317/v1";
    ALLYNX_BASE_URL = "http://127.0.0.1:48317/v1";
  };

  xdg.configFile = {
    "opencode/opencode.json".text = builtins.toJSON opencodeConfig;
    "opencode/oh-my-openagent.jsonc" = {
      force = true;
      source = ./opencode/oh-my-openagent.jsonc;
    };
    "opencode/dcp.json".source = ./opencode/dcp.json;
  };
}
