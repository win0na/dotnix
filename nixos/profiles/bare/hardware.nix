/** Bare-metal hardware, GPU, and bluetooth settings. */
{ lib, ... }: {
  hardware = {
    enableRedistributableFirmware = true;

    amdgpu.initrd.enable = false;

    bluetooth = {
      enable = true;
      powerOnBoot = true;

      input.General = {
        UserspaceHID = true;
        ClassicBondedOnly = false;
        IdleTimeout = 30;
      };

      settings = {
        General = {
          ControllerMode = "dual";
          DiscoverableTimeout = 0;
          FastConnectable = true;
          Experimental = true;
          KernelExperimental = lib.mkForce true;
        };

        Policy.AutoEnable = true;
      };
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    enableAllFirmware = true;
  };
}
