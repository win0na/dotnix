/**
  Shared Git SSH signing settings used by the platform-specific 1Password features.
*/
{
  gitSigningKey,
  signerProgram,
  extraSettings ? { },
}:
{
  settings = extraSettings // {
    "gpg \"ssh\"".program = signerProgram;
  };

  signing = {
    format = "ssh";
    key = gitSigningKey;
    signByDefault = true;
  };
}
