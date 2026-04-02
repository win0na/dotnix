# opencode

this directory owns the repo-managed OpenCode configuration.

- keep `opencode.json`, `oh-my-opencode.json`, and `dcp.json` coherent
- prefer `gpt-5.4` as the default GPT lane
- reserve claude lanes for harder architecture, review, and deep refactor work
- optimize for bounded sessions and durable file-based memory, not immortal chat state
- if plugin names or compatibility rules change upstream, update this directory and `home/features/opencode.nix` together
