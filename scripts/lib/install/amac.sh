#!/usr/bin/env bash
# a.mac installer flow

# install missing mac prerequisites, then run the darwin rebuild.
run_amac() {
  clone_or_update_repo
  collect_install_options "$ANIX_DEFAULT_USER" "$ANIX_DEFAULT_HOSTNAME_AMAC" "$ANIX_DEFAULT_GIT_DISPLAY_NAME" "$ANIX_DEFAULT_GIT_EMAIL" "$ANIX_DEFAULT_GIT_SIGNING_KEY" "$ANIX_DEFAULT_ROOT_SSH_AUTHORIZED_KEY" "__unset__" amac
  if ! have brew; then consent "install Homebrew?" || exit 1; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; fi
  if [[ -x /opt/homebrew/bin/brew ]]; then # shellcheck disable=SC1091
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then # shellcheck disable=SC1091
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "error: brew not found after installation" >&2; exit 1
  fi
  if ! have mas; then consent "install mas?" || exit 1; brew install mas; fi
  ensure_bootstrap_runner
  cat <<'EOF'
note: sign into the Mac App Store before running the rebuild.
note: brew and mas are installed only if missing.
note: Lix is preferred for the remaining bootstrap steps; plain Nix is only used if the Lix installer is unavailable.
EOF
  persist_install_options
  consent "run nix-darwin rebuild for a.mac?" || exit 1
  sudo env ANIX_INSTALL_OPTIONS_FILE="$ANIX_INSTALL_OPTIONS_FILE" nix --extra-experimental-features 'nix-command flakes' run "${repo_dir}#darwin-rebuild" -- --impure switch --flake "${repo_dir}#amac"
}
