/** 1Password SSH agent and Git signing integration for Linux with the GUI app. */
{ lib, pkgs, ... }: {
  programs.git.extraConfig = {
    gpg.format = "ssh";

    "gpg \"ssh\"" = {
      program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
    };

    commit.gpgsign = true;

    user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
  };

  programs.ssh.matchBlocks."*".identityAgent = "~/.1password/agent.sock";
}
