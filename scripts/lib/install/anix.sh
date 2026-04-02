#!/usr/bin/env bash
# anix installer flow

# run the bare-metal install or rebuild path.
# this may generate a temporary disko override file during live installs.
run_anix() {
  clone_or_update_repo
  if is_live_nixos_installer; then
    cat <<'EOF'
note: live NixOS installer detected.
note: if you choose disko, it can partition, format, and mount the target disk before nixos-install.
note: if you skip disko, the target filesystems must already be mounted at /mnt and /mnt/boot.
EOF
  fi

  local generated_disko_override disko_disk facter_report_path facter_report_tmp
  if is_live_nixos_installer; then
    collect_install_options "$ANIX_DEFAULT_USER" "$ANIX_DEFAULT_HOSTNAME_ANIX" "$ANIX_DEFAULT_GIT_DISPLAY_NAME" "$ANIX_DEFAULT_GIT_EMAIL" "$ANIX_DEFAULT_GIT_SIGNING_KEY" "$ANIX_DEFAULT_ROOT_SSH_AUTHORIZED_KEY" "__unset__" anix
    have nixos-install || { echo "error: nixos-install is required in the live installer environment" >&2; exit 1; }
    if consent "use destructive disko for anix? this can ERASE ALL DATA on the selected disk by partitioning, formatting, and mounting it"; then
      disko_disk="${ANIX_SELECTED_DISKO_DEVICE:-}"
      [[ -n "$disko_disk" ]] || disko_disk="$(prompt_required 'target disk device')"
      ensure_block_device "$disko_disk"
      printf 'note: selected disk: %s\n' "$(describe_block_device "$disko_disk")" >&2
      consent "run destructive disko on ${disko_disk}?" || exit 1
      generated_disko_override="$(mktemp "${TMPDIR:-/tmp}/anix-disko-override.XXXXXX.nix")"
      register_cleanup_path "$generated_disko_override"
      cat >"$generated_disko_override" <<EOF
{ diskoDevice = "$disko_disk"; }
EOF
      have nix || { echo "error: a working nix command is required to run disko in the live installer environment" >&2; exit 1; }
      sudo env ANIX_DISKO_OVERRIDE="$generated_disko_override" ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nix --extra-experimental-features 'nix-command flakes' --impure run "${repo_dir}#disko" -- --mode disko --flake "${repo_dir}#anix"
    fi
    ensure_installer_mounts
    persist_install_options "/mnt${anix_persistent_install_options_path}"
    facter_report_path="/mnt${anix_persistent_facter_report_path}"
    facter_report_tmp="$(mktemp "${TMPDIR:-/tmp}/anix-facter-report.XXXXXX.json")"
    register_cleanup_path "$facter_report_tmp"
    have_nix_command || { echo "error: a working nix command is required to generate facter.json" >&2; exit 1; }
    (cd "$repo_dir" && nix --extra-experimental-features 'nix-command flakes' run .#nixos-facter -- --generate-hardware-config "$facter_report_tmp")
    consent "run nixos-install for anix?" || exit 1
    sudo env ANIX_FACTER_REPORT_PATH="$facter_report_tmp" ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nixos-install --impure --flake "${repo_dir}#anix"
    sudo install -d -m755 "$(dirname "$facter_report_path")"
    sudo mv "$facter_report_tmp" "$facter_report_path"
    set_installed_passwords /mnt "$ANIX_SELECTED_USER"
  else
    collect_install_options "$ANIX_DEFAULT_USER" "$ANIX_DEFAULT_HOSTNAME_ANIX" "$ANIX_DEFAULT_GIT_DISPLAY_NAME" "$ANIX_DEFAULT_GIT_EMAIL" "$ANIX_DEFAULT_GIT_SIGNING_KEY" "$ANIX_DEFAULT_ROOT_SSH_AUTHORIZED_KEY" "__unset__" anix
    have nixos-rebuild || { echo "error: nixos-rebuild is required on an installed NixOS system" >&2; exit 1; }
    persist_install_options
    consent "run nixos-rebuild switch for anix?" || exit 1
    sudo env ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nixos-rebuild switch --impure --flake "${repo_dir}#anix"
  fi
}
