/**
  1Password SSH agent and Git signing integration for macOS.
*/
{
  config,
  gitEmail,
  gitSigningKey,
  lib,
  pkgs,
  ...
}:
let
  gitSshProgram = import ./lib/git-ssh-program.nix {
    inherit lib pkgs;
    signerProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
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

  programs.ssh.matchBlocks."*".identityAgent =
    "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
}
