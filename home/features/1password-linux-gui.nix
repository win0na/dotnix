/** 1Password SSH agent and Git signing integration for Linux with the GUI app. */
{ lib, pkgs, gitSigningKey, ... }: {
  programs.git.extraConfig = {
    gpg.format = "ssh";

    "gpg \"ssh\"" = {
      program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
    };

    commit.gpgsign = true;

    user.signingKey = gitSigningKey;
  };

  programs.ssh.matchBlocks."*".identityAgent = "~/.1password/agent.sock";
}
