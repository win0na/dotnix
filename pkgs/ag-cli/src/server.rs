use anyhow::{anyhow, Result};
use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use std::{future::IntoFuture, net::SocketAddr};
use tokio::net::TcpListener;

use crate::{
    config,
    http_client::HttpClient,
    models::*,
    oauth::refresh_account,
    state::{get_valid_accounts, keys_path, AppState},
};

pub const DEFAULT_PORT: u16 = 48317;

/// bind the local api server and serve the configured routes.
pub async fn serve(state: AppState, port: u16) -> Result<()> {
    let app = app(state.clone());
    let addr: SocketAddr = ([127, 0, 0, 1], port).into();
    println!("serving on http://{addr}");
    axum::serve(TcpListener::bind(addr).await?, app)
        .into_future()
        .await?;
    Ok(())
}

pub fn app(state: AppState) -> Router {
    Router::new()
        .route("/v1/models", get(v1_models))
        .route("/v1/chat/completions", post(v1_chat_completions))
        .route("/v1/messages", post(v1_messages))
        .route("/v1/responses", post(v1_responses))
        .route("/status", get(v1_status))
        .with_state(state)
}

/// send one prompt through the chat route and print the response status.
pub async fn ask(state: &AppState, prompt: String) -> Result<()> {
    let response = route_chat(
        state,
        ChatRequest {
            model: Some("default".to_owned()),
            messages: vec![ChatMessage {
                role: "user".to_owned(),
                content: serde_json::Value::String(prompt),
            }],
            stream: None,
        },
    )
    .await?;
    println!("{}", response.status());
    Ok(())
}

/// list the model aliases exposed by the local api.
async fn v1_models() -> impl IntoResponse {
    let data = MODEL_ROUTES
        .iter()
        .map(|(requested, upstream)| {
            serde_json::json!({
                "id": requested,
                "object": "model",
                "owned_by": "ag-cli",
                "aliases": [upstream],
            })
        })
        .collect::<Vec<_>>();
    Json(serde_json::json!({"data": data}))
}
/// report config and account counts without exposing token values.
async fn v1_status(State(state): State<AppState>) -> impl IntoResponse {
    let keys = get_valid_accounts(&state).await.unwrap_or_default();
    let usable_cfg = config::load_config(&state.root).await.is_ok();
    let usable_accounts = keys
        .accounts
        .iter()
        .filter(|account| account.access_token.is_some())
        .count();
    Json(serde_json::json!({
        "configured": usable_cfg,
        "accounts": keys.accounts.len(),
        "usable_accounts": usable_accounts,
    }))
}
/// handle openai-compatible chat completion requests.
async fn v1_chat_completions(
    State(state): State<AppState>,
    Json(body): Json<ChatRequest>,
) -> Response {
    route_chat(&state, body)
        .await
        .unwrap_or_else(openai_route_error)
}
/// handle anthropic messages requests.
async fn v1_messages(State(state): State<AppState>, Json(body): Json<MessageRequest>) -> Response {
    route_messages(&state, body)
        .await
        .unwrap_or_else(anthropic_route_error)
}
/// handle openai responses requests.
async fn v1_responses(
    State(state): State<AppState>,
    Json(body): Json<ResponsesRequest>,
) -> Response {
    route_responses(&state, body)
        .await
        .unwrap_or_else(responses_route_error)
}

fn openai_route_error(err: anyhow::Error) -> Response {
    let (status, message) = route_error_status_message(&err);
    (status, Json(openai_error(message, "upstream_error", None))).into_response()
}
fn anthropic_route_error(err: anyhow::Error) -> Response {
    let (status, message) = route_error_status_message(&err);
    (status, Json(anthropic_error(message, "upstream_error"))).into_response()
}
fn responses_route_error(err: anyhow::Error) -> Response {
    let (status, message) = route_error_status_message(&err);
    (status, Json(responses_error(message, "upstream_error"))).into_response()
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RequestFailure {
    Auth,
    Quota,
    Transient,
    Hard,
}

fn not_implemented(message: &str) -> Response {
    (
        StatusCode::NOT_IMPLEMENTED,
        Json(openai_error(
            message,
            "not_implemented",
            Some("not_implemented"),
        )),
    )
        .into_response()
}
fn route_error_status_message(err: &anyhow::Error) -> (StatusCode, String) {
    if let Some((status, message)) = upstream_error_status_message(err) {
        return (status, message);
    }
    (StatusCode::BAD_GATEWAY, err.to_string())
}

fn upstream_error_status_message(err: &anyhow::Error) -> Option<(StatusCode, String)> {
    let message = err.to_string();
    let status_message = message.strip_prefix("upstream ")?;
    let (status_text, body) = status_message.split_once(':')?;
    let code = status_text
        .split_whitespace()
        .find_map(|part| part.parse::<u16>().ok())?;
    let status = StatusCode::from_u16(code).ok()?;
    Some((status, body.trim().to_owned()))
}

fn classify_error(err: &anyhow::Error) -> RequestFailure {
    let status = upstream_error_status_message(err).map(|(status, _)| status);
    let text = err.to_string().to_lowercase();

    if matches!(
        status,
        Some(StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN)
    ) || text.contains("invalid_token")
        || text.contains("no access_token")
        || text.contains("no usable access_token")
        || text.contains("token expired")
        || text.contains("unauthorized")
        || text.contains("forbidden")
    {
        return RequestFailure::Auth;
    }

    if matches!(status, Some(StatusCode::TOO_MANY_REQUESTS))
        || text.contains("quota")
        || text.contains("rate limit")
        || text.contains("resource exhausted")
    {
        return RequestFailure::Quota;
    }

    if matches!(
        status,
        Some(
            StatusCode::INTERNAL_SERVER_ERROR
                | StatusCode::BAD_GATEWAY
                | StatusCode::SERVICE_UNAVAILABLE
                | StatusCode::GATEWAY_TIMEOUT
        )
    ) || text.contains("temporarily unavailable")
        || text.contains("server error")
        || text.contains("backend error")
        || text.contains("overloaded")
        || text.contains("retry")
    {
        return RequestFailure::Transient;
    }

    RequestFailure::Hard
}

fn clear_account_failures(account: &mut crate::state::AccountKeys) {
    account.last_auth_failure_at = None;
    account.last_quota_failure_at = None;
}

fn note_account_failure(account: &mut crate::state::AccountKeys, failure: RequestFailure) {
    match failure {
        RequestFailure::Auth => account.last_auth_failure_at = Some(now_unix()),
        RequestFailure::Quota => account.last_quota_failure_at = Some(now_unix()),
        RequestFailure::Transient | RequestFailure::Hard => {}
    }
}
fn now_unix() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn should_try_next_account(err: &anyhow::Error) -> bool {
    matches!(
        classify_error(err),
        RequestFailure::Auth | RequestFailure::Quota | RequestFailure::Transient
    )
}

/// translate and forward a chat completion request.
///
/// reads config and account state from disk, refreshes tokens when needed, and
/// writes updated account state back after a successful upstream call.
async fn route_chat(state: &AppState, body: ChatRequest) -> Result<Response> {
    if body.stream.unwrap_or(false) {
        return Ok(not_implemented("streaming is not implemented yet"));
    }
    if body
        .messages
        .iter()
        .any(|message| !text_only_content(&message.content))
    {
        return Ok((
            StatusCode::NOT_IMPLEMENTED,
            Json(openai_error(
                "multimodal content is not implemented yet",
                "not_implemented",
                Some("not_implemented"),
            )),
        )
            .into_response());
    }
    let config = config::load_config(&state.root).await?;
    let mut keys = get_valid_accounts(state).await?;
    let request = translate_chat_request(&body)?;
    let mut last_err = None;
    for account in &mut keys.accounts {
        match execute_chat_account(
            &state.http,
            account,
            &config,
            &request,
            body.model.as_deref(),
        )
        .await
        {
            Ok(resp) => {
                let _ = crate::state::write_json(&keys_path(&state.root), &keys).await;
                return Ok(Json(resp).into_response());
            }
            Err(err) if should_try_next_account(&err) => last_err = Some(err),
            Err(err) => return Err(err),
        }
    }
    Err(last_err.unwrap_or_else(|| anyhow!("no usable access_token found")))
}
/// translate and forward an anthropic messages request.
///
/// reads config and account state from disk, rejects unsupported tool-use
/// payloads, and writes refreshed account state after success.
async fn route_messages(state: &AppState, body: MessageRequest) -> Result<Response> {
    if body.stream.unwrap_or(false) {
        return Ok(not_implemented("streaming is not implemented yet"));
    }
    if let Some(reason) = body
        .messages
        .iter()
        .find_map(|message| message_blocks_unsupported_reason(&message.content))
    {
        return Ok((
            StatusCode::NOT_IMPLEMENTED,
            Json(match reason {
                "tool_use" => anthropic_error("tool use is not implemented yet", "not_implemented"),
                _ => anthropic_error(
                    "multimodal content is not implemented yet",
                    "not_implemented",
                ),
            }),
        )
            .into_response());
    }
    let config = config::load_config(&state.root).await?;
    let mut keys = get_valid_accounts(state).await?;
    let request = translate_message_request(&body)?;
    let mut last_err = None;
    for account in &mut keys.accounts {
        match execute_message_account(
            &state.http,
            account,
            &config,
            &request,
            body.model.as_deref(),
        )
        .await
        {
            Ok(resp) => {
                let _ = crate::state::write_json(&keys_path(&state.root), &keys).await;
                return Ok(Json(resp).into_response());
            }
            Err(err) if should_try_next_account(&err) => last_err = Some(err),
            Err(err) => return Err(err),
        }
    }
    Err(last_err.unwrap_or_else(|| anyhow!("no usable access_token found")))
}

fn message_block_text(block: &MessageBlock) -> String {
    if block.kind != "text" && block.kind != "input_text" && block.kind != "output_text" {
        return String::new();
    }
    block
        .text
        .clone()
        .or_else(|| block.value.clone())
        .unwrap_or_default()
}
/// translate and forward an openai responses request.
///
/// reads config and account state from disk, rejects unsupported tool-use
/// payloads, and writes refreshed account state back after success.
async fn route_responses(state: &AppState, body: ResponsesRequest) -> Result<Response> {
    if body.stream.unwrap_or(false) {
        return Ok(not_implemented("streaming is not implemented yet"));
    }
    if !responses_text_only(&body.input) {
        return Ok((
            StatusCode::NOT_IMPLEMENTED,
            Json(responses_error(
                "multimodal input is not implemented yet",
                "not_implemented",
            )),
        )
            .into_response());
    }
    if tool_use_requested(&body.input) {
        return Ok((
            StatusCode::NOT_IMPLEMENTED,
            Json(responses_error(
                "tool use is not implemented yet",
                "not_implemented",
            )),
        )
            .into_response());
    }
    let config = config::load_config(&state.root).await?;
    let mut keys = get_valid_accounts(state).await?;
    let request = translate_responses_request(&body)?;
    let mut last_err = None;
    for account in &mut keys.accounts {
        match execute_responses_account(
            &state.http,
            account,
            &config,
            &request,
            body.model.as_deref(),
        )
        .await
        {
            Ok(resp) => {
                let _ = crate::state::write_json(&keys_path(&state.root), &keys).await;
                return Ok(Json(resp).into_response());
            }
            Err(err) if should_try_next_account(&err) => last_err = Some(err),
            Err(err) => return Err(err),
        }
    }
    Err(last_err.unwrap_or_else(|| anyhow!("no usable access_token found")))
}

async fn execute_message_request(
    http: &HttpClient,
    access_token: &str,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<AnthropicResponse> {
    let response = http
        .0
        .post(stream_generate_url())
        .headers(http.auth_headers(access_token)?)
        .json(body)
        .send()
        .await?;
    if !response.status().is_success() {
        return Err(anyhow!(
            "upstream {}: {}",
            response.status(),
            response.text().await.unwrap_or_default()
        ));
    }
    let response: GeminiResponse = response.json().await?;
    let text = response
        .candidates
        .into_iter()
        .find_map(|c| c.content)
        .and_then(|c| c.parts.into_iter().find_map(|p| p.text))
        .unwrap_or_default();
    Ok(AnthropicResponse {
        id: format!("msg_{}", uuid::Uuid::new_v4()),
        r#type: "message".to_owned(),
        role: "assistant".to_owned(),
        model: resolve_model(model).to_owned(),
        content: vec![AnthropicBlock {
            kind: "text".to_owned(),
            text,
        }],
        stop_reason: "end_turn".to_owned(),
        stop_sequence: None,
        usage: None,
    })
}
async fn execute_message_account(
    http: &HttpClient,
    account: &mut crate::state::AccountKeys,
    config: &config::ConfigFile,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<AnthropicResponse> {
    let first = match account.access_token.as_deref() {
        Some(token) => execute_message_request(http, token, body, model).await,
        None => Err(anyhow!("no access_token")),
    };
    match first {
        Ok(resp) => {
            clear_account_failures(account);
            Ok(resp)
        }
        Err(err)
            if classify_error(&err) == RequestFailure::Auth && account.refresh_token.is_some() =>
        {
            note_account_failure(account, RequestFailure::Auth);
            refresh_account(http, config, account).await?;
            let token = account
                .access_token
                .as_deref()
                .ok_or_else(|| anyhow!("no usable access_token found after refresh"))?;
            let retry = execute_message_request(http, token, body, model).await;
            match &retry {
                Ok(_) => clear_account_failures(account),
                Err(err) => note_account_failure(account, classify_error(err)),
            }
            retry
        }
        Err(err) => {
            note_account_failure(account, classify_error(&err));
            Err(err)
        }
    }
}
async fn execute_responses_request(
    http: &HttpClient,
    access_token: &str,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<ResponsesResponse> {
    let response = http
        .0
        .post(stream_generate_url())
        .headers(http.auth_headers(access_token)?)
        .json(body)
        .send()
        .await?;
    if !response.status().is_success() {
        return Err(anyhow!(
            "upstream {}: {}",
            response.status(),
            response.text().await.unwrap_or_default()
        ));
    }
    let response: GeminiResponse = response.json().await?;
    let text = response
        .candidates
        .into_iter()
        .find_map(|c| c.content)
        .and_then(|c| c.parts.into_iter().find_map(|p| p.text))
        .unwrap_or_default();
    Ok(ResponsesResponse {
        id: format!("resp_{}", uuid::Uuid::new_v4()),
        object: "response".to_owned(),
        model: resolve_model(model).to_owned(),
        output: vec![ResponsesOutput {
            kind: "message".to_owned(),
            id: format!("msg_{}", uuid::Uuid::new_v4()),
            role: "assistant".to_owned(),
            content: vec![ResponsesOutputContent {
                kind: "output_text".to_owned(),
                text,
            }],
        }],
        usage: None,
    })
}
async fn execute_responses_account(
    http: &HttpClient,
    account: &mut crate::state::AccountKeys,
    config: &config::ConfigFile,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<ResponsesResponse> {
    let first = match account.access_token.as_deref() {
        Some(token) => execute_responses_request(http, token, body, model).await,
        None => Err(anyhow!("no access_token")),
    };
    match first {
        Ok(resp) => {
            clear_account_failures(account);
            Ok(resp)
        }
        Err(err)
            if classify_error(&err) == RequestFailure::Auth && account.refresh_token.is_some() =>
        {
            note_account_failure(account, RequestFailure::Auth);
            refresh_account(http, config, account).await?;
            let token = account
                .access_token
                .as_deref()
                .ok_or_else(|| anyhow!("no usable access_token found after refresh"))?;
            let retry = execute_responses_request(http, token, body, model).await;
            match &retry {
                Ok(_) => clear_account_failures(account),
                Err(err) => note_account_failure(account, classify_error(err)),
            }
            retry
        }
        Err(err) => {
            note_account_failure(account, classify_error(&err));
            Err(err)
        }
    }
}

fn translate_message_request(body: &MessageRequest) -> Result<GeminiRequest> {
    let mut system_instruction = None;
    let mut contents = Vec::new();
    for message in &body.messages {
        let text = text_only_message_content(&message.content);
        if text.is_empty() {
            continue;
        }
        if message.role == "system" {
            system_instruction = Some(GeminiSystemInstruction {
                parts: vec![GeminiPart { text }],
            });
        } else {
            let role = if message.role == "assistant" {
                "model"
            } else {
                "user"
            };
            contents.push(GeminiContent {
                role: role.to_owned(),
                parts: vec![GeminiPart { text }],
            });
        }
    }
    Ok(GeminiRequest {
        project: DEFAULT_PROJECT_ID.to_owned(),
        model: resolve_model(body.model.as_deref()).to_owned(),
        request: GeminiInnerRequest {
            contents,
            system_instruction,
        },
    })
}

fn text_only_message_content(blocks: &[MessageBlock]) -> String {
    blocks
        .iter()
        .map(message_block_text)
        .filter(|text| !text.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}
fn translate_responses_request(body: &ResponsesRequest) -> Result<GeminiRequest> {
    let (system, text) = responses_input_text(&body.input)?;
    Ok(GeminiRequest {
        project: DEFAULT_PROJECT_ID.to_owned(),
        model: resolve_model(body.model.as_deref()).to_owned(),
        request: GeminiInnerRequest {
            contents: vec![GeminiContent {
                role: "user".to_owned(),
                parts: vec![GeminiPart { text }],
            }],
            system_instruction: system.map(|text| GeminiSystemInstruction {
                parts: vec![GeminiPart { text }],
            }),
        },
    })
}
fn translate_chat_request(body: &ChatRequest) -> Result<GeminiRequest> {
    let mut system_instruction = None;
    let mut contents = Vec::new();
    for msg in &body.messages {
        let text = extract_text(&msg.content)?;
        if matches!(msg.role.as_str(), "system" | "developer") {
            system_instruction = Some(GeminiSystemInstruction {
                parts: vec![GeminiPart { text }],
            });
        } else {
            let role = if msg.role == "assistant" {
                "model"
            } else {
                "user"
            };
            contents.push(GeminiContent {
                role: role.to_owned(),
                parts: vec![GeminiPart { text }],
            });
        }
    }
    Ok(GeminiRequest {
        project: DEFAULT_PROJECT_ID.to_owned(),
        model: resolve_model(body.model.as_deref()).to_owned(),
        request: GeminiInnerRequest {
            contents,
            system_instruction,
        },
    })
}
async fn execute_chat_request(
    http: &HttpClient,
    access_token: &str,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<OpenAIChatResponse> {
    let response = http
        .0
        .post(stream_generate_url())
        .headers(http.auth_headers(access_token)?)
        .json(body)
        .send()
        .await?;
    if !response.status().is_success() {
        return Err(anyhow!(
            "upstream {}: {}",
            response.status(),
            response.text().await.unwrap_or_default()
        ));
    }
    let response: GeminiResponse = response.json().await?;
    let text = response
        .candidates
        .into_iter()
        .find_map(|c| c.content)
        .and_then(|c| c.parts.into_iter().find_map(|p| p.text))
        .unwrap_or_default();
    Ok(OpenAIChatResponse {
        id: format!("chatcmpl-{}", uuid::Uuid::new_v4()),
        object: "chat.completion".to_owned(),
        created: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_secs(),
        model: resolve_model(model).to_owned(),
        choices: vec![OpenAIChoice {
            index: 0,
            message: OpenAIMessage {
                role: "assistant".to_owned(),
                content: text,
            },
            finish_reason: "stop".to_owned(),
        }],
        usage: None,
    })
}

async fn execute_chat_account(
    http: &HttpClient,
    account: &mut crate::state::AccountKeys,
    config: &config::ConfigFile,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<OpenAIChatResponse> {
    if account.access_token.is_none() && account.refresh_token.is_some() {
        refresh_account(http, config, account).await.ok();
    }
    let first = match account.access_token.as_deref() {
        Some(token) => execute_chat_request(http, token, body, model).await,
        None => Err(anyhow!("no access_token")),
    };
    match first {
        Ok(resp) => {
            clear_account_failures(account);
            Ok(resp)
        }
        Err(err)
            if classify_error(&err) == RequestFailure::Auth && account.refresh_token.is_some() =>
        {
            note_account_failure(account, RequestFailure::Auth);
            refresh_account(http, config, account).await?;
            let token = account
                .access_token
                .as_deref()
                .ok_or_else(|| anyhow!("no usable access_token found after refresh"))?;
            let retry = execute_chat_request(http, token, body, model).await;
            match &retry {
                Ok(_) => clear_account_failures(account),
                Err(err) => note_account_failure(account, classify_error(err)),
            }
            retry
        }
        Err(err) => {
            note_account_failure(account, classify_error(&err));
            Err(err)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{routing::post, Json, Router};
    use std::sync::{Arc, Mutex};
    use tokio::net::TcpListener;
    use tower::ServiceExt;

    struct EnvGuard {
        key: &'static str,
        value: Option<String>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: String) -> Self {
            let previous = std::env::var(key).ok();
            std::env::set_var(key, value);
            Self {
                key,
                value: previous,
            }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            match self.value.take() {
                Some(value) => std::env::set_var(self.key, value),
                None => std::env::remove_var(self.key),
            }
        }
    }

    async fn test_state() -> AppState {
        let dir = tempfile::tempdir().unwrap();
        crate::state::write_json(
            &crate::state::config_path(dir.path()),
            &crate::config::ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: crate::config::DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        crate::state::write_json(
            &crate::state::keys_path(dir.path()),
            &crate::state::KeysFile {
                accounts: vec![crate::state::AccountKeys {
                    id: "a".into(),
                    access_token: Some("t".into()),
                    ..Default::default()
                }],
            },
        )
        .await
        .unwrap();
        let path = dir.keep();
        AppState::new(Some(path)).unwrap()
    }

    #[test]
    fn classifies_common_errors() {
        assert!(matches!(
            classify_error(&anyhow!("upstream 401: nope")),
            RequestFailure::Auth
        ));
        assert!(matches!(
            classify_error(&anyhow!("forbidden by upstream")),
            RequestFailure::Auth
        ));
        assert!(matches!(
            classify_error(&anyhow!("no access_token")),
            RequestFailure::Auth
        ));
        assert!(matches!(
            classify_error(&anyhow!("no usable access_token found after refresh")),
            RequestFailure::Auth
        ));
        assert!(matches!(
            classify_error(&anyhow!("token expired upstream")),
            RequestFailure::Auth
        ));
        assert!(matches!(
            classify_error(&anyhow!("quota exceeded")),
            RequestFailure::Quota
        ));
        assert!(matches!(
            classify_error(&anyhow!("upstream 429: rate limit")),
            RequestFailure::Quota
        ));
        assert!(matches!(
            classify_error(&anyhow!("backend error retry later")),
            RequestFailure::Transient
        ));
        assert!(matches!(
            classify_error(&anyhow!("upstream 503: temporarily unavailable")),
            RequestFailure::Transient
        ));
        assert!(matches!(
            classify_error(&anyhow!("bad request")),
            RequestFailure::Hard
        ));
        assert!(should_try_next_account(&anyhow!(
            "upstream 503: retry later"
        )));
        assert_eq!(
            upstream_error_status_message(&anyhow!("upstream 418: teapot")),
            Some((StatusCode::IM_A_TEAPOT, "teapot".into()))
        );
        assert_eq!(
            route_error_status_message(&anyhow!("upstream 429: quota hit")).0,
            StatusCode::TOO_MANY_REQUESTS
        );
    }

    #[test]
    fn translates_chat_requests() {
        let body = ChatRequest {
            model: Some("claude-sonnet-4".into()),
            messages: vec![
                ChatMessage {
                    role: "system".into(),
                    content: serde_json::json!("rules"),
                },
                ChatMessage {
                    role: "user".into(),
                    content: serde_json::json!({"text":"hi"}),
                },
            ],
            stream: None,
        };
        let translated = translate_chat_request(&body).unwrap();
        assert_eq!(translated.model, "claude-sonnet-4");
        assert_eq!(translated.request.contents.len(), 1);
        assert!(translated.request.system_instruction.is_some());
    }

    #[test]
    fn translates_message_and_response_requests() {
        let msg = translate_message_request(&MessageRequest {
            messages: vec![MessageContent {
                role: "user".into(),
                content: vec![MessageBlock {
                    kind: "text".into(),
                    text: Some("hi".into()),
                    value: None,
                }],
            }],
            model: None,
            stream: None,
        })
        .unwrap();
        assert_eq!(msg.request.contents.len(), 1);
        let resp = translate_responses_request(&ResponsesRequest { model: None, input: serde_json::json!([{ "role": "system", "content": "rules" }, { "role": "user", "content": "hi" }]), stream: None }).unwrap();
        assert!(resp.request.system_instruction.is_some());
    }

    #[test]
    fn message_block_text_and_unsupported_reason_cover_variants() {
        assert_eq!(
            message_block_text(&MessageBlock {
                kind: "text".into(),
                text: Some("hello".into()),
                value: None
            }),
            "hello"
        );
        assert_eq!(
            message_block_text(&MessageBlock {
                kind: "tool_use".into(),
                text: Some("ignored".into()),
                value: None
            }),
            ""
        );
        assert_eq!(
            message_blocks_unsupported_reason(&[MessageBlock {
                kind: "tool_use".into(),
                text: None,
                value: None
            }]),
            Some("tool_use")
        );
        assert_eq!(
            responses_input_text(&serde_json::json!({"content":"hi"}))
                .unwrap()
                .1,
            "hi"
        );
    }

    #[tokio::test]
    async fn app_serves_models_and_status() {
        let app = app(test_state().await);

        let models = app
            .clone()
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/models")
                    .body(axum::body::Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(models.status(), StatusCode::OK);

        let status = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/status")
                    .body(axum::body::Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(status.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn route_handlers_reject_unsupported_shapes() {
        let state = test_state().await;

        assert_eq!(
            route_chat(
                &state,
                ChatRequest {
                    model: None,
                    messages: vec![ChatMessage {
                        role: "user".into(),
                        content: serde_json::json!("hi"),
                    }],
                    stream: Some(true),
                },
            )
            .await
            .unwrap()
            .status(),
            StatusCode::NOT_IMPLEMENTED
        );

        assert_eq!(
            route_messages(
                &state,
                MessageRequest {
                    messages: vec![MessageContent {
                        role: "user".into(),
                        content: vec![MessageBlock {
                            kind: "image".into(),
                            text: None,
                            value: None,
                        }],
                    }],
                    model: None,
                    stream: None,
                },
            )
            .await
            .unwrap()
            .status(),
            StatusCode::NOT_IMPLEMENTED
        );

        let tool_use = route_messages(
            &state,
            MessageRequest {
                messages: vec![MessageContent {
                    role: "user".into(),
                    content: vec![MessageBlock {
                        kind: "tool_use".into(),
                        text: None,
                        value: None,
                    }],
                }],
                model: None,
                stream: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(tool_use.status(), StatusCode::NOT_IMPLEMENTED);

        assert_eq!(
            route_responses(
                &state,
                ResponsesRequest {
                    model: None,
                    input: serde_json::json!({"type":"tool_use"}),
                    stream: None,
                },
            )
            .await
            .unwrap()
            .status(),
            StatusCode::NOT_IMPLEMENTED
        );

        let multimodal = route_responses(
            &state,
            ResponsesRequest {
                model: None,
                input: serde_json::json!({"type":"image"}),
                stream: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(multimodal.status(), StatusCode::NOT_IMPLEMENTED);
    }

    #[tokio::test]
    async fn route_handlers_surface_fake_upstream_results() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/",
            post(|| async {
                Json(serde_json::json!({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _guard = EnvGuard::set("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/"));
        let state = test_state().await;

        let chat = route_chat(
            &state,
            ChatRequest {
                model: Some("claude-sonnet-4".into()),
                messages: vec![ChatMessage {
                    role: "user".into(),
                    content: serde_json::json!("hi"),
                }],
                stream: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(chat.status(), StatusCode::OK);

        let msg = route_messages(
            &state,
            MessageRequest {
                messages: vec![MessageContent {
                    role: "user".into(),
                    content: vec![MessageBlock {
                        kind: "text".into(),
                        text: Some("hi".into()),
                        value: None,
                    }],
                }],
                model: None,
                stream: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(msg.status(), StatusCode::OK);

        let resp = route_responses(
            &state,
            ResponsesRequest {
                model: None,
                input: serde_json::json!({"content":"hi"}),
                stream: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn chat_account_refreshes_on_auth_failure() {
        let request_count = Arc::new(Mutex::new(0usize));
        let request_count2 = request_count.clone();
        let gen = post(move |Json(_): Json<serde_json::Value>| {
            let request_count = request_count2.clone();
            async move {
                let mut count = request_count.lock().unwrap();
                *count += 1;
                if *count == 1 {
                    (
                        StatusCode::UNAUTHORIZED,
                        Json(serde_json::json!({"error":"invalid_token"})),
                    )
                } else {
                    (
                        StatusCode::OK,
                        Json(
                            serde_json::json!({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}),
                        ),
                    )
                }
            }
        });
        let token = post(|| async {
            (
                StatusCode::OK,
                Json(serde_json::json!({"access_token":"fresh","expires_in":60})),
            )
        });
        let upstream = Router::new().route("/gen", gen).route("/token", token);
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let _ = axum::serve(listener, upstream).await;
        });
        let _stream = EnvGuard::set("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/gen"));
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = test_state().await;
        let mut account = crate::state::AccountKeys {
            id: "a".into(),
            access_token: Some("old".into()),
            refresh_token: Some("refresh".into()),
            ..Default::default()
        };
        let cfg = crate::config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: crate::config::DEFAULT_REDIRECT_URI.into(),
        };
        let body = translate_chat_request(&ChatRequest {
            model: None,
            messages: vec![ChatMessage {
                role: "user".into(),
                content: serde_json::json!("hi"),
            }],
            stream: None,
        })
        .unwrap();
        let resp = execute_chat_account(&state.http, &mut account, &cfg, &body, None)
            .await
            .unwrap();
        assert_eq!(resp.choices[0].message.content, "ok");
        assert!(
            account.access_token.as_deref() == Some("fresh")
                || account.access_token.as_deref() == Some("old")
        );
    }

    #[tokio::test]
    async fn chat_account_refreshes_before_first_attempt_without_access_token() {
        let request_count = Arc::new(Mutex::new(0usize));
        let request_count2 = request_count.clone();
        let gen = post(move |Json(_): Json<serde_json::Value>| {
            let request_count = request_count2.clone();
            async move {
                *request_count.lock().unwrap() += 1;
                (
                    StatusCode::OK,
                    Json(serde_json::json!({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]})),
                )
            }
        });
        let token = post(|| async {
            (
                StatusCode::OK,
                Json(serde_json::json!({"access_token":"fresh","expires_in":60})),
            )
        });
        let upstream = Router::new().route("/gen", gen).route("/token", token);
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let _ = axum::serve(listener, upstream).await;
        });
        let _stream = EnvGuard::set("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/gen"));
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = test_state().await;
        let mut account = crate::state::AccountKeys {
            id: "a".into(),
            access_token: None,
            refresh_token: Some("refresh".into()),
            ..Default::default()
        };
        let cfg = crate::config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: crate::config::DEFAULT_REDIRECT_URI.into(),
        };
        let body = translate_chat_request(&ChatRequest {
            model: None,
            messages: vec![ChatMessage {
                role: "user".into(),
                content: serde_json::json!("hi"),
            }],
            stream: None,
        })
        .unwrap();
        let resp = execute_chat_account(&state.http, &mut account, &cfg, &body, None)
            .await
            .unwrap();
        assert_eq!(resp.choices[0].message.content, "ok");
        assert_eq!(*request_count.lock().unwrap(), 1);
        assert_eq!(account.access_token.as_deref(), Some("fresh"));
    }

    #[tokio::test]
    async fn message_account_refreshes_on_auth_failure() {
        let request_count = Arc::new(Mutex::new(0usize));
        let request_count2 = request_count.clone();
        let gen = post(move |Json(_): Json<serde_json::Value>| {
            let request_count = request_count2.clone();
            async move {
                let mut count = request_count.lock().unwrap();
                *count += 1;
                if *count == 1 {
                    (
                        StatusCode::UNAUTHORIZED,
                        Json(serde_json::json!({"error":"invalid_token"})),
                    )
                } else {
                    (
                        StatusCode::OK,
                        Json(
                            serde_json::json!({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}),
                        ),
                    )
                }
            }
        });
        let token = post(|| async {
            (
                StatusCode::OK,
                Json(serde_json::json!({"access_token":"fresh","expires_in":60})),
            )
        });
        let upstream = Router::new().route("/gen", gen).route("/token", token);
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let _ = axum::serve(listener, upstream).await;
        });
        let _stream = EnvGuard::set("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/gen"));
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = test_state().await;
        let cfg = crate::config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: crate::config::DEFAULT_REDIRECT_URI.into(),
        };
        let body = translate_message_request(&MessageRequest {
            messages: vec![MessageContent {
                role: "user".into(),
                content: vec![MessageBlock {
                    kind: "text".into(),
                    text: Some("hi".into()),
                    value: None,
                }],
            }],
            model: None,
            stream: None,
        })
        .unwrap();
        let mut message_account = crate::state::AccountKeys {
            id: "a".into(),
            access_token: Some("old".into()),
            refresh_token: Some("refresh".into()),
            ..Default::default()
        };
        let msg = execute_message_account(&state.http, &mut message_account, &cfg, &body, None)
            .await
            .unwrap();
        assert_eq!(msg.content[0].text, "ok");
    }

    #[tokio::test]
    async fn responses_account_refreshes_on_auth_failure() {
        let request_count = Arc::new(Mutex::new(0usize));
        let request_count2 = request_count.clone();
        let gen = post(move |Json(_): Json<serde_json::Value>| {
            let request_count = request_count2.clone();
            async move {
                let mut count = request_count.lock().unwrap();
                *count += 1;
                if *count == 1 {
                    (
                        StatusCode::UNAUTHORIZED,
                        Json(serde_json::json!({"error":"invalid_token"})),
                    )
                } else {
                    (
                        StatusCode::OK,
                        Json(
                            serde_json::json!({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}),
                        ),
                    )
                }
            }
        });
        let token = post(|| async {
            (
                StatusCode::OK,
                Json(serde_json::json!({"access_token":"fresh","expires_in":60})),
            )
        });
        let upstream = Router::new().route("/gen", gen).route("/token", token);
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let _ = axum::serve(listener, upstream).await;
        });
        let _stream = EnvGuard::set("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/gen"));
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = test_state().await;
        let cfg = crate::config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: crate::config::DEFAULT_REDIRECT_URI.into(),
        };
        let response_body = translate_responses_request(&ResponsesRequest {
            model: None,
            input: serde_json::json!("hi"),
            stream: None,
        })
        .unwrap();
        let mut responses_account = crate::state::AccountKeys {
            id: "b".into(),
            access_token: Some("old".into()),
            refresh_token: Some("refresh".into()),
            ..Default::default()
        };
        let resp = execute_responses_account(
            &state.http,
            &mut responses_account,
            &cfg,
            &response_body,
            None,
        )
        .await
        .unwrap();
        assert_eq!(resp.output[0].content[0].text, "ok");
    }

    #[tokio::test]
    async fn route_wrappers_preserve_upstream_status_and_shape_errors() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let upstream = Router::new().route(
            "/",
            post(|| async {
                (
                    StatusCode::BAD_REQUEST,
                    Json(serde_json::json!({"error":"bad payload"})),
                )
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, upstream).await;
        });
        let _stream = EnvGuard::set("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/"));
        let state = test_state().await;
        let local_app = app(state);

        let chat = local_app
            .clone()
            .oneshot(
                axum::http::Request::builder()
                    .method("POST")
                    .uri("/v1/chat/completions")
                    .header("content-type", "application/json")
                    .body(axum::body::Body::from(
                        serde_json::to_vec(&serde_json::json!({
                            "messages":[{"role":"user","content":"hi"}]
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(chat.status(), StatusCode::BAD_REQUEST);

        let messages = local_app
            .clone()
            .oneshot(
                axum::http::Request::builder()
                    .method("POST")
                    .uri("/v1/messages")
                    .header("content-type", "application/json")
                    .body(axum::body::Body::from(
                        serde_json::to_vec(&serde_json::json!({
                            "messages":[{"role":"user","content":[{"type":"text","text":"hi"}]}]
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(messages.status(), StatusCode::BAD_REQUEST);

        let responses = local_app
            .oneshot(
                axum::http::Request::builder()
                    .method("POST")
                    .uri("/v1/responses")
                    .header("content-type", "application/json")
                    .body(axum::body::Body::from(
                        serde_json::to_vec(&serde_json::json!({"input":"hi"})).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(responses.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn chat_request_hits_fake_upstream() {
        let captured = Arc::new(Mutex::new(None::<serde_json::Value>));
        let captured2 = captured.clone();
        let upstream = Router::new().route(
            "/",
            post(move |Json(body): Json<serde_json::Value>| {
                let captured = captured2.clone();
                async move {
                    *captured.lock().unwrap() = Some(body);
                    Json(serde_json::json!({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}))
                }
            }),
        );
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let _ = axum::serve(listener, upstream).await;
        });
        let old = std::env::var("AG_CLI_STREAM_GENERATE_URL").ok();
        std::env::set_var("AG_CLI_STREAM_GENERATE_URL", format!("http://{addr}/"));
        let state = test_state().await;
        let resp = route_chat(
            &state,
            ChatRequest {
                model: None,
                messages: vec![ChatMessage {
                    role: "user".into(),
                    content: serde_json::json!("hi"),
                }],
                stream: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        assert!(captured.lock().unwrap().is_some());
        match old {
            Some(v) => std::env::set_var("AG_CLI_STREAM_GENERATE_URL", v),
            None => std::env::remove_var("AG_CLI_STREAM_GENERATE_URL"),
        }
    }
}
