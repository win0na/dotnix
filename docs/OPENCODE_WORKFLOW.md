# OPENCODE_WORKFLOW.md

this file is the human-facing guide for using OpenCode on this repository.

it does not restate the full agent workflow. that lives in `llm/SESSION_WORKFLOW.md`.

use this file to decide how to scope work, when to start over, when to intervene, and what to ask the model to verify.

<p>
  <a href="#what-this-doc-is-for">what this doc is for</a> •
  <a href="#when-to-start-a-new-session">new session</a> •
  <a href="#how-to-ask-for-work-well">asking well</a> •
  <a href="#when-to-intervene">intervene</a> •
  <a href="#verification-expectations">verification</a> •
  <a href="#prompt-templates">templates</a>
</p>

## what this doc is for

use this file when you need to decide how to drive the session.

use `llm/SESSION_WORKFLOW.md` when you want the model to follow the repo's preferred session rules.

## when to start a new session

start a new session when the scope changes.

common triggers:
- new subsystem
- new host or flake output
- new goal
- stale or degraded context
- a verified milestone is complete

examples:
- start a new session when moving from `home/features/opencode/` cleanup to `nixos/networking/` refactor
- start a new session when moving from `.#apc` work to `.#amac` work
- start a new session after a verified docs update if the next task is a darwin config change

do not keep one long session alive just because it still has history.

## how to ask for work well

good requests name four things:
- scope
- exclusions
- verification target
- expected output

example: scoped refactor

```text
Refactor only `home/features/opencode/`.
Read root `AGENTS.md`, `home/AGENTS.md`, and `home/features/opencode/AGENTS.md` first.
Do not change unrelated Home Manager features.
Verify the config files in that directory stay coherent.
Return a short summary of changed files and any checks you could not run.
```

example: host-specific fix

```text
Fix the darwin-only issue in `darwin/config.nix`.
Do not change linux or shared modules unless the current layout makes that necessary.
Read `darwin/AGENTS.md` first.
Verify only the darwin output if possible.
```

example: docs-only task

```text
Docs-only task.
Update `README.md` and `docs/OPENCODE_WORKFLOW.md` only.
Do not change Nix modules unless the docs would otherwise become false.
Tell me which statements you validated against current files.
```

example: review-only pass

```text
Review `nixos/networking/` for cleanup opportunities.
Do not edit files.
Return concrete findings, risks, and a proposed edit plan.
```

## how to use the hierarchy

tell the model which local guidance to read before it edits.

minimum:
- `AGENTS.md`
- the nearest nested `AGENTS.md`
- only the smallest relevant source files

add these only when needed:
- `llm/ARCHITECTURE.md` for repo-map questions
- `README.md` for setup, rebuild, or deployment commands
- `TEXT_STYLE.md` for docs or comment edits

examples:
- `home/features/opencode/` task: point to `AGENTS.md`, `home/AGENTS.md`, `home/features/opencode/AGENTS.md`
- `nixos/` task: point to `AGENTS.md`, `nixos/AGENTS.md`, then the affected profile or shared module
- `darwin/` task: point to `AGENTS.md`, `darwin/AGENTS.md`, then the affected darwin file

## when to intervene

intervene when the model drifts away from the task you asked for.

common signs:
- it starts touching unrelated directories
- it relies on old chat memory instead of current files
- it broadens the task without asking
- it gives vague completion claims without naming checks
- it starts repeating investigation instead of making progress

examples:
- if you asked for `home/features/opencode/` cleanup and it starts editing `darwin/home.nix`, stop it
- if it says "done" without naming the affected output or checks, ask for exact verification
- if it keeps summarizing prior attempts, start a new scoped session

example intervention prompt:

```text
Stop widening scope.
Limit work to `nixos/networking/` only.
Re-read `nixos/AGENTS.md` and summarize the exact files you still need to touch before editing again.
```

## review vs implementation

ask for review first when the change surface is not yet clear.

good cases for review-first:
- cross-boundary refactors
- unclear ownership between shared and host-specific modules
- cleanup requests that may turn into behavior changes
- documentation audits

examples:
- ask for review first before moving logic from `darwin/` into `home/common.nix`
- ask for review first before deduplicating `nixos/` and `home/` behavior across hosts
- ask for review first when you suspect dead config but are not sure whether it is still referenced

example review-first prompt:

```text
Review `nixos/networking/` and adjacent shared modules for cleanup opportunities.
Do not edit yet.
Tell me what is safe to simplify, what may change behavior, and what should stay where it is.
```

ask for implementation directly when the boundary is already clear.

example:
- updating only `docs/OPENCODE_WORKFLOW.md`
- fixing one known bad path in `darwin/config.nix`
- keeping `home/features/opencode/` config files aligned after a known plugin change

## verification expectations

expect the model to say what it verified and what it could not verify.

good completion report:
- names changed files
- names the exact output or check used
- says what could not run locally
- separates facts from assumptions

bad completion report:
- "done"
- "everything looks good"
- "should work now" without naming checks

example good report:

```text
Changed:
- `home/features/opencode/opencode.json`
- `home/features/opencode/oh-my-openagent.jsonc`

Verified:
- both JSON files parse successfully

Not verified:
- Home Manager activation was not run in this environment
```

example follow-up if the report is weak:

```text
Be specific.
List the files you changed, the checks you actually ran, and anything you could not verify.
```

## repo-specific reminders

### `home/features/opencode/`

keep these coherent:
- `opencode.nix`
- `opencode.json`
- `oh-my-openagent.jsonc`
- `dcp.json`

example ask:

```text
Clean up `home/features/opencode/` only.
Keep the declarative Nix file and the config JSON files coherent.
Do not change unrelated Home Manager features.
```

### `nixos/`

read the affected profile before changing shared linux modules.

example ask:

```text
Refactor `nixos/networking/` only.
Read the affected profile first so you do not infer host behavior.
Verify only the affected Linux output if possible.
```

### `darwin/`

keep darwin-specific behavior separate from linux shared modules.

example ask:

```text
Fix the issue in `darwin/config.nix`.
Keep the change darwin-local unless the current design clearly belongs in a shared home module.
```

### cross-boundary work

plan first.

example ask:

```text
Plan a cleanup that touches `home/` and `nixos/`.
Do not edit yet.
Show the boundary decisions first, then propose the smallest safe implementation slices.
```

## prompt templates

### bounded cleanup

```text
Clean up only `home/features/opencode/`.
Read the relevant AGENTS files first.
Do not widen scope.
Return the exact files changed and the checks you ran.
```

### architecture review

```text
Review whether this logic belongs in `darwin/`, `home/common.nix`, or a feature module.
Do not edit files.
Give me a recommendation, tradeoffs, and the smallest safe next step.
```

### verify-first follow-up

```text
Before any more edits, tell me what you already changed, what is still unverified, and the next smallest useful check.
```

### reset-and-rescope

```text
Start fresh.
Scope this session to `nixos/networking/` only.
Ignore prior broad cleanup plans unless they are still visible in current files.
```
