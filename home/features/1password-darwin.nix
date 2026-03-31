/** 1Password SSH agent and Git signing integration for macOS. */
{ gitSigningKey, ... }: {
  programs.git.extraConfig = {
    gpg.format = "ssh";

    "gpg \"ssh\"" = {
      program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };

    commit.gpgsign = true;

    user.signingKey = gitSigningKey;
  };

  programs.ssh.matchBlocks."*".identityAgent =
    "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
}
