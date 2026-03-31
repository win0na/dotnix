# TEXT_STYLE.md

This file defines the default text style for the whole repository.

It applies to:
- markdown
- human-readable comments
- doc comments
- module docs
- llm-facing docs

Follow the normal documentation syntax and structure of the language you are writing in.
Keep the prose rules here unless a direct user instruction overrides them.

## prose

- use lowercase-first headings when that reads naturally
- write short declarative sentences
- keep prose direct, calm, and specific
- prefer concrete behavior over abstract summaries
- describe what a file or function does, what it reads or writes, what it calls, and any important limits
- avoid vague words like `wiring`, `foundation`, and `improves readability`
- keep explanations shorter than the commands or code they support
- prefer plain words over clever wording
- state assumptions directly
- prefer one idea per sentence or bullet

## code documentation

- follow the standard documentation syntax and structure for the language in use
- keep these prose rules for wording and tone inside that structure
- do not treat rust, nix, or any other language as a special case for prose style
- be concrete and concise
- keep file and function docs consistent within a module when that module benefits from docs
- mention state reads, state writes, side effects, endpoints, and key limits when they matter
- avoid trivial notes and repetitive restatements
- prefer clear naming and control flow over cleverness when code readability is at stake

## layout

- use short section names
- keep surrounding prose tight
- favor direct commands and examples over explanation
- put navigation near the top when the document is long enough to need it
- keep code blocks small and runnable
- label shell context explicitly inside a code block when it matters
- for documentation files, match the top title to the filename case-sensitively unless the file is `README.md`

## command blocks

- prefer one block per task
- declare variables near the top only when they genuinely reduce repetition
- avoid helper-tool assumptions when a more universal command exists
- keep inline comments sparse
- prefer comment lines above commands when context is required

## llm-facing docs

- keep exact file paths and direct references when they help understanding
- preserve useful context over stylistic minimalism when the tradeoff matters
- prefer explicit structure and durable facts over prose flow
- do not drop important context just to make a file shorter

## voice

- be direct
- be calm
- be specific
- do not sell the project
- do not pad the text
