/**
  VS Code tunnel helpers for WSL hosts.

  This keeps the normal `code` command available for the Windows-hosted Remote - WSL
  flow while exposing separate wrappers for remote tunnel login and service startup.
*/
{ lib, pkgs, ... }:
let
  cliDataDir = "$HOME/.local/state/vscode-tunnel/cli";
  tunnelStateDir = "$HOME/.local/state/vscode-tunnel";
  tunnelName = "apc";

  codeTunnel = pkgs.writeShellScriptBin "code-tunnel" ''
    set -eu
    umask 077

    ${pkgs.coreutils}/bin/install -d -m 700 "${tunnelStateDir}" "${cliDataDir}"

    exec ${pkgs.coreutils}/bin/env DONT_PROMPT_WSL_INSTALL=1 \
      ${pkgs.vscode}/bin/code tunnel \
      --accept-server-license-terms \
      --cli-data-dir "${cliDataDir}" \
      --name "${tunnelName}" \
      "$@"
  '';

  codeTunnelLogin = pkgs.writeShellScriptBin "code-tunnel-login" ''
    set -eu
    umask 077

    ${pkgs.coreutils}/bin/install -d -m 700 "${tunnelStateDir}" "${cliDataDir}"

    ${pkgs.coreutils}/bin/env DONT_PROMPT_WSL_INSTALL=1 \
      ${pkgs.vscode}/bin/code tunnel user login \
      --cli-data-dir "${cliDataDir}" \
      "$@"

    if ${pkgs.findutils}/bin/find "${cliDataDir}" -mindepth 1 -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
      ${pkgs.coreutils}/bin/touch "${tunnelStateDir}/authenticated"
      ${pkgs.coreutils}/bin/chmod 600 "${tunnelStateDir}/authenticated"

      if command -v systemctl >/dev/null 2>&1; then
        systemctl --user import-environment PATH >/dev/null 2>&1 || true
        systemctl --user restart vscode-tunnel.service >/dev/null 2>&1 || true
      fi

      printf '%s\n' 'anix: VS Code tunnel login stored in ~/.local/state/vscode-tunnel/cli.'
      printf '%s\n' 'anix: run `systemctl --user status vscode-tunnel.service` to check the tunnel.'
    else
      ${pkgs.coreutils}/bin/rm -f "${tunnelStateDir}/authenticated"
    fi
  '';
in
{
  home.packages = [
    codeTunnel
    codeTunnelLogin
  ];

  home.activation.importSystemdUserPath =
    lib.hm.dag.entryAfter [ "writeBoundary" ]
      ''
        if command -v systemctl >/dev/null 2>&1; then
          $DRY_RUN_CMD systemctl --user import-environment PATH >/dev/null 2>&1 || true
        fi
      '';

  systemd.user.services.vscode-tunnel = {
    Unit = {
      Description = "VS Code tunnel";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "%h/.local/state/vscode-tunnel/authenticated";
    };

    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 700 %h/.local/state/vscode-tunnel %h/.local/state/vscode-tunnel/cli";
      ExecStart = "${codeTunnel}/bin/code-tunnel";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
