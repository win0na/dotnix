/**
  Shared Git SSH signing settings used by the platform-specific 1Password features.
*/
{
  gitSigningKey,
  signerProgram,
  extraSettings ? { },
}:
{
  settings = extraSettings;

  signing = {
    format = "ssh";
    key = gitSigningKey;
    signByDefault = true;
    signer = signerProgram;
  };
}
