/**
  1Password SSH agent and Git signing integration for Linux with the GUI app.
*/
{
  config,
  lib,
  pkgs,
  gitEmail,
  gitSigningKey,
  ...
}:
let
  gitSshProgram = import ./lib/git-ssh-program.nix {
    inherit lib pkgs;
    signerProgram = lib.getExe' pkgs._1password-gui "op-ssh-sign";
  };
  gitSshSigning = import ./lib/git-ssh-signing.nix;
  allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
in
{
  home.file.".config/git/allowed_signers".text = ''
    ${gitEmail} ${gitSigningKey}
  '';

  programs.git = gitSshSigning {
    inherit allowedSignersFile gitSigningKey;
    signerProgram = "${gitSshProgram}";
  };

  programs.ssh.matchBlocks."*".identityAgent = "~/.1password/agent.sock";
}
