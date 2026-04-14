/**
  Git SSH signing program wrapper.

  Git uses gpg.ssh.program for both signing and verification. 1Password's helper works
  for signing, while OpenSSH's ssh-keygen handles verification correctly.
*/
{
  lib,
  pkgs,
  signerProgram,
}:
pkgs.writeShellScript "git-ssh-program" ''
  set -eu

  mode=""
  prev=""

  for arg in "$@"; do
    if [ "$prev" = "-Y" ]; then
      mode="$arg"
      break
    fi

    prev="$arg"
  done

  case "$mode" in
    sign)
      exec ${signerProgram} "$@"
      ;;
    verify|find-principals|check-novalidate|match-principals)
      exec ${lib.getExe' pkgs.openssh "ssh-keygen"} "$@"
      ;;
    *)
      exec ${lib.getExe' pkgs.openssh "ssh-keygen"} "$@"
      ;;
  esac
''
