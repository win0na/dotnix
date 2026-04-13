# ARCHITECTURE.md

this file is the repo map for `anix`.

read it when you need to orient on structure, ownership, and config entrypoints.

use `README.md` for setup, rebuild, and deploy commands.

## hosts and outputs

`flake.nix` exposes three host outputs.

| host | platform | flake attr | role |
|---|---|---|---|
| `anix` | NixOS on `x86_64-linux` | `.#anix` | bare-metal desktop and gaming host |
| `apc` | NixOS on WSL2 / WSLg | `.#apc` | Windows-backed build host |
| `amac` | nix-darwin on `x86_64-darwin` | `.#amac` | macOS build server |

linux host selection happens by separate flake outputs.

`flake.nix` builds linux hosts through `mkANixSystem hostProfile hostname`.

the linux selector in `nixos/default.nix` chooses `./profiles/bare/` or `./profiles/wsl/` from `hostProfile`.

the darwin path is separate and starts at `darwin/config.nix`.

install-time identity, hostnames, and shared SSH authorized keys flow through `installOptions` in `flake.nix`.

`flake.nix` seeds `installOptions` from `scripts/lib/install/defaults.sh`, then merges overrides from `ANIX_INSTALL_OPTIONS_FILE` when present.

if that variable is unset, `flake.nix` falls back to `/etc/anix/install-options.json`.

## filesystem tree

this tree is selective.

it shows the paths that define repo structure and ownership.

```text
.
├── flake.nix                    # outputs, shared args, and host composition
├── .sops.yaml                   # sops creation rules and age recipients
├── AGENTS.md                    # repo-wide rules and invariants
├── README.md                    # setup, rebuild, deploy, and host summary
├── TEXT_STYLE.md                # prose rules for docs and comments
├── common/
│   ├── AGENTS.md                # shared cross-host guidance
│   └── system.nix               # cross-host system defaults
├── home/
│   ├── AGENTS.md                # shared Home Manager guidance
│   ├── common.nix               # cross-host Home Manager defaults
│   └── features/
│       ├── AGENTS.md            # feature module rules
│       ├── 1password-darwin.nix # darwin 1Password feature
│       ├── 1password-linux-gui.nix
│       ├── 1password-wsl.nix
│       ├── api-keys.nix         # shared user API key wiring via sops-nix
│       ├── opencode.nix         # OpenCode feature entrypoint
│       ├── opencode/            # repo-managed OpenCode config JSON files
│       ├── zsh.nix              # shared shell feature
│       └── zsh/                 # paired zsh assets such as the theme
├── nixos/
│   ├── AGENTS.md                # linux boundary rules
│   ├── default.nix              # root linux selector
│   ├── common.nix               # shared linux defaults
│   ├── users.nix                # linux user setup
│   ├── docker.nix               # linux docker setup
│   ├── disk.nix                 # disko entrypoint for `.#anix`
│   ├── default-disko.nix        # default disk layout
│   ├── networking/              # shared, bare, and WSL networking split
│   ├── features/                # linux-only feature modules such as `allynx`
│   ├── home/                    # linux Home Manager selector and profile imports
│   └── profiles/
│       ├── bare/                # bare-metal modules: boot, desktop, gaming, audio
│       └── wsl/                 # WSL-specific profile
├── darwin/
│   ├── AGENTS.md                # darwin boundary rules
│   ├── config.nix               # nix-darwin system entrypoint
│   ├── home.nix                 # darwin Home Manager entrypoint
│   └── gruvbox.png              # darwin wallpaper asset
├── scripts/
│   ├── install-anix             # cached remote bootstrap entrypoint
│   ├── install-anix-local       # host detection and local installer dispatcher
│   ├── install-anix.sh          # minimal shell shim to `install-anix-local`
│   ├── install-apc.ps1          # Windows bootstrap for `apc`
│   └── lib/install/             # shared installer logic and per-host flows
├── docs/
│   └── OPENCODE_WORKFLOW.md     # human-facing OpenCode session guide
├── secrets/
│   └── home/                    # encrypted or example user secret manifests
└── llm/
    ├── ARCHITECTURE.md          # this repo map
    └── SESSION_WORKFLOW.md      # LLM session and verification flow
```

## module boundaries

`common/system.nix` owns system defaults shared by linux and darwin.

`home/common.nix` owns Home Manager defaults shared by linux and darwin.

`home/features/` owns opt-in user features and any paired config assets.

`nixos/` owns linux-only composition.

inside `nixos/`, networking, features, Home Manager selection, and host profiles stay split by concern.

`nixos/home/default.nix` imports shared home defaults and linux Home Manager features, then adds bare-only or WSL-only home features.

that includes `home/features/opencode.nix` for linux profiles.

`darwin/home.nix` does not currently import the OpenCode feature.

`nixos/profiles/bare/default.nix` fans out into the bare-metal slices such as `boot.nix`, `desktop.nix`, `gaming.nix`, and `virtualization.nix`.

`nixos/profiles/wsl/default.nix` owns WSL-specific guest behavior and assumes mirrored networking comes from Windows `.wslconfig`.

`darwin/config.nix` and `darwin/home.nix` own macOS behavior and stay separate from linux modules.

nested `AGENTS.md` files reinforce these ownership lines.

## environment variables

this section covers repo-relevant environment variables and session variables.

it omits prompt-internal shell state and unrelated theme internals.

### build-time inputs

| variable | source | function |
|---|---|---|
| `ANIX_INSTALL_OPTIONS_FILE` | `flake.nix`, installer scripts | JSON override path for install options; fallback is `/etc/anix/install-options.json` |
| `ANIX_FACTER_REPORT_PATH` | `flake.nix`, `scripts/lib/install/anix.sh` | hardware report path for bare-metal installs; fallback is `/etc/anix/facter.json` |
| `ANIX_DISKO_OVERRIDE` | `nixos/disk.nix`, `scripts/lib/install/anix.sh` | path to a generated nix file that overrides the target disk for disko |

### installer defaults and runtime state

| variable | source | function |
|---|---|---|
| `ANIX_DEFAULT_USER` | `scripts/lib/install/defaults.sh` | default install username parsed by `flake.nix` |
| `ANIX_DEFAULT_GIT_DISPLAY_NAME` | `scripts/lib/install/defaults.sh` | default git display name parsed by `flake.nix` |
| `ANIX_DEFAULT_GIT_EMAIL` | `scripts/lib/install/defaults.sh` | default git email parsed by `flake.nix` |
| `ANIX_DEFAULT_GIT_SIGNING_KEY` | `scripts/lib/install/defaults.sh` | default git signing key parsed by `flake.nix` |
| `ANIX_DEFAULT_SSH_AUTHORIZED_KEY` | `scripts/lib/install/defaults.sh` | default shared SSH authorized key parsed by `flake.nix` |
| `ANIX_DEFAULT_HOSTNAME_ANIX` | `scripts/lib/install/defaults.sh` | default hostname for `.#anix` |
| `ANIX_DEFAULT_HOSTNAME_APC` | `scripts/lib/install/defaults.sh` | default hostname for `.#apc` |
| `ANIX_DEFAULT_HOSTNAME_AMAC` | `scripts/lib/install/defaults.sh` | default hostname for `.#amac` |
| `ANIX_CLEANUP_PATHS` | `scripts/lib/install/common.sh` | list of temporary installer paths removed on shell exit |
| `ANIX_SELECTED_DISKO_DEVICE` | `scripts/lib/install/common.sh` | selected target disk carried through the bare-metal install flow |
| `ANIX_SELECTED_USER` | `scripts/lib/install/common.sh` | selected install user carried through password prompts and later steps |
| `ANIX_REPO` | `scripts/lib/install/common.sh` | optional override path for locating an existing `anix` checkout |
| `ANIX_APC_RESUME` | `scripts/lib/install/apc.sh` | marks that the APC install resumed inside the NixOS-WSL guest |
| `ANIX_KEEP_APC_RESUME_MARKER` | `scripts/lib/install/apc.sh` | keeps or clears the Windows resume marker during APC bootstrap |

### repo-declared runtime variables

| variable | source | function |
|---|---|---|
| `EDITOR` | `home/common.nix` | sets the default editor to `nvim` |
| `ANIX_API_KEYS_ENV` | `home/features/api-keys.nix` | points shells at the runtime-generated `sops-nix` env file for API keys |
| `OPENCODE_BASE_URL` | `home/features/opencode.nix` | points OpenCode at the local `a.llynx` API endpoint |
| `ALLYNX_BASE_URL` | `home/features/opencode.nix` | points `a.llynx` clients at the local API endpoint |
| `ALLYNX_HOME` | `nixos/features/allynx.nix` | exported through the `a.llynx` service and login profile script to set the `a.llynx` state directory |
| `STEAM_EXTRA_COMPAT_TOOLS_PATHS` | `nixos/profiles/bare/gaming.nix` | exposes extra Steam compatibility tool paths on the bare profile |
| `STEAM_MULTIPLE_XWAYLANDS` | `nixos/profiles/bare/gaming.nix` | enables multiple Xwayland instances for Steam on the bare profile |
| `ENABLE_GAMESCOPE_WSI` | `nixos/profiles/bare/gaming.nix` | enables Gamescope WSI on the bare profile |
| `PROTON_ENABLE_AMD_AGS` | `nixos/profiles/bare/gaming.nix` | enables AMD AGS for Proton on the bare profile |
| `PROTON_ENABLE_NVAPI` | `nixos/profiles/bare/gaming.nix` | enables NVAPI for Proton on the bare profile |
| `PROTON_USE_NTSYNC` | `nixos/profiles/bare/gaming.nix` | enables ntsync for Proton on the bare profile |
| `LD_LIBRARY_PATH` | `nixos/profiles/bare/gaming.nix` | exposes OpenGL driver paths needed by Steam on the bare profile |

### external runtime inputs used by scripts

| variable | source | function |
|---|---|---|
| `HOME` | bootstrap scripts, `README.md` examples | default root for checkout discovery and example paths such as `$HOME/anix` |
| `PWD` | `scripts/lib/install/common.sh` | current working directory checked during checkout discovery |
| `XDG_CACHE_HOME` | bootstrap scripts | cache root for the downloaded bootstrap checkout |
| `TMPDIR` | installer scripts | temporary file root for generated install files and archives |
| `WSL_DISTRO_NAME` | `scripts/lib/install/apc.sh`, shell logic | detects whether execution is already inside WSL |
| `NIXOS_INSTALL_BOOT` | `scripts/lib/install/common.sh` | helps detect the live NixOS installer environment |
| `USERPROFILE` | Windows bootstrap scripts | path to the Windows user profile and `%UserProfile%\.wslconfig` |
| `TEMP` | Windows bootstrap scripts | Windows temp directory used to stage `nixos.wsl` |
| `PATH` | `darwin/config.nix` activation script | makes nix, Homebrew, and system binaries visible during darwin activation |
| `SSHPASS` | `README.md` deploy example | passes the target password to `nixos-anywhere` |

`README.md` also documents shell variables such as `targetHost` and `targetPassword` for the deploy example.

those are example shell locals, not repo-managed environment variables.

these generic runtime inputs matter to the install and deploy flows, but they are less central than the repo-declared variables above.

## doc hierarchy

use the docs by responsibility.

- `AGENTS.md`: repo-wide rules, invariants, and safety limits
- `common/AGENTS.md`: cross-host system guidance for `common/`
- `home/AGENTS.md`: shared Home Manager boundaries
- `home/features/AGENTS.md`: feature module rules
- `home/features/opencode/AGENTS.md`: OpenCode-specific coherence rules
- `nixos/AGENTS.md`: linux composition boundaries
- `darwin/AGENTS.md`: darwin-local boundaries
- `README.md`: setup, rebuild, deploy, and user-facing host summary
- `TEXT_STYLE.md`: prose rules for docs and comments
- `docs/OPENCODE_WORKFLOW.md`: human-facing OpenCode session guide
- `llm/SESSION_WORKFLOW.md`: preferred LLM session flow and verification shape
- `llm/ARCHITECTURE.md`: this repo map

## flake inputs

these inputs shape the repo more than the rest.

| input | role |
|---|---|
| `nixpkgs` | base package set for all outputs |
| `nix-darwin` | macOS system composition for `.#amac` |
| `home-manager` | user environment composition for linux and darwin |
| `sops-nix` | runtime secret provisioning for Home Manager |
| `nixos-wsl` | WSL support for `.#apc` |
| `disko` | disk layout and install flow for `.#anix` |
| `nixos-facter` and `nixos-facter-modules` | hardware report generation and import for bare-metal installs |
| `jovian` | SteamOS and gaming support for the bare profile |
| `nix-flatpak` | flatpak integration for the bare profile |
| `mise-nix` | plugin source wired into `home/common.nix` for the shared mise setup |
| `allynx` | local API service used by OpenCode-related config |
| `nix-vscode-extensions` | overlay used in shared system defaults |

## maintenance

update this file when the tree changes, when a new flake output appears, or when env vars move or gain new meaning.

keep commands in `README.md`.

keep repo rules in `AGENTS.md` and nested `AGENTS.md` files.

keep session flow in `llm/SESSION_WORKFLOW.md`.
