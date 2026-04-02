# AGENTS.md

## purpose

this file defines the repo-wide defaults for human and ai contributors.

keep this file compact. it should contain only durable, repo-wide rules. put setup, install, rebuild, and workstation commands in `README.md`. put deeper llm-facing reference material in `llm/`.

## project overview

this repository contains **anix** (`/æ nɪx/`), a personal nixos + nix-darwin flake for one user (`winona`).

at a high level, the project manages three system outputs:
- `anix` — bare-metal nixos host `anix`
- `apc` — wsl2 / wslg nixos host `apc`
- `amac` — nix-darwin host `amac`

do not infer deep internals from this file alone. use:
- `README.md` for setup, install, rebuild, and bootstrap commands
- `TEXT_STYLE.md` for repo-wide text and documentation style rules
- `llm/ARCHITECTURE.md` for the broader repo/module map
- `llm/SESSION_WORKFLOW.md` for session flow and deeper context-loading guidance
- the relevant source files for deeper context

## working principles

these rules are intended to keep changes small, grounded, and easy to verify.

- prefer small, focused changes over broad rewrites
- match existing module boundaries before introducing new ones
- do not assume host behavior; read the relevant profile and shared modules first
- keep shared-vs-profile responsibilities clear
- if instructions conflict, prefer:
  1. direct user instructions
  2. the nearest nested `AGENTS.md`
  3. this root file

## token optimization

treat this file as the always-loaded minimum.

- keep only repo-wide, durable defaults here
- do not put long playbooks, temporary plans, or repeated file trees here
- prefer short trigger lists and exact file references over long prose
- avoid dumping large config excerpts when file paths are enough

## agent efficiency rules

use the smallest amount of context that still allows correct work.

- read only the files needed for the current task
- prefer targeted searches over broad repository dumps
- prefer fresh, scoped sessions over one long-lived chat for unrelated work
- write durable conclusions into repo files instead of relying on session memory
- summarize findings before making large changes
- reuse canonical commands from `README.md` instead of inventing alternatives
- when editing, preserve surrounding style and naming conventions
- when investigating, gather enough context to act correctly, then stop

## repository invariants

these are repo-wide facts worth preserving unless the user explicitly changes them.

- `flake.nix` exposes `anix`, `apc`, and `amac` outputs
- linux profile selection happens by separate flake outputs, not by editing a local mode variable
- cross-host system defaults live in `common/system.nix`
- cross-host Home Manager defaults live in `home/common.nix`
- wsl mirrored networking is configured from Windows via `%UserProfile%\.wslconfig`, not from the guest
- wsl 1Password signing must use the Windows-hosted helper path resolved from inside WSL
- OpenCode auth and runtime caches are intentionally unmanaged
- zsh is managed via Home Manager with oh-my-zsh and the vendored Headline theme
- linux hosts use `ollama-rocm`; darwin runs `ollama serve` via launchd

## safety baseline

these constraints apply across the repository, regardless of tool or workflow.

- never commit secrets, credentials, `.env` files, private keys, auth caches, or signing material
- never hand-edit generated artifacts if the project provides a generation path
- never use destructive git operations unless explicitly requested
- ask before changing flake outputs, deployment behavior, signing behavior, or destructive disk/install behavior
- if a required check cannot be run, say so explicitly instead of claiming success

## git conventions

all commits in this repository must be **signed and verified**.

- always create commits with `git commit -S`
- if Git signing is not configured or signing fails, **do not commit**
- fail with the real reason from Git or GPG/SSH signing output instead of bypassing signing
- do not use unsigned commits as a fallback
- never add co-author trailers, attribution footers, AI credit lines, or similar metadata unless explicitly requested
- do not include lines such as:
  - `Co-authored-by: ...`
  - `Generated-by: ...`
  - `Created-with: ...`
  - `AI-assisted-by: ...`
- keep commit messages clean and project-focused

### commit message format

use this format for short commits:

`topic(short scope): description`

examples:
- `nixos(networking): split bare and wsl routing`
- `home(zsh): add headline theme config`
- `docs(readme): simplify quickstart`

for larger commits, use the same first line, followed by short bullets and a final reasoning paragraph:

```text
topic(short scope): description

* change with short reasoning
* change with short reasoning
* change with short reasoning

Detailed change description & reasoning.
```

guidance:
- `topic` should describe the area of work clearly and briefly
- `scope` should name the primary file, directory, or subsystem
- keep the header concise and specific
- the body should explain why the change exists, not just restate the diff

## verification

before considering work complete, run the smallest relevant verification available for the change.

prefer this order:
1. targeted eval/build for affected host/output
2. formatting or linting for changed areas
3. broader rebuild/bootstrap validation only when needed

if local verification cannot be run in the current environment, say so explicitly.

## maintenance

update this file only when repo-wide rules change.

do not add one-off task instructions, temporary migration notes, or deep per-module details here.
