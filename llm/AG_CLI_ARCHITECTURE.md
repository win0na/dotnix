# AG_CLI_ARCHITECTURE.md

- `pkgs/ag-cli/src/main.rs`: tokio entrypoint.
- `pkgs/ag-cli/src/lib.rs`: command dispatch.
- `pkgs/ag-cli/src/cli.rs`: clap CLI and subcommands.
- `pkgs/ag-cli/src/state.rs`: root directory, `config.json` / `keys.json`, read/write helpers, setup/status messaging.
- `pkgs/ag-cli/src/config.rs`: optional oauth override schema and safe defaults.
- `pkgs/ag-cli/src/http_client.rs`: reqwest wrapper and upstream headers.
- `pkgs/ag-cli/src/models.rs`: request/response types, model routing, text extraction.
- `pkgs/ag-cli/src/oauth.rs`: login flow, callback listener, token exchange and refresh.
- `pkgs/ag-cli/src/server.rs`: HTTP server and API routes.

## command flow

`setup` writes default state files and prints an assisted manual Google OAuth client setup guide. `login` requires `CLIENT_ID` and `CLIENT_SECRET` from `config.json`. Browser login opens the system browser and captures a loopback callback on a dynamic localhost port. `login --no-browser` prints an auth URL and exchanges a pasted authorization code. Both flows store tokens in `keys.json`. `ask` sends one prompt through the chat route. `serve` exposes OpenAI/Anthropic-compatible endpoints on `127.0.0.1:48317` by default and proxies them to Google Gemini.

## state files

- `config.json`: optional oauth overrides for `CLIENT_ID`, `CLIENT_SECRET`, and legacy `REDIRECT_URI`
- `keys.json`: per-account OAuth code, refresh token, access token, expiry, last auth failure time

## endpoints

- `GET /v1/models`
- `POST /v1/chat/completions`
- `POST /v1/messages`
- `POST /v1/responses`
- `GET /status`

## notes

- streaming is not implemented.
- tool use is rejected with `NOT_IMPLEMENTED`.
- auth retry is best-effort and persists refreshed keys when requests succeed.
- the built-in oauth scope set is `cloud-platform`, `userinfo.email`, and `userinfo.profile`.
