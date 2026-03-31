/** Root Home Manager selector for the wnix host profiles. */
{ wnixMode, ... }: {
  imports = [
    ../../home/common.nix
    ../../home/features/opencode.nix
  ] ++ (if wnixMode == "bare" then [
    ./profiles/bare.nix
    ../../home/features/1password-linux-gui.nix
  ] else [
    ./profiles/wsl.nix
    ../../home/features/1password-wsl.nix
  ]);
}
