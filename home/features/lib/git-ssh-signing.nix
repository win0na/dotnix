/**
  Shared Git SSH signing settings used by the platform-specific 1Password features.
*/
{
  gitSigningKey,
  signerProgram,
  allowedSignersFile ? null,
  extraSettings ? { },
}:
{
  settings =
    extraSettings
    // (
      if allowedSignersFile == null then { } else { gpg.ssh.allowedSignersFile = allowedSignersFile; }
    );

  signing = {
    format = "ssh";
    key = gitSigningKey;
    signByDefault = true;
    signer = signerProgram;
  };
}
