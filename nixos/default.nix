/** Root NixOS selector for the wnix host profiles. */
{ wnixMode, ... }: {
  imports = [
    ../common/system.nix
    ./common.nix
    ./networking/default.nix
    ./users.nix
    ./docker.nix
  ] ++ (if wnixMode == "bare" then [ ./profiles/bare/default.nix ] else [ ./profiles/wsl/default.nix ]);
}
