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