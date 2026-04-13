/**
  1Password SSH agent and Git signing integration for macOS.
*/
{ gitSigningKey, ... }:
let
  gitSshSigning = import ./lib/git-ssh-signing.nix;
in
{
  programs.git = gitSshSigning {
    inherit gitSigningKey;
    signerProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  };

  programs.ssh.matchBlocks."*".identityAgent =
    "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
}
