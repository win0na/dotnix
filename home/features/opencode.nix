/** Declarative OpenCode configuration for NixOS Home Manager profiles. */
{ pkgs, ... }: {
  xdg.enable = true;

  home.packages = with pkgs; [ opencode ];

  home.sessionVariables = {
    OPENCODE_BASE_URL = "http://127.0.0.1:8080/v1";
    ANTIGRAVITY_CLI_BASE_URL = "http://127.0.0.1:8080/v1";
  };

  xdg.configFile = {
    "opencode/opencode.json".source = ./opencode/opencode.json;
    "opencode/oh-my-opencode-slim.json".source = ./opencode/oh-my-opencode-slim.json;
  };
}
