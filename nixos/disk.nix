/**
  Disko partition layout for nixos-anywhere deployments.

  To install, set the root password on the target (`sudo passwd root`) then run:

  ```
  SSHPASS="<TARGET_PASSWORD>" nix run github:nix-community/nixos-anywhere -- \
    --env-password \
    --generate-hardware-config nixos-facter ./facter.json \
    --flake .#anix \
    --target-host root@<IP_ADDRESS_OF_TARGET>
  ```

  This module is only imported by the `anix` bare-metal output in `flake.nix`.
 */
{ lib, ... }: {
  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";

      content = {
        type = "gpt";

        partitions = {
          boot = {
            name = "BOOT";
            size = "1M";
            type = "EF02";
          };

          efi = {
            name = "EFI";
            size = "500M";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            name  = "SWAP";
            size = "8G";
            type = "8200";

            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true;
            };
          };

          root = {
            name = "ROOT";
            size = "100%";

            content = {
              type = "btrfs";
              mountpoint = "/";

              mountOptions = [
                "compress=zstd"
                "noatime"
              ];
            };
          };
        };
      };
    };
  };
}
