#!/usr/bin/env bash
# shared installer helpers

set -euo pipefail

# shellcheck source=defaults.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/defaults.sh"

install_script_url="https://raw.githubusercontent.com/win0na/a.nix/main/scripts/install-anix"
anix_repo_url="https://github.com/win0na/a.nix.git"
anix_repo_tarball_url="https://github.com/win0na/a.nix/archive/refs/heads/main.tar.gz"
windows_resume_state_path='HKCU:\Software\win0na\a.nix'
windows_resume_state_name='apc-resume-pending'
anix_repo_remote_regex='(^|[[:space:]])(git@github\.com:|https://github\.com/|ssh://git@github\.com/)?win0na/a\.nix(\.git)?($|[[:space:]])'
anix_persistent_install_options_path='/etc/a.nix/install-options.json'
anix_persistent_facter_report_path='/etc/a.nix/facter.json'
ANIX_CLEANUP_PATHS=()
ANIX_SELECTED_DISKO_DEVICE=""
ANIX_SELECTED_USER=""

# return success when a command exists on `PATH`.
have() { command -v "$1" >/dev/null 2>&1; }

# remove registered temporary paths on shell exit.
cleanup_registered_paths() {
  local path
  for path in "${ANIX_CLEANUP_PATHS[@]:-}"; do
    [[ -n "$path" ]] && rm -rf -- "$path"
  done
}

# register a temporary file or directory for cleanup on exit.
register_cleanup_path() {
  ANIX_CLEANUP_PATHS+=("$1")
  trap cleanup_registered_paths EXIT
}

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
  exit $LASTEXITCODE
} else {
  $proc = Start-Process -FilePath $ps -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command','$escaped')
  exit $proc.ExitCode
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

# escape a string for safe embedding in JSON.
json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

# download a tarball checkout when git is unavailable.
download_repo_archive() {
  local target_dir="$1" tarball tmp_dir extracted_dir
  have curl || { echo "error: curl is required to download the a.nix bootstrap checkout" >&2; exit 1; }
  have tar || { echo "error: tar is required to extract the a.nix bootstrap checkout" >&2; exit 1; }
  mkdir -p "$(dirname "$target_dir")"
  tarball="$(mktemp "${TMPDIR:-/tmp}/anix-bootstrap.XXXXXX.tar.gz")"
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/anix-bootstrap.XXXXXX")"
  register_cleanup_path "$tarball"
  register_cleanup_path "$tmp_dir"
  curl -fsSL "$anix_repo_tarball_url" -o "$tarball"
  tar -xzf "$tarball" -C "$tmp_dir"
  extracted_dir="$tmp_dir/a.nix-main"
  [[ -d "$extracted_dir" ]] || { echo "error: unexpected archive layout while downloading a.nix" >&2; exit 1; }
  rm -rf -- "$target_dir"
  mv "$extracted_dir" "$target_dir"
}

# prompt for a value while showing a default that is accepted on ENTER.
prompt_default() {
  local prompt="$1" default_value="$2" value
  read -r -p "$prompt [${default_value}]: " value
  printf '%s\n' "${value:-$default_value}"
}

# prompt until a non-empty value is entered.
prompt_required() {
  local prompt="$1" value
  while :; do
    read -r -p "$prompt: " value
    [[ -n "$value" ]] && { printf '%s\n' "$value"; return 0; }
    echo "error: $prompt cannot be empty" >&2
  done
}

# stop unless the username is a safe local Unix account name.
ensure_safe_unix_username() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "error: username '$1' is not a safe Unix account name" >&2; exit 1; }
}

# collect install-time overrides into a temporary JSON file.
collect_install_options() {
  local default_user="$1" default_hostname="$2" default_git_display_name="$3" default_git_email="$4" default_git_signing_key="$5" default_root_key="$6" default_disk="${7-__unset__}" selected_host_key="$8"
  local user git_display_name git_email hostname git_signing_key root_key extra_root_keys disk_device override_file extra_key

  user="$(prompt_default 'username' "$default_user")"
  ensure_safe_unix_username "$user"
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
  if [[ "$default_disk" != "__unset__" ]]; then
    if [[ -n "$default_disk" ]]; then
      disk_device="$(prompt_default 'target disk device' "$default_disk")"
    else
      disk_device="$(prompt_required 'target disk device')"
    fi
  fi

  override_file="$(mktemp "${TMPDIR:-/tmp}/anix-install-options.XXXXXX.json")"
  register_cleanup_path "$override_file"
  {
    printf '{\n'
    printf '  "user": "%s",\n' "$(json_escape "$user")"
    printf '  "gitDisplayName": "%s",\n' "$(json_escape "$git_display_name")"
    printf '  "gitEmail": "%s",\n' "$(json_escape "$git_email")"
    printf '  "gitSigningKey": "%s",\n' "$(json_escape "$git_signing_key")"
    printf '  "rootSshAuthorizedKeys": ['
    printf '"%s"' "$(json_escape "$root_key")"
    for extra_key in "${extra_root_keys[@]}"; do
      printf ', "%s"' "$(json_escape "$extra_key")"
    done
    printf '],\n'
    printf '  "hostnames": { "%s": "%s" }\n' "$(json_escape "$selected_host_key")" "$(json_escape "$hostname")"
    printf '}\n'
  } >"$override_file"

  export ANIX_INSTALL_OPTIONS_FILE="$override_file"
  ANIX_SELECTED_DISKO_DEVICE="$disk_device"
  ANIX_SELECTED_USER="$user"
}
# stop unless the given path is a block device.
ensure_block_device() {
  [[ -b "$1" ]] || { echo "error: $1 is not a block device" >&2; exit 1; }
  [[ "$(lsblk -dnro TYPE "$1" 2>/dev/null || true)" == disk ]] || { echo "error: $1 is not a whole disk" >&2; exit 1; }
}

# print a short identity summary for a whole disk device.
describe_block_device() {
  lsblk -dnro PATH,SIZE,MODEL "$1" 2>/dev/null || printf '%s\n' "$1"
}

# return success when a path looks like a valid a.nix checkout.
is_valid_anix_checkout() {
  local path="${1:-}"
  [[ -n "$path" ]] || return 1
  if [[ -d "$path/.git" ]] && have git && git -C "$path" remote get-url origin >/dev/null 2>&1; then
    git -C "$path" remote get-url origin | grep -Eq "$anix_repo_remote_regex" && return 0
  fi
  [[ -f "$path/flake.nix" && -f "$path/scripts/install-anix-local" ]] || return 1
  [[ -d "$path/.git" ]] && return 0
  true
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

# ensure a usable checkout exists, cloning with git when available or downloading an archive otherwise.
ensure_anix_checkout() {
  local repo_dir="$1"
  if is_valid_anix_checkout "$repo_dir"; then
    if [[ -d "$repo_dir/.git" ]] && have git; then
      git -C "$repo_dir" pull --ff-only || echo "warning: failed to refresh $repo_dir; using existing checkout" >&2
    fi
    return 0
  elif [[ "$repo_dir" == "${XDG_CACHE_HOME:-$HOME/.cache}/a.nix-bootstrap/repo" ]]; then
    download_repo_archive "$repo_dir"
  elif have git; then
    git clone "$anix_repo_url" "$repo_dir"
  else
    download_repo_archive "$repo_dir"
  fi
}

# persist the current install options for future impure rebuilds.
persist_install_options() {
  local target_path="${1:-$anix_persistent_install_options_path}"
  [[ -n "${ANIX_INSTALL_OPTIONS_FILE:-}" && -f "$ANIX_INSTALL_OPTIONS_FILE" ]] || return 0
  if [[ "$(id -u)" -eq 0 ]]; then
    install -Dm644 "$ANIX_INSTALL_OPTIONS_FILE" "$target_path"
  else
    sudo install -Dm644 "$ANIX_INSTALL_OPTIONS_FILE" "$target_path"
  fi
}

# prompt to configure mirrored WSL networking from Windows and update .wslconfig if approved.
configure_windows_mirrored_networking() {
  local ps_script
  consent "configure mirrored networking in %UserProfile%\\.wslconfig now?" || { echo "note: skipping mirrored networking setup." >&2; return 0; }
  ps_script="$(cat <<'EOF'
$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
$lines = if (Test-Path $wslConfig) { [System.Collections.Generic.List[string]](Get-Content -Path $wslConfig) } else { [System.Collections.Generic.List[string]]::new() }

$sectionIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*\[wsl2\]\s*$') {
    $sectionIndex = $i
    break
  }
}

if ($sectionIndex -lt 0) {
  if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') {
    $lines.Add('') | Out-Null
  }
  $lines.Add('[wsl2]') | Out-Null
  $sectionIndex = $lines.Count - 1
}

$sectionEnd = $lines.Count
for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*\[.*\]\s*$') {
    $sectionEnd = $i
    break
  }
}

function Set-AnixWslKey([string]$key, [string]$value) {
  $foundIndex = -1
  for ($j = $sectionIndex + 1; $j -lt $sectionEnd; $j++) {
    if ($lines[$j] -match "^\s*$([regex]::Escape($key))\s*=") {
      if ($foundIndex -lt 0) {
        $lines[$j] = "$key=$value"
        $foundIndex = $j
      } else {
        $lines.RemoveAt($j)
        $j--
        $sectionEnd--
      }
    }
  }
  if ($foundIndex -lt 0) {
    $lines.Insert($sectionEnd, "$key=$value")
    $sectionEnd++
  }
}

Set-AnixWslKey 'networkingMode' 'Mirrored'
Set-AnixWslKey 'dnsTunneling' 'true'

try {
  Set-Content -Path $wslConfig -Value $lines
  & wsl.exe --shutdown | Out-Null
} catch {
  exit 1
}
EOF
)"
  if run_ps "$ps_script"; then
    echo "note: mirrored networking has been configured from Windows via %UserProfile%\\.wslconfig." >&2
  else
    echo "warning: failed to configure mirrored networking in %UserProfile%\\.wslconfig; continuing without it" >&2
  fi
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

# offer interactive password setup inside an installed target system without persisting secrets.
set_installed_passwords() {
  local target_root="$1" user="$2"
  have nixos-enter || { echo "warning: nixos-enter is unavailable; skipping password prompts" >&2; return 0; }

  if consent "set a root password now? this is entered interactively and is not saved anywhere"; then
    sudo nixos-enter --root "$target_root" -c 'passwd root'
  fi

  if [[ -n "$user" ]] && consent "set a password for ${user} now? this is entered interactively and is not saved anywhere"; then
    sudo nixos-enter --root "$target_root" -c "passwd ${user@Q}"
  fi
}
