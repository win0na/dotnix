/**
  1Password SSH agent and Git signing integration for WSL using the Windows host app.

  This relies on the Windows-side 1Password app and WSL integration. SSH requests are
  forwarded to Windows `ssh.exe`, and Git signing uses a wrapper that resolves the
  Windows-hosted `op-ssh-sign-wsl.exe` helper at runtime without hardcoding the username.
*/
{ pkgs, ... }:
let
  opSshSignWsl = pkgs.writeShellScript "op-ssh-sign-wsl" ''
    set -eu

    local_appdata_win="$(${pkgs.powershell}/bin/powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('LocalApplicationData')" | ${pkgs.coreutils}/bin/tr -d '\r')"
    local_appdata_wsl="$(wslpath "$local_appdata_win")"

    candidates="
      $local_appdata_wsl/1Password/app/8/op-ssh-sign-wsl.exe
      /mnt/c/Users/$USER/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe
      $(command -v op-ssh-sign-wsl.exe 2>/dev/null || true)
    "

    for candidate in $candidates; do
      if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        exec "$candidate" "$@"
      fi
    done

    echo "a.nix: could not locate op-ssh-sign-wsl.exe from WSL" >&2
    exit 1
  '';
in {
  programs.git.extraConfig = {
    gpg.format = "ssh";

    "gpg \"ssh\"" = {
      program = opSshSignWsl;
    };

    commit.gpgsign = true;

    core.sshCommand = "/mnt/c/Windows/System32/OpenSSH/ssh.exe";

    user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
  };
}
