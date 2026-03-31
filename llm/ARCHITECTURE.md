# ARCHITECTURE.md

- `src/main.rs`: tokio entrypoint.
- `src/lib.rs`: command dispatch.
- `src/cli.rs`: clap CLI and subcommands.
- `src/state.rs`: root directory, `config.json` / `keys.json`, read/write helpers.
- `src/config.rs`: config schema and validation.
- `src/http_client.rs`: reqwest wrapper and upstream headers.
- `src/models.rs`: request/response types, model routing, text extraction.
- `src/oauth.rs`: login flow, callback listener, token exchange and refresh.
- `src/server.rs`: HTTP server and API routes.

## command flow

`setup` writes default state files. `login` opens Google OAuth, captures the callback on `127.0.0.1:57936`, exchanges the code, and stores tokens in `keys.json`. `ask` sends one prompt through the chat route. `serve` exposes OpenAI/Anthropic-compatible endpoints backed by Google Gemini.

## state files

- `config.json`: `CLIENT_ID`, `CLIENT_SECRET`, `REDIRECT_URI`
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
