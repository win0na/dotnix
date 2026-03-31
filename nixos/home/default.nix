/** Root Home Manager selector for the a.nix host profiles. */
{ hostProfile, ... }: {
  imports = [
    ../../home/common.nix
    ../../home/features/opencode.nix
  ] ++ (if hostProfile == "bare" then [
    ./profiles/bare.nix
    ../../home/features/1password-linux-gui.nix
  ] else [
    ./profiles/wsl.nix
    ../../home/features/1password-wsl.nix
  ]);
}
