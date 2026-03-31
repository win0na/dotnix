/** a.llynx package, service, and first-run guidance. */
{ pkgs, inputs, ... }:
let
  aLlynx = inputs.allynx.packages.${pkgs.system}.default;
in
{
  environment.systemPackages = [ aLlynx ];

  systemd.user.services.allynx = {
    description = "a.llynx service";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Environment = "ALLYNX_HOME=%h/.local/share/allynx";
      WorkingDirectory = "%h/.local/share/allynx";
      ExecStartPre = "${pkgs.coreutils}/bin/test -s %h/.local/share/allynx/keys.json";
      ExecStart = "${aLlynx}/bin/allynx serve --port 48317";
      Restart = "on-failure";
    };
  };

  environment.etc."profile.d/allynx-login.sh".text = ''
    export ALLYNX_HOME="$HOME/.local/share/allynx"
    if [ ! -s "$ALLYNX_HOME/keys.json" ]; then
      printf '%s\n' 'a.llynx: run "allynx setup" for the manual Google OAuth client steps.'
      printf '%s\n' 'a.llynx: use "allynx login --no-browser" for a pasted-code flow.'
      printf '%s\n' 'a.llynx: write CLIENT_ID and CLIENT_SECRET in config.json before login.'
      printf '%s\n' 'a.llynx: local api base url is http://127.0.0.1:48317/v1.'
      printf '%s\n' 'a.llynx: state will live in ~/.local/share/allynx.'
    fi
  '';
}
