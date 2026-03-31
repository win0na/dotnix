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

pub const DEFAULT_PORT: u16 = 8080;

/// bind the local api server and serve the configured routes.
pub async fn serve(state: AppState, port: u16) -> Result<()> {
    let app = Router::new()
        .route("/v1/models", get(v1_models))
        .route("/v1/chat/completions", post(v1_chat_completions))
        .route("/v1/messages", post(v1_messages))
        .route("/v1/responses", post(v1_responses))
        .route("/status", get(v1_status))
        .with_state(state.clone());
    let addr: SocketAddr = ([127, 0, 0, 1], port).into();
    println!("serving on http://{addr}");
    axum::serve(TcpListener::bind(addr).await?, app)
        .into_future()
        .await?;
    Ok(())
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
    let keys: crate::state::KeysFile = get_valid_accounts(&state).await.unwrap_or_default();
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
        .unwrap_or_else(error_response)
}
/// handle anthropic messages requests.
async fn v1_messages(State(state): State<AppState>, Json(body): Json<MessageRequest>) -> Response {
    route_messages(&state, body)
        .await
        .unwrap_or_else(error_response)
}
/// handle openai responses requests.
async fn v1_responses(
    State(state): State<AppState>,
    Json(body): Json<ResponsesRequest>,
) -> Response {
    route_responses(&state, body)
        .await
        .unwrap_or_else(error_response)
}

fn error_response(err: anyhow::Error) -> Response {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(openai_error(err.to_string(), "server_error", None)),
    )
        .into_response()
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
fn clear_unsupported_tool_use() -> Response {
    (
        StatusCode::NOT_IMPLEMENTED,
        Json(anthropic_error(
            "tool use is not implemented yet",
            "not_implemented",
        )),
    )
        .into_response()
}
fn is_auth_error(err: &anyhow::Error) -> bool {
    let s = err.to_string();
    s.contains("401") || s.contains("403") || s.contains("unauthorized") || s.contains("forbidden")
}
fn now_unix() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// translate and forward a chat completion request.
///
/// reads config and account state from disk, refreshes tokens when needed, and
/// writes updated account state back after a successful upstream call.
async fn route_chat(state: &AppState, body: ChatRequest) -> Result<Response> {
    if body.stream.unwrap_or(false) {
        return Ok(not_implemented("streaming is not implemented yet"));
    }
    let config = config::load_config(&state.root).await?;
    let mut keys = get_valid_accounts(state).await?;
    let request = translate_chat_request(&body)?;
    let mut last_err = None;
    for account in &mut keys.accounts {
        if account.access_token.is_none() && account.refresh_token.is_some() {
            let _ = refresh_account(&state.http, &config, account).await;
        }
        let Some(token) = account.access_token.as_deref() else {
            continue;
        };
        match execute_chat_request(&state.http, token, &request, body.model.as_deref()).await {
            Ok(resp) => {
                let _ = crate::state::write_json(&keys_path(&state.root), &keys).await;
                return Ok(Json(resp).into_response());
            }
            Err(err) => last_err = Some(err),
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
    if message_requests_tool_use(&body.messages) {
        return Ok(clear_unsupported_tool_use());
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
            Err(err) => last_err = Some(err),
        }
    }
    Err(last_err.unwrap_or_else(|| anyhow!("no usable access_token found")))
}

/// return true when any message block requests tool use.
fn message_requests_tool_use(messages: &[MessageContent]) -> bool {
    messages.iter().any(|message| {
        message.content.iter().any(|block| {
            tool_use_requested(&serde_json::json!({
                "type": block.kind,
                "text": block.text,
            }))
        })
    })
}
/// translate and forward an openai responses request.
///
/// reads config and account state from disk, rejects unsupported tool-use
/// payloads, and writes refreshed account state back after success.
async fn route_responses(state: &AppState, body: ResponsesRequest) -> Result<Response> {
    if body.stream.unwrap_or(false) {
        return Ok(not_implemented("streaming is not implemented yet"));
    }
    if tool_use_requested(&body.input) {
        return Ok(clear_unsupported_tool_use());
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
            Err(err) => last_err = Some(err),
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
    let response: GeminiResponse = http
        .0
        .post(STREAM_GENERATE_URL)
        .headers(http.auth_headers(access_token)?)
        .json(body)
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;
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
        Ok(resp) => Ok(resp),
        Err(err) if is_auth_error(&err) && account.refresh_token.is_some() => {
            account.last_auth_failure_at = Some(now_unix());
            refresh_account(http, config, account).await?;
            let token = account
                .access_token
                .as_deref()
                .ok_or_else(|| anyhow!("no usable access_token found after refresh"))?;
            execute_message_request(http, token, body, model).await
        }
        Err(err) => Err(err),
    }
}
async fn execute_responses_request(
    http: &HttpClient,
    access_token: &str,
    body: &GeminiRequest,
    model: Option<&str>,
) -> Result<ResponsesResponse> {
    let response: GeminiResponse = http
        .0
        .post(STREAM_GENERATE_URL)
        .headers(http.auth_headers(access_token)?)
        .json(body)
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;
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
        Ok(resp) => Ok(resp),
        Err(err) if is_auth_error(&err) && account.refresh_token.is_some() => {
            refresh_account(http, config, account).await?;
            let token = account
                .access_token
                .as_deref()
                .ok_or_else(|| anyhow!("no usable access_token found after refresh"))?;
            execute_responses_request(http, token, body, model).await
        }
        Err(err) => Err(err),
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
        .filter(|block| block.kind == "text")
        .filter_map(|block| block.text.as_deref())
        .collect()
}
fn translate_responses_request(body: &ResponsesRequest) -> Result<GeminiRequest> {
    let text = extract_text(&body.input)?;
    Ok(GeminiRequest {
        project: DEFAULT_PROJECT_ID.to_owned(),
        model: resolve_model(body.model.as_deref()).to_owned(),
        request: GeminiInnerRequest {
            contents: vec![GeminiContent {
                role: "user".to_owned(),
                parts: vec![GeminiPart { text }],
            }],
            system_instruction: None,
        },
    })
}
fn translate_chat_request(body: &ChatRequest) -> Result<GeminiRequest> {
    let mut system_instruction = None;
    let mut contents = Vec::new();
    for msg in &body.messages {
        let text = extract_text(&msg.content)?;
        if msg.role == "system" {
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
        model: body
            .model
            .clone()
            .unwrap_or_else(|| "claude-opus-4-6-thinking".to_owned()),
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
    let response: GeminiResponse = http
        .0
        .post(STREAM_GENERATE_URL)
        .headers(http.auth_headers(access_token)?)
        .json(body)
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;
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
