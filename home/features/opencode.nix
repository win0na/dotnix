/** Declarative OpenCode configuration for NixOS Home Manager profiles. */
{ pkgs, ... }: {
  xdg.enable = true;

  home.packages = with pkgs; [ opencode ];

  home.sessionVariables = {
    OPENCODE_BASE_URL = "http://127.0.0.1:48317/v1";
    ALLYNX_BASE_URL = "http://127.0.0.1:48317/v1";
  };

  xdg.configFile = {
    "opencode/opencode.json".source = ./opencode/opencode.json;
    "opencode/oh-my-opencode.json".source = ./opencode/oh-my-opencode.json;
    "opencode/dcp.json".source = ./opencode/dcp.json;
  };
}
