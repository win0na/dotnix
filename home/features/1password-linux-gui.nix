/**
  1Password SSH agent and Git signing integration for Linux with the GUI app.
*/
{
  lib,
  pkgs,
  gitSigningKey,
  ...
}:
let
  gitSshSigning = import ./lib/git-ssh-signing.nix;
in
{
  programs.git = gitSshSigning {
    inherit gitSigningKey;
    signerProgram = lib.getExe' pkgs._1password-gui "op-ssh-sign";
  };

  programs.ssh.matchBlocks."*".identityAgent = "~/.1password/agent.sock";
}
