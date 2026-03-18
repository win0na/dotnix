# dotnix

.nix, my custom nix-darwin & NixOS configuration.

| Host | Platform | Purpose |
|------|----------|---------|
| **wnix** | NixOS (`x86_64-linux`) | Desktop + gaming (KDE Plasma, Steam, Gamescope) |
| **wmac** | nix-darwin (`x86_64-darwin`) | macOS build server (Xcode, Homebrew) |

Both hosts use [Lix](https://lix.systems) as their Nix implementation and share common configuration through `shared_config.nix` and `shared_home.nix`.

## Prerequisites

- [Nix](https://nixos.org/download/) or [Lix](https://lix.systems/install/) with flakes enabled
- For **wmac**: macOS with [Homebrew](https://brew.sh) and [nix-darwin](https://github.com/nix-darwin/nix-darwin), signed into the Mac App Store
- For **wnix**: a target machine reachable via SSH (for remote deploys)

## Manual Deployment

### NixOS (wnix)

From the repository root on the target machine:

```sh
sudo nixos-rebuild switch --flake .#wnix
```

### nix-darwin (wmac)

From the repository root on the target Mac:

```sh
sudo darwin-rebuild switch --flake .#wmac
```

## Automatic Deployment (nixos-anywhere)

The NixOS host can be deployed to a fresh machine remotely using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere). This will partition the disk (via [disko](https://github.com/nix-community/disko)), install NixOS, and apply the full configuration in one step.

### 1. Prepare the target

Boot the target machine into any NixOS installer image, then set a root password:

```sh
sudo passwd root
```

### 2. Deploy from the source machine

```sh
SSHPASS="<TARGET_PASSWORD>" nix run github:nix-community/nixos-anywhere -- \
  --env-password \
  --generate-hardware-config nixos-facter ./facter.json \
  --flake .#wnix \
  --target-host root@<IP_ADDRESS_OF_TARGET>
```

This will:
1. Partition the target disk according to `nixos/disk.nix` (GPT with EFI, swap, and btrfs root).
2. Generate a `facter.json` hardware report and copy it back to your local repo.
3. Install NixOS with the full `wnix` configuration.

After the first deploy, commit the generated `facter.json` so subsequent rebuilds can reference the hardware configuration.

## Automatic Deployment (nix-darwin)

On a fresh Mac with the prerequisites installed, clone the repo and apply the configuration in one command:

```sh
git clone https://github.com/win0na/dotnix.git ~/wmac && \
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/wmac#wmac
```

This will bootstrap nix-darwin and apply the full `wmac` configuration.

Subsequent rebuilds can use the `sw` alias, or `sudo darwin-rebuild switch --flake ~/wmac#wmac`.

## Day-to-Day Commands

| Task | Command |
|------|---------|
| Rebuild NixOS | `sudo nixos-rebuild switch --flake .#wnix` |
| Rebuild macOS | `sudo darwin-rebuild switch --flake .#wmac` |
| Format all Nix files | `nix fmt` |
| Update all flake inputs | `nix flake update` |
| Upgrade Mac App Store apps | `mas upgrade` |

The shell alias `sw` is also defined for both hosts, running the appropriate rebuild command with `--show-trace`.

## Repository Structure

```
flake.nix            Entry point: inputs, outputs, host definitions
shared_config.nix    System config shared across hosts (Lix, overlays, packages)
shared_home.nix      Home Manager config shared across hosts (git, ssh, vscode, zsh)
darwin/
  config.nix         wmac system: homebrew, dock, launchd, Xcode tooling
  home.nix           wmac home-manager (imports shared_home.nix)
nixos/
  config.nix         wnix system: boot, hardware, KDE, gaming, services
  home.nix           wnix home-manager: zen-browser, dconf, mime types
  disk.nix           Disko partition layout for nixos-anywhere
  firmware/brcm/     Broadcom firmware blobs for Apple hardware
```