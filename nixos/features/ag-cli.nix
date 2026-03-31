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
      ExecStart = "${agCli}/bin/ag-cli serve --port 8080";
      Restart = "on-failure";
    };
  };

  environment.etc."profile.d/ag-cli-login.sh".text = ''
    export AG_CLI_HOME="$HOME/.local/share/ag-cli"
    if [ ! -s "$AG_CLI_HOME/keys.json" ]; then
      printf '%s\n' 'ag-cli: run "ag-cli setup" and then "ag-cli login".'
      printf '%s\n' 'ag-cli: config and auth will live in ~/.local/share/ag-cli.'
    fi
  ''; 
}
