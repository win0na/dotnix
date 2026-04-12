<div align="center">

# anix

`/æ nɪx/`

a nixos + nix-darwin flake for `anix`, `apc`, and `amac`.

linux. wsl2. macos. one repo.

<p>
  <a href="#quickstart">quickstart</a> •
  <a href="#rebuild">rebuild</a> •
  <a href="#deploy">deploy</a> •
  <a href="#common-commands">common commands</a>
</p>

</div>

## what it manages

| host | platform | flake attr | role |
|------|----------|------------|------|
| `anix` | nixos (`x86_64-linux`) | `.#anix` | bare-metal desktop + gaming host |
| `apc` | nixos (`x86_64-linux`) on wsl | `.#apc` | wsl2 / wslg build host |
| `amac` | nix-darwin (`x86_64-darwin`) | `.#amac` | macos build server |

all hosts use [lix](https://lix.systems), with [nix](https://github.com/NixOS/nix) as a fallback.

## quickstart

```sh
# linux & macos
curl -fsSL "https://raw.githubusercontent.com/win0na/anix/main/scripts/install-anix" | bash
```

```powershell
# windows 11
irm "https://raw.githubusercontent.com/win0na/anix/main/scripts/install-apc.ps1" | iex
```

### llm install (copy/paste)

```text
Fetch and run this bootstrap script:
https://raw.githubusercontent.com/win0na/anix/main/scripts/install-anix
```

## rebuild

use `sw` where the alias exists.

if all else fails:

```sh
# in anix's working directory (def: $HOME/anix)
sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/anix/install-options.json nixos-rebuild switch --impure --flake .#anix
sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/anix/install-options.json nixos-rebuild switch --impure --flake .#apc
sudo env ANIX_INSTALL_OPTIONS_FILE=/etc/anix/install-options.json darwin-rebuild switch --impure --flake .#amac
```

## deploy

### anix (via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere))

```sh
# on the target machine:

# boot into a nixos installer and set a root password.
sudo passwd root

# note the ipv4/6 address before continuing
ip addr
```

```sh
# on the source machine:

# set the following variables.
targetHost="root@<IP_ADDRESS_OF_TARGET>"
targetPassword="<TARGET_PASSWORD>"

# this path assumes the target install disk matches nixos/default-disko.nix.
# verify the disk path yourself before installing.

# then run:
tmpDir="$(mktemp -d)/anix"
facterReport="$(mktemp)"
git clone https://github.com/win0na/anix.git "$tmpDir" && cd "$tmpDir"
SSHPASS="$targetPassword" nix run github:nix-community/nixos-anywhere -- \
  --env-password \
  --generate-hardware-config nixos-facter "$facterReport" \
  --flake .#anix \
  --target-host "$targetHost"
```

## common commands

```sh
nix fmt                 # format nix files
nix flake update        # update flake inputs
mas upgrade             # upgrade app store apps on amac
```

## notable bits

- `anix` uses disko in the live-installer `anix` flow with an explicit destructive confirmation prompt
- `apc` requires mirrored networking from windows via `%UserProfile%\.wslconfig`:

  ```ini
  [wsl2]
  networkingMode=Mirrored
  dnsTunneling=true
  ```
- `apc` can bootstrap from Windows first, then continue inside the NixOS-WSL guest
- `amac` checks for brew, mas, and nix/lix before rebuilding
- `anix` and `apc` use `ollama-rocm`
- `amac` runs `ollama serve` via launchd
- opencode config is declarative; auth and runtime caches are intentionally unmanaged
- zsh is managed through home manager with oh-my-zsh + the headline theme
