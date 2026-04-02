/** Root NixOS selector for the anix host profiles. */
{ hostProfile, ... }: {
  imports = [
    ../common/system.nix
    ./common.nix
    ./networking/default.nix
    ./users.nix
    ./docker.nix
  ] ++ (if hostProfile == "bare" then [ ./profiles/bare/default.nix ] else [ ./profiles/wsl/default.nix ]);
}
