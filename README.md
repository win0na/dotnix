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

## vscode on apc

`apc` uses two separate VS Code paths.

### local wsl development from windows

install VS Code on Windows.
enable its PATH integration.
install the Remote - WSL extension.

then from a WSL shell in your project:

```sh
code .
```

`apc` does not install the Linux `code` launcher in WSL.
the `code` command should come from Windows interop.

### remote tunnel access

`apc` exposes a separate tunnel wrapper so the normal `code` command stays reserved for the Windows-hosted WSL flow.

after rebuilding `.#apc`, log in once from WSL with the same GitHub or Microsoft account you will use on the client side:

```sh
code-tunnel-login --provider github
systemctl --user status vscode-tunnel.service
```

once logged in, the declarative user service will keep the tunnel available while the WSL instance is running.
you can then connect from `vscode.dev` or from VS Code with the Remote - Tunnels extension.

to reset the tunnel state, stop the user service and remove the saved CLI state:

```sh
systemctl --user stop vscode-tunnel.service
rm -rf ~/.local/state/vscode-tunnel
```

## secrets

api keys are wired through `sops-nix` in Home Manager.

the repo expects a runtime shell fragment at `ANIX_API_KEYS_ENV`, generated from `secrets/home/api-keys.yaml` when that encrypted file exists.

bootstrap each host with an age key:

```sh
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

then:

1. replace the placeholder recipients in `.sops.yaml` with the public age keys for `anix`, `apc`, and `amac`
2. copy `secrets/home/api-keys.example.yaml` to `secrets/home/api-keys.yaml`
3. run `sops secrets/home/api-keys.yaml`
4. fill in `tavily_api_key`, `brightdata_api_key`, `hf_token`, and `openrouter_api_key`
5. rebuild the target host with `sw` or the matching rebuild command above

the generated env file is sourced automatically by zsh. plaintext secrets are not committed, and secret values are not stored in Nix expressions.
that env fragment currently exports `TAVILY_API_KEY`, `BRIGHTDATA_API_KEY`, `HF_TOKEN`, and `OPENROUTER_API_KEY`.

## notable bits

- `anix` uses disko in the live-installer `anix` flow with an explicit destructive confirmation prompt
- `apc` requires mirrored networking from windows via `%UserProfile%\.wslconfig`:

  ```ini
  [wsl2]
  networkingMode=Mirrored
  dnsTunneling=true
  ```
- `apc` can bootstrap from Windows first, then continue inside the NixOS-WSL guest
- installer SSH authorized keys are shared across root and the primary NixOS user on linux hosts
- `amac` checks for brew, mas, and nix/lix before rebuilding
- `anix` and `apc` use `ollama-rocm`
- `amac` runs `ollama serve` via launchd
- api keys can be provisioned through `sops-nix` as a user-scoped shell env file
- Hermes uses a shared declarative `~/.hermes` config on all hosts; linux hosts use the official Hermes NixOS module with state rooted in the login user's home, and `amac` uses the standard Hermes CLI workflow with declarative config plus `hermes gateway install` for launchd
- opencode config is declarative; auth and runtime caches are intentionally unmanaged
- zsh is managed through home manager with oh-my-zsh + the headline theme
