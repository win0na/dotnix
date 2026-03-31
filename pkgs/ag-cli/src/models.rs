use anyhow::Result;
use serde::{Deserialize, Serialize};

/// request and response shapes for upstream api calls.
pub const DEFAULT_PROJECT_ID: &str = "rising-fact-p41fc";
pub const STREAM_GENERATE_URL: &str =
    "https://cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse";
pub const MODEL_ROUTES: &[(&str, &str)] = &[
    ("default", "claude-opus-4-6-thinking"),
    ("claude-opus-4-6-thinking", "claude-opus-4-6-thinking"),
    ("claude-sonnet-4", "claude-sonnet-4"),
    ("claude-haiku-4", "claude-haiku-4"),
    ("gemini-2.0-pro", "gemini-2.0-pro"),
];

#[derive(Debug, Deserialize)]
pub struct ChatRequest {
    #[serde(default)]
    pub model: Option<String>,
    pub messages: Vec<ChatMessage>,
    #[serde(default)]
    pub stream: Option<bool>,
}
#[derive(Debug, Deserialize)]
pub struct ChatMessage {
    pub role: String,
    pub content: serde_json::Value,
}
#[derive(Debug, Deserialize)]
pub struct MessageRequest {
    pub messages: Vec<MessageContent>,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default)]
    pub stream: Option<bool>,
}
#[derive(Debug, Deserialize)]
pub struct MessageContent {
    pub role: String,
    pub content: Vec<MessageBlock>,
}
#[derive(Debug, Deserialize)]
pub struct MessageBlock {
    #[serde(rename = "type")]
    pub kind: String,
    pub text: Option<String>,
}
#[derive(Debug, Deserialize)]
pub struct ResponsesRequest {
    #[serde(default)]
    pub model: Option<String>,
    pub input: serde_json::Value,
    #[serde(default)]
    pub stream: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct GeminiRequest {
    pub project: String,
    pub model: String,
    pub request: GeminiInnerRequest,
}
#[derive(Debug, Serialize)]
pub struct GeminiInnerRequest {
    pub contents: Vec<GeminiContent>,
    #[serde(rename = "systemInstruction", skip_serializing_if = "Option::is_none")]
    pub system_instruction: Option<GeminiSystemInstruction>,
}
#[derive(Debug, Serialize)]
pub struct GeminiSystemInstruction {
    pub parts: Vec<GeminiPart>,
}
#[derive(Debug, Serialize)]
pub struct GeminiContent {
    pub role: String,
    pub parts: Vec<GeminiPart>,
}
#[derive(Debug, Serialize)]
pub struct GeminiPart {
    pub text: String,
}

#[derive(Debug, Deserialize)]
pub struct GeminiResponse {
    #[serde(default)]
    pub candidates: Vec<GeminiCandidate>,
}
#[derive(Debug, Deserialize)]
pub struct GeminiCandidate {
    pub content: Option<GeminiCandidateContent>,
}
#[derive(Debug, Deserialize)]
pub struct GeminiCandidateContent {
    #[serde(default)]
    pub parts: Vec<GeminiCandidatePart>,
}
#[derive(Debug, Deserialize)]
pub struct GeminiCandidatePart {
    pub text: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct OpenAIChatResponse {
    pub id: String,
    pub object: String,
    pub created: u64,
    pub model: String,
    pub choices: Vec<OpenAIChoice>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub usage: Option<OpenAIUsage>,
}
#[derive(Debug, Serialize)]
pub struct OpenAIChoice {
    pub index: u64,
    pub message: OpenAIMessage,
    pub finish_reason: String,
}
#[derive(Debug, Serialize)]
pub struct OpenAIMessage {
    pub role: String,
    pub content: String,
}
#[derive(Debug, Serialize)]
pub struct OpenAIUsage {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prompt_tokens: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_tokens: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total_tokens: Option<u64>,
}
#[derive(Debug, Serialize)]
pub struct ResponsesResponse {
    pub id: String,
    pub object: String,
    pub model: String,
    pub output: Vec<ResponsesOutput>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub usage: Option<ResponsesUsage>,
}
#[derive(Debug, Serialize)]
pub struct ResponsesOutput {
    #[serde(rename = "type")]
    pub kind: String,
    pub id: String,
    pub role: String,
    pub content: Vec<ResponsesOutputContent>,
}
#[derive(Debug, Serialize)]
pub struct ResponsesOutputContent {
    #[serde(rename = "type")]
    pub kind: String,
    pub text: String,
}
#[derive(Debug, Serialize)]
pub struct ResponsesUsage {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input_tokens: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_tokens: Option<u64>,
}
#[derive(Debug, Serialize)]
pub struct AnthropicResponse {
    pub id: String,
    pub r#type: String,
    pub role: String,
    pub model: String,
    pub content: Vec<AnthropicBlock>,
    pub stop_reason: String,
    pub stop_sequence: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub usage: Option<AnthropicUsage>,
}
#[derive(Debug, Serialize)]
pub struct AnthropicBlock {
    #[serde(rename = "type")]
    pub kind: String,
    pub text: String,
}
#[derive(Debug, Serialize)]
pub struct AnthropicUsage {
    pub input_tokens: u64,
    pub output_tokens: u64,
}

#[derive(Debug, Serialize)]
pub struct OpenAIErrorEnvelope {
    pub error: OpenAIErrorBody,
}

#[derive(Debug, Serialize)]
pub struct OpenAIErrorBody {
    pub message: String,
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub param: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub code: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AnthropicErrorEnvelope {
    #[serde(rename = "type")]
    pub kind: String,
    pub error: AnthropicErrorBody,
}

#[derive(Debug, Serialize)]
pub struct AnthropicErrorBody {
    #[serde(rename = "type")]
    pub kind: String,
    pub message: String,
}

pub fn openai_error(
    message: impl Into<String>,
    kind: &str,
    code: Option<&str>,
) -> serde_json::Value {
    serde_json::to_value(OpenAIErrorEnvelope {
        error: OpenAIErrorBody {
            message: message.into(),
            kind: kind.to_owned(),
            param: None,
            code: code.map(|c| c.to_owned()),
        },
    })
    .unwrap_or_else(
        |_| serde_json::json!({"error":{"message":"internal error","type":"server_error"}}),
    )
}

pub fn anthropic_error(message: impl Into<String>, kind: &str) -> serde_json::Value {
    serde_json::to_value(AnthropicErrorEnvelope {
        kind: "error".to_owned(),
        error: AnthropicErrorBody {
            kind: kind.to_owned(),
            message: message.into(),
        },
    }).unwrap_or_else(|_| serde_json::json!({"type":"error","error":{"type":"internal_error","message":"internal error"}}))
}

pub fn responses_error(message: impl Into<String>, kind: &str) -> serde_json::Value {
    openai_error(message, kind, None)
}

/// map a requested model name to the upstream model id.
pub fn resolve_model(requested: Option<&str>) -> &'static str {
    let requested = requested.unwrap_or("default");
    MODEL_ROUTES
        .iter()
        .find(|(r, _)| *r == requested)
        .map(|(_, u)| *u)
        .unwrap_or(MODEL_ROUTES[0].1)
}

/// extract plain text from a chat content payload.
pub fn extract_text(content: &serde_json::Value) -> Result<String> {
    Ok(match content {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Array(parts) => parts
            .iter()
            .filter_map(|part| part.get("text").and_then(|v| v.as_str()))
            .collect(),
        _ => content.to_string(),
    })
}

/// return true when the payload contains tool-use blocks the server rejects.
pub fn tool_use_requested(value: &serde_json::Value) -> bool {
    match value {
        serde_json::Value::Object(map) => {
            let value_type = map.get("type").and_then(|v| v.as_str());
            value_type == Some("tool_use")
                || value_type == Some("tool_result")
                || map.values().any(tool_use_requested)
        }
        serde_json::Value::Array(items) => items.iter().any(tool_use_requested),
        _ => false,
    }
}
