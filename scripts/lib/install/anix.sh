#!/usr/bin/env bash
# a.nix installer flow

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

  local default_disko_disk generated_disko_override disko_disk
  default_disko_disk="$(default_anix_disko_disk)"
  if is_live_nixos_installer; then
    collect_install_options "winona" "a-nix" "winona" "winnie@winneon.moe" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ" "$default_disko_disk" anix
    have nixos-install || { echo "error: nixos-install is required in the live installer environment" >&2; exit 1; }
    if consent "run destructive disko for a.nix? this can ERASE ALL DATA on the selected disk by partitioning, formatting, and mounting it"; then
      disko_disk="${ANIX_INSTALL_DISKO_DEVICE:-$default_disko_disk}"
      ensure_block_device "$disko_disk"
      generated_disko_override="$(mktemp "${TMPDIR:-/tmp}/anix-disko-override.XXXXXX.nix")"
      trap 'rm -f "$generated_disko_override"' EXIT
      cat >"$generated_disko_override" <<EOF
{ diskoDevice = "$disko_disk"; }
EOF
      have nix || { echo "error: a working nix command is required to run disko in the live installer environment" >&2; exit 1; }
      sudo env ANIX_DISKO_OVERRIDE="$generated_disko_override" ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nix --extra-experimental-features 'nix-command flakes' --impure run github:nix-community/disko -- --mode disko --flake "${repo_dir}#anix"
    fi
    ensure_installer_mounts
    if [[ ! -f "$repo_dir/facter.json" ]]; then
      have_nix_command || { echo "error: a working nix command is required to generate facter.json" >&2; exit 1; }
      (cd "$repo_dir" && nix run github:numtide/nixos-facter -- --generate-hardware-config ./facter.json)
    fi
    consent "run nixos-install for a.nix?" || exit 1
    sudo env ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nixos-install --impure --flake "${repo_dir}#anix"
  else
    collect_install_options "winona" "a-nix" "winona" "winnie@winneon.moe" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ" "" anix
    have nixos-rebuild || { echo "error: nixos-rebuild is required on an installed NixOS system" >&2; exit 1; }
    consent "run nixos-rebuild switch for a.nix?" || exit 1
    sudo env ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nixos-rebuild switch --impure --flake "${repo_dir}#anix"
  fi
}
