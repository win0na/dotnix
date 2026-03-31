/** Bare-metal 1Password GUI integration and browser allowances. */
{ pkgs, user, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      _1password-gui = prev._1password-gui.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          substituteInPlace $out/share/applications/1password.desktop \
            --replace "Exec=1password" "Exec=1password --silent"
        '';
      });
    })
  ];

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ user ];
  };

  environment.systemPackages = with pkgs; [
    (makeAutostartItem {
      name = "1password";
      package = _1password-gui;
    })
  ];
}
