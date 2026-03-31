/** ag-cli package, service, and first-run guidance. */
{ pkgs, lib, ... }:
let
  agCli = pkgs.callPackage ../../pkgs/ag-cli { };
in
{
  environment.systemPackages = [ agCli ];

  systemd.user.services.ag-cli = {
    description = "ag-cli service";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Environment = "AG_CLI_HOME=%h/.local/share/ag-cli";
      WorkingDirectory = "%h/.local/share/ag-cli";
      ExecStartPre = "${pkgs.coreutils}/bin/test -s %h/.local/share/ag-cli/keys.json";
      ExecStart = "${agCli}/bin/ag-cli serve --port 48317";
      Restart = "on-failure";
    };
  };

  environment.etc."profile.d/ag-cli-login.sh".text = ''
    export AG_CLI_HOME="$HOME/.local/share/ag-cli"
    if [ ! -s "$AG_CLI_HOME/keys.json" ]; then
      printf '%s\n' 'ag-cli: run "ag-cli setup" for the manual Google OAuth client steps.'
      printf '%s\n' 'ag-cli: use "ag-cli login --no-browser" for a pasted-code flow.'
      printf '%s\n' 'ag-cli: write CLIENT_ID and CLIENT_SECRET in config.json before login.'
      printf '%s\n' 'ag-cli: local api base url is http://127.0.0.1:48317/v1.'
      printf '%s\n' 'ag-cli: state will live in ~/.local/share/ag-cli.'
    fi
  ''; 
}
