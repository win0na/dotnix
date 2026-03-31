/** Root networking selector for the a.nix host profiles. */
{ hostProfile, ... }: {
  imports = [
    ./common.nix
  ] ++ (if hostProfile == "bare" then [ ./bare.nix ] else [ ./wsl.nix ]);
}
