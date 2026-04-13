/**
  Shared user-scoped API key wiring for CLI and MCP consumers.
*/
{ config, lib, ... }:
let
  secretsHome = ../../secrets/home;
  apiKeysSopsFile = "${secretsHome}/api-keys.yaml";
  apiKeysTemplate = "anix-api-keys.env";
in
lib.mkIf (builtins.pathExists apiKeysSopsFile) {
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = apiKeysSopsFile;

    secrets = {
      tavily_api_key = { };
      brightdata_api_key = { };
      hf_token = { };
    };

    templates.${apiKeysTemplate} = {
      path = "%r/${apiKeysTemplate}";
      content = ''
        TAVILY_API_KEY=${config.sops.placeholder.tavily_api_key}
        BRIGHTDATA_API_KEY=${config.sops.placeholder.brightdata_api_key}
        HF_TOKEN=${config.sops.placeholder.hf_token}
      '';
    };
  };

  home.sessionVariables.ANIX_API_KEYS_ENV = config.sops.templates.${apiKeysTemplate}.path;
}
