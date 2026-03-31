/** Declarative OpenCode configuration for NixOS Home Manager profiles. */
{ pkgs, ... }: {
  xdg.enable = true;

  home.packages = with pkgs; [ opencode ];

  xdg.configFile = {
    "opencode/opencode.json".source = ./opencode/opencode.json;
    "opencode/oh-my-opencode-slim.json".source = ./opencode/oh-my-opencode-slim.json;
  };
}
