/**
  1Password SSH agent and Git signing integration for WSL using the Windows host app.

  this relies on the Windows-side 1Password app and WSL integration. SSH and Git-over-SSH
  are forwarded to Windows `ssh.exe`, while Git commit signing uses the Windows-hosted
  `op-ssh-sign-wsl.exe` helper resolved at runtime without hardcoding the username.
 */
{ pkgs, gitSigningKey, ... }:
let
  windowsSsh = pkgs.writeShellScriptBin "ssh" ''
    set -eu
    exec /mnt/c/Windows/System32/OpenSSH/ssh.exe "$@"
  '';

  opSshSignWsl = pkgs.writeShellScript "op-ssh-sign-wsl" ''
    set -eu

    local_appdata_win="$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('LocalApplicationData')" | tr -d '\r')"
    local_appdata_wsl="$(wslpath "$local_appdata_win")"

    candidates=(
      "$local_appdata_wsl/1Password/app/8/op-ssh-sign-wsl.exe"
      "/mnt/c/Users/$USER/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe"
      "$(command -v op-ssh-sign-wsl.exe 2>/dev/null || true)"
    )

    for candidate in "''${candidates[@]}"; do
      if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        exec "$candidate" "$@"
      fi
    done

    echo "a.nix: could not locate op-ssh-sign-wsl.exe from WSL" >&2
    exit 1
  '';
in {
  home.packages = [ windowsSsh ];

  programs.git.extraConfig = {
    core.sshCommand = "${windowsSsh}/bin/ssh";
    gpg.format = "ssh";

    "gpg \"ssh\"" = {
      program = "${opSshSignWsl}";
    };

    commit.gpgsign = true;
    user.signingKey = gitSigningKey;
  };
}
