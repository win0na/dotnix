/** Bare-metal peripheral device integration and service overrides. */
{ lib, pkgs, ... }: {
  services = {
    solaar = {
      enable = true;
      extraArgs = "--restart-on-wake-up";
    };

    udev.extraRules = ''
      # dualsense usb & bt hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
      KERNEL=="hidraw*", KERNELS=="*054C:0CE6*", MODE="0660", TAG+="uaccess"

      # dualense edge usb & bt hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0660", TAG+="uaccess"
      KERNEL=="hidraw*", KERNELS=="*054C:0DF2*", MODE="0660", TAG+="uaccess"

      ACTION!="remove", SUBSYSTEMS=="usb", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="1028", MODE="0660", TAG+="uaccess"
    '';

    thermald.enable = true;
  };

  systemd.services.bluetooth = {
    overrideStrategy = "asDropin";

    serviceConfig = {
      ExecStartPost = "/bin/sh -c '${pkgs.coreutils}/bin/sleep 3; rfkill unblock bluetooth; ${pkgs.bluez}/bin/bluetoothctl power on'";
      ExecStart = lib.mkForce "\nExecStart=${pkgs.bluez}/libexec/bluetooth/bluetoothd --experimental -p input";
    };
  };

  systemd.settings.Manager.DefaultTimeoutStopSec = "5s";
}
