/**
  Disko entrypoint for `anix` installs.

  The default layout lives in `./default-disko.nix`. Live installs can point
  `ANIX_DISKO_OVERRIDE` at a generated file that overrides the disk device.
 */
{ lib, ... }:
let
  overridePath = builtins.getEnv "ANIX_DISKO_OVERRIDE";
  overrideArgs =
    if overridePath != "" && builtins.pathExists overridePath
    then import overridePath
    else { };
in import ./default-disko.nix ({ inherit lib; } // overrideArgs)
