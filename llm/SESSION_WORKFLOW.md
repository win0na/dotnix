# SESSION_WORKFLOW.md

this file defines the preferred OpenCode session workflow for this repository.

use it with the root `AGENTS.md`, nested `AGENTS.md` files, `README.md`, and `llm/ARCHITECTURE.md`.

## goals

- keep sessions small, scoped, and easy to recover
- keep repo knowledge in files, not only in chat history
- use the nearest nested `AGENTS.md` before making local changes
- prefer the smallest verification that proves the change

## default session shape

use one fresh session per scoped task.

good scopes:
- clean up one subsystem such as `home/features/opencode/`
- refactor one boundary such as shared-vs-profile logic in `nixos/`
- update one host output such as `.#amac`
- revise one docs area such as `README.md` or `llm/`

avoid mixing unrelated work in one session.

## session types

### 1. discovery

use this to map a local area before changing it.

- read root `AGENTS.md`
- read the nearest nested `AGENTS.md`
- read only the smallest relevant architecture and source files
- search for direct references and current boundaries
- stop once the change surface is clear

output:
- a short task summary in chat
- if the task is non-trivial, a small plan in chat or a note under `llm/` when it should persist

### 2. planning

use this when the change touches multiple files or boundaries.

- define the exact scope
- name the files or directories that should change
- name the files that should not change
- identify the smallest useful verification

persist the plan in a file only when it will help later sessions.

good locations:
- `llm/` for durable notes or playbooks
- nearby docs when the decision changes local boundaries

### 3. implementation

keep implementation sessions narrow.

- reopen the nearest nested `AGENTS.md` before editing if the session is fresh
- change one subsystem at a time
- keep shared-vs-host responsibilities clear
- do not let the model infer host behavior without reading the relevant profile or host file
- if the task grows, stop and start a new scoped session

### 4. verification

follow the verification order from root `AGENTS.md`.

in practice, name the exact affected output or file area first and avoid broader checks unless they are needed.

if verification cannot run locally, say so explicitly and name the missing tool or environment.

### 5. documentation

after boundary changes:

- update the nearest nested `AGENTS.md` if local guidance changed
- update `llm/ARCHITECTURE.md` only for repo-map changes
- update `README.md` only for user-facing setup, rebuild, or deployment changes
- keep root `AGENTS.md` limited to durable repo-wide rules

## model routing

the default stack is GPT-centric.

these are current defaults, not permanent repo invariants.

### use gpt-5.4 for

- primary orchestration
- normal implementation
- repo-local reasoning that stays within one subsystem
- standard search, synthesis, and follow-up edits

### use gpt-5.4-mini for

- bounded exploration
- cheap search passes
- quick summarization before deeper work

### use claude lanes for

- difficult architecture choices
- deep refactors across module boundaries
- code review or maintainability review
- ambiguous cases where a second strong opinion is worth the cost

### keep gpt-5.3-codex as a fallback for

- narrow executor loops
- terminal-heavy coding tasks where GPT-5.4 stalls or over-explains

## context and compaction

dynamic context pruning is enabled to keep sessions healthy.

still prefer good session hygiene over relying on pruning.

- start fresh for new tasks
- compress after a milestone, not in the middle of unresolved reasoning
- protect durable memory by keeping important rules in files
- do not rely on chat history as the only source of project truth

important durable files include:
- `AGENTS.md`
- nested `AGENTS.md` files
- `llm/ARCHITECTURE.md`
- this file
- `TEXT_STYLE.md`
- `flake.nix`
- `common/system.nix`
- `home/common.nix`

## hierarchy rules

when entering a subtree:

1. read root `AGENTS.md`
2. read the nearest nested `AGENTS.md`
3. read the smallest relevant source files
4. only then plan or edit

if root and nested guidance differ, follow the nearest nested `AGENTS.md` unless the user says otherwise.

## refactor workflow for this repo

for cleanup or refactor work, use this sequence:

1. discovery session for one subtree
2. planning session if the change crosses boundaries
3. implementation session for one refactor slice
4. verification session against affected outputs
5. documentation session only if boundaries or durable rules changed

examples:
- `home/features/opencode/` cleanup: read `home/AGENTS.md` and `home/features/opencode/AGENTS.md`, then verify the declarative config files stay coherent
- `nixos/networking/` refactor: read `nixos/AGENTS.md`, then verify only the affected Linux output
- `darwin/` cleanup: read `darwin/AGENTS.md`, then verify only `.#amac`

## stop conditions

stop and rescope when:

- the task starts touching unrelated directories
- verification requires a different host or environment than expected
- the model is relying on old chat memory instead of current files
- the session is mostly summarizing old work instead of making progress

when that happens, write a short durable note if needed and start a new scoped session.
