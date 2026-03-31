/** Root networking selector for the wnix host profiles. */
{ wnixMode, ... }: {
  imports = [
    ./common.nix
  ] ++ (if wnixMode == "bare" then [ ./bare.nix ] else [ ./wsl.nix ]);
}
