/** 1Password SSH agent and Git signing integration for macOS. */
{ ... }: {
  programs.git.extraConfig = {
    gpg.format = "ssh";

    "gpg \"ssh\"" = {
      program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };

    commit.gpgsign = true;

    user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClBpas/q9BP1YNEKQ1w7bHm2RjTJfIimOUWBHekHjoJ";
  };

  programs.ssh.matchBlocks."*".identityAgent =
    "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
}
