#!/usr/bin/env bash
# a.pc installer flow

# register a one-shot windows resume command for post-reboot apc bootstrap.
register_windows_runonce_resume() {
  local resume_cmd
  resume_cmd="wsl.exe -d NixOS --exec env A_NIX_APC_RESUME=1 bash -lc \"curl -fsSL ${install_script_url} -o /tmp/install-anix && chmod +x /tmp/install-anix && /tmp/install-anix a.pc\""
  run_ps "Set-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce' -Name 'a.nix-apc-resume' -Value '$resume_cmd' -Force"
}

# clear the one-shot windows resume command.
clear_windows_runonce_resume() { run_ps "Remove-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce' -Name 'a.nix-apc-resume' -ErrorAction SilentlyContinue" || true; }

# run the windows bootstrap path or the nixos-wsl rebuild path.
run_apc() {
  if [[ -z "${WSL_DISTRO_NAME:-}" && ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    A_NIX_KEEP_APC_RESUME_MARKER=0
    trap 'if [[ "${A_NIX_KEEP_APC_RESUME_MARKER:-0}" != 1 ]]; then clear_windows_resume_marker || true; clear_windows_runonce_resume || true; fi' EXIT
    have powershell.exe || have pwsh || { echo "error: apc bootstrap from Windows requires powershell.exe or pwsh" >&2; exit 1; }
    cat <<'EOF'
note: Windows-side bootstrap detected.
note: the script will install WSL2 and NixOS-WSL if you confirm.
note: it can also configure mirrored networking in %UserProfile%\.wslconfig if you confirm.
note: Windows may show a UAC prompt for the WSL installation steps.
EOF
    configure_windows_mirrored_networking
    if have_windows_resume_marker; then echo "note: resuming an interrupted APC bootstrap from Windows." >&2; clear_windows_resume_marker || true; clear_windows_runonce_resume || true; fi
    consent "install WSL2 and NixOS-WSL on Windows now? this may require a reboot before the guest is usable" || exit 1
    set_windows_resume_marker || true
    register_windows_runonce_resume || true
    run_ps "\$tmp = Join-Path \$env:TEMP 'nixos.wsl'; Invoke-WebRequest -Uri 'https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl' -OutFile \$tmp" || { echo "error: failed to download nixos.wsl" >&2; exit 1; }
    run_ps_admin "wsl --install --no-distribution" || { A_NIX_KEEP_APC_RESUME_MARKER=1; echo "note: WSL installation reported a restart is required; Windows should resume this installer after you sign back in." >&2; exit 1; }
    run_ps_admin "wsl --install --from-file \"\$env:TEMP\\nixos.wsl\"" || { A_NIX_KEEP_APC_RESUME_MARKER=1; echo "note: NixOS-WSL installation reported a restart or manual completion is required; Windows should try to resume after sign-in." >&2; exit 1; }
    run_ps "wsl -d NixOS --exec /bin/sh -lc 'printf ready'" >/dev/null 2>&1 || { A_NIX_KEEP_APC_RESUME_MARKER=1; echo "note: the NixOS-WSL guest is not ready yet; sign back into Windows, start NixOS-WSL, then rerun this script inside the guest if it does not continue automatically." >&2; exit 1; }
    consent "launch the installer inside the NixOS-WSL guest now?" || { echo "note: rerun this script inside NixOS-WSL after the guest starts." >&2; exit 0; }
    A_NIX_KEEP_APC_RESUME_MARKER=0
    clear_windows_resume_marker || true; clear_windows_runonce_resume || true
    run_ps "wsl -d NixOS --exec bash -lc 'curl -fsSL ${install_script_url} -o /tmp/install-anix && bash /tmp/install-anix a.pc'"
    exit $?
  fi

  if [[ "${A_NIX_APC_RESUME:-}" == 1 ]]; then clear_windows_resume_marker || true; clear_windows_runonce_resume || true; echo "note: resumed APC bootstrap is now continuing inside NixOS-WSL." >&2; fi
  clone_or_update_repo
  collect_install_options "$ANIX_DEFAULT_USER" "$ANIX_DEFAULT_HOSTNAME_APC" "$ANIX_DEFAULT_GIT_DISPLAY_NAME" "$ANIX_DEFAULT_GIT_EMAIL" "$ANIX_DEFAULT_GIT_SIGNING_KEY" "$ANIX_DEFAULT_ROOT_SSH_AUTHORIZED_KEY" "__unset__" apc
  have nixos-rebuild || { echo "error: nixos-rebuild is required inside the NixOS-WSL guest" >&2; exit 1; }
  persist_install_options
  cat <<'EOF'
note: running inside the NixOS-WSL guest.
note: if needed, mirrored networking is configured from Windows via the bootstrap prompt and %UserProfile%\.wslconfig.
EOF
  consent "run nixos-rebuild switch for a.pc?" || exit 1
  sudo env ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nixos-rebuild switch --impure --flake "${repo_dir}#apc"
}
