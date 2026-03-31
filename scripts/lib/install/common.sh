#!/usr/bin/env bash
# shared installer helpers

set -euo pipefail

install_script_url="https://raw.githubusercontent.com/win0na/a.nix/main/scripts/install-anix"
windows_resume_state_path='HKCU:\Software\win0na\a.nix'
windows_resume_state_name='apc-resume-pending'
anix_repo_remote_regex='(^|[[:space:]])(git@github\.com:|https://github\.com/|ssh://git@github\.com/)?win0na/a\.nix(\.git)?($|[[:space:]])'

# return success when a command exists on `PATH`.
have() { command -v "$1" >/dev/null 2>&1; }

# ask for yes/no consent and return 0 only for yes.
consent() {
  local prompt="$1" reply
  read -r -p "$prompt [y/N] " reply
  case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# check whether the current `nix` command is present.
have_nix_command() { have nix; }
# check whether the current `nix` command is backed by lix.
have_lix_runtime() { have nix && nix --version 2>/dev/null | grep -qi 'lix'; }
# probe the lix installer endpoint.
lix_installer_available() { curl -fsSI https://install.lix.systems/lix >/dev/null 2>&1; }

# install plain nix only when the lix installer is unavailable.
install_nix_fallback() {
  consent "Lix is unavailable online. install Nix instead?" || { echo "error: cannot continue without a working lix/nix install" >&2; exit 1; }
  sh <(curl -fsSL https://nixos.org/nix/install) --daemon
}

# ensure a working `nix` command exists and prefer upgrading it to lix.
ensure_bootstrap_runner() {
  if have_lix_runtime; then return 0; fi
  if have_nix_command && ! have_lix_runtime && ! lix_installer_available; then return 0; fi
  if lix_installer_available; then
    consent "install or upgrade to Lix for the remaining bootstrap steps?" || { echo "error: cannot continue without Lix while the Lix installer is available" >&2; exit 1; }
    curl -sSf -L https://install.lix.systems/lix | sh -s -- install
  else
    install_nix_fallback
  fi
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  fi
  have_nix_command || { echo "error: no working lix/nix install was found after bootstrap" >&2; exit 1; }
}

# run a powershell command through `powershell.exe` or `pwsh`.
run_ps() {
  if have powershell.exe; then powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$1"; elif have pwsh; then pwsh -NoProfile -Command "$1"; else return 1; fi
}

# run a powershell command, elevating with UAC when needed.
run_ps_admin() {
  local command="$1" escaped
  escaped=${command//\'/\'\'}
  run_ps "\
$ps = 'pwsh'
if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
  $ps = 'powershell.exe'
}
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Invoke-Expression '$escaped'
} else {
  Start-Process -FilePath $ps -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command','$escaped')
}
"
}

# record that windows should resume the apc bootstrap after sign-in.
set_windows_resume_marker() { run_ps "New-Item -Path '$windows_resume_state_path' -Force | Out-Null; New-ItemProperty -Path '$windows_resume_state_path' -Name '$windows_resume_state_name' -Value 1 -PropertyType DWord -Force | Out-Null"; }
# clear the windows apc resume marker.
clear_windows_resume_marker() { run_ps "Remove-ItemProperty -Path '$windows_resume_state_path' -Name '$windows_resume_state_name' -ErrorAction SilentlyContinue"; }
# report whether a windows apc resume marker is already set.
have_windows_resume_marker() { run_ps "if ((Get-ItemProperty -Path '$windows_resume_state_path' -Name '$windows_resume_state_name' -ErrorAction SilentlyContinue).'$windows_resume_state_name' -eq 1) { exit 0 } else { exit 1 }"; }

# return the default disk used by the bundled disko layout.
default_anix_disko_disk() { printf '%s\n' /dev/sda; }

# prompt for a value while showing a default that is accepted on ENTER.
prompt_default() {
  local prompt="$1" default_value="$2" value
  read -r -p "$prompt [${default_value}]: " value
  printf '%s\n' "${value:-$default_value}"
}

# collect install-time overrides into a temporary JSON file.
collect_install_options() {
  local default_user="$1" default_hostname="$2" default_git_display_name="$3" default_git_email="$4" default_git_signing_key="$5" default_root_key="$6" default_disk="${7:-}" selected_host_key="$8"
  local user git_display_name git_email hostname git_signing_key root_key extra_root_keys disk_device override_file extra_key

  user="$(prompt_default 'username' "$default_user")"
  git_display_name="$(prompt_default 'git display name' "$default_git_display_name")"
  git_email="$(prompt_default 'git email' "$default_git_email")"
  hostname="$(prompt_default 'hostname' "$default_hostname")"
  git_signing_key="$(prompt_default 'git signing ssh public key' "$default_git_signing_key")"
  root_key="$(prompt_default 'root ssh public key' "$default_root_key")"

  extra_root_keys=()
  while consent "add another root/admin ssh public key?"; do
    read -r -p "extra root ssh public key: " extra_key
    [[ -n "$extra_key" ]] && extra_root_keys+=("$extra_key")
  done

  disk_device=""
  if [[ -n "$default_disk" ]]; then
    disk_device="$(prompt_default 'target disk device' "$default_disk")"
  fi

  override_file="$(mktemp "${TMPDIR:-/tmp}/anix-install-options.XXXXXX.json")"
  trap 'rm -f "$override_file"' EXIT
  python3 - "$override_file" "$user" "$git_display_name" "$git_email" "$hostname" "$git_signing_key" "$selected_host_key" "$disk_device" "$root_key" "${extra_root_keys[@]}" <<'PY'
import json
import sys

out, user, git_name, git_email, hostname, signing_key, host_key, disk_device, root_key, *extra_keys = sys.argv[1:]
data = {
    "user": user,
    "gitDisplayName": git_name,
    "gitEmail": git_email,
    "gitSigningKey": signing_key,
    "rootSshAuthorizedKeys": [root_key, *[k for k in extra_keys if k]],
    "hostnames": {host_key: hostname},
}
if disk_device:
    data["diskoDevice"] = disk_device
with open(out, "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

  export ANIX_INSTALL_OPTIONS_FILE="$override_file"
  export ANIX_INSTALL_DISKO_DEVICE="$disk_device"
}
# stop unless the given path is a block device.
ensure_block_device() {
  [[ -b "$1" ]] || { echo "error: $1 is not a block device" >&2; exit 1; }
  [[ "$(lsblk -dnro TYPE "$1" 2>/dev/null || true)" == disk ]] || { echo "error: $1 is not a whole disk" >&2; exit 1; }
}

# return success when a path looks like a valid a.nix checkout.
is_valid_anix_checkout() {
  local path="${1:-}"
  [[ -n "$path" && -d "$path/.git" ]] || return 1
  if git -C "$path" remote get-url origin >/dev/null 2>&1; then
    git -C "$path" remote get-url origin | grep -Eq "$anix_repo_remote_regex" && return 0
  fi
  [[ -f "$path/flake.nix" && -f "$path/scripts/install-anix-local" ]]
}

# find a usable checkout without deleting or overwriting unrelated paths.
discover_anix_checkout() {
  local candidate
  for candidate in "${A_NIX_REPO:-}" "$PWD" "$HOME/a.nix" "${XDG_CACHE_HOME:-$HOME/.cache}/a.nix-bootstrap/repo"; do
    [[ -n "$candidate" ]] || continue
    if is_valid_anix_checkout "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if [[ -e "$HOME/a.nix" ]]; then
    echo "error: $HOME/a.nix exists but is not a valid a.nix checkout; set A_NIX_REPO or choose a different path" >&2
    exit 1
  fi
  printf '%s\n' "$HOME/a.nix"
}

# ensure the live installer mountpoints exist and are mounted.
ensure_installer_mounts() {
  mkdir -p /mnt /mnt/boot
  mountpoint -q /mnt || { echo "error: /mnt is not mounted; run disko or mount the target root filesystem first" >&2; exit 1; }
  mountpoint -q /mnt/boot || { echo "error: /mnt/boot is not mounted; run disko or mount the target boot filesystem first" >&2; exit 1; }
}

# detect the live nixos installer without treating installed systems as live media.
is_live_nixos_installer() {
  if [[ -r /etc/os-release ]] && grep -Eq '(^|_)installer($|=)|VARIANT_ID=installer|IMAGE_ID=.*installer' /etc/os-release; then return 0; fi
  [[ -z "${NIXOS_INSTALL_BOOT:-}" ]] && [[ ! -e /etc/NIXOS ]] && have nixos-install && [[ ! -e /run/current-system ]]
}
