/** Home Manager configuration shared by the NixOS and nix-darwin users. */
{ pkgs, user, email, inputs, ... }: {
  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.file.".local/share/mise/plugins/nix".source = inputs.mise-nix;

  home.activation.miseInstallLatestNode =
    let
      miseBin = "${pkgs.mise}/bin/mise";
    in
      pkgs.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "$HOME/.config/mise/config.toml" ] || ! grep -q '^[[:space:]]*node[[:space:]]*=' "$HOME/.config/mise/config.toml"; then
          run "$miseBin use -g node@latest"
        fi
      '';

  programs = {
    home-manager.enable = true;

    mise = {
      enable = true;
      package = pkgs.mise;
      enableZshIntegration = true;
    };

    git = {
      enable = true;

      userName = user;
      userEmail = email;
      ignores = [ "._*" ];

      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };

    nix-index.enable = true;

    ssh = {
      enable = true;
      enableDefaultConfig = false;
    };

    vscode = {
      enable = true;
      package = pkgs.vscode;

      profiles.default.extensions = with pkgs.vscode-marketplace; [
        bbenoist.nix
        nowsci.glassit-linux
      ];
    };

    zsh = {
      enable = true;

      shellAliases = {
        node-install-latest = "mise use -g node@latest";
        sw = "sudo ${if pkgs.stdenv.isDarwin then "darwin" else "nixos"}-rebuild switch --flake $HOME/$HOST --show-trace";
        vim = "nvim";
      };
    };
  };
}
