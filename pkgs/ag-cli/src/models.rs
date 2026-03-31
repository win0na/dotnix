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
    #[serde(default)]
    pub value: Option<String>,
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
    openai_error(message, kind, Some(kind))
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

pub fn stream_generate_url() -> String {
    std::env::var("AG_CLI_STREAM_GENERATE_URL").unwrap_or_else(|_| STREAM_GENERATE_URL.to_owned())
}

/// extract plain text from a chat content payload.
pub fn extract_text(content: &serde_json::Value) -> Result<String> {
    Ok(match content {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Array(parts) => parts.iter().map(content_part_text).collect(),
        serde_json::Value::Object(map) => map
            .get("text")
            .and_then(|v| v.as_str())
            .or_else(|| map.get("value").and_then(|v| v.as_str()))
            .or_else(|| map.get("content").and_then(|v| v.as_str()))
            .or_else(|| map.get("parts").and_then(text_from_parts))
            .unwrap_or_default()
            .to_owned(),
        _ => content.to_string(),
    })
}

fn content_part_text(part: &serde_json::Value) -> String {
    if let Some(text) = part.get("text").and_then(|v| v.as_str()) {
        return text.to_owned();
    }
    if let Some(text) = part.get("value").and_then(|v| v.as_str()) {
        return text.to_owned();
    }
    if let Some(text) = part.get("content").and_then(|v| v.as_str()) {
        return text.to_owned();
    }
    if let Some(text) = part.as_str() {
        return text.to_owned();
    }
    if let Some(parts) = part.get("parts") {
        return flatten_text_parts(parts);
    }
    String::new()
}

fn text_from_parts(value: &serde_json::Value) -> Option<&str> {
    match value {
        serde_json::Value::Array(parts) => parts.iter().find_map(|part| {
            part.get("text")
                .and_then(|v| v.as_str())
                .or_else(|| part.get("value").and_then(|v| v.as_str()))
                .or_else(|| part.as_str())
        }),
        _ => None,
    }
}

fn flatten_text_parts(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::Array(parts) => parts.iter().map(content_part_text).collect(),
        serde_json::Value::Object(_) => content_part_text(value),
        _ => String::new(),
    }
}

/// extract text from a responses input value while preserving user/system roles.
pub fn responses_input_text(input: &serde_json::Value) -> Result<(Option<String>, String)> {
    match input {
        serde_json::Value::String(text) => Ok((None, text.clone())),
        serde_json::Value::Array(items) => {
            let mut system = None;
            let mut text = String::new();
            for item in items {
                if let Some(role) = item.get("role").and_then(|v| v.as_str()) {
                    let item_text = flatten_text_parts(item.get("content").unwrap_or(item));
                    if role == "system" {
                        system = Some(item_text);
                    } else {
                        if !text.is_empty() {
                            text.push('\n');
                        }
                        text.push_str(&item_text);
                    }
                } else {
                    let item_text = extract_text(item)?;
                    if !text.is_empty() {
                        text.push('\n');
                    }
                    text.push_str(&item_text);
                }
            }
            Ok((system, text))
        }
        _ => Ok((None, extract_text(input)?)),
    }
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

/// return true when a content payload is text-only and safe to flatten.
pub fn text_only_content(value: &serde_json::Value) -> bool {
    match value {
        serde_json::Value::String(_) => true,
        serde_json::Value::Array(items) => items.iter().all(text_only_content),
        serde_json::Value::Object(map) => {
            let kind = map.get("type").and_then(|v| v.as_str()).unwrap_or("text");
            if matches!(kind, "text" | "input_text" | "output_text") {
                map.get("text").and_then(|v| v.as_str()).is_some()
                    || map.get("value").and_then(|v| v.as_str()).is_some()
                    || map.get("content").and_then(|v| v.as_str()).is_some()
                    || map.get("parts").is_some()
            } else {
                false
            }
        }
        _ => false,
    }
}

/// return true when a message content payload contains tool-use or non-text blocks.
pub fn message_content_unsupported_reason(value: &serde_json::Value) -> Option<&'static str> {
    if tool_use_requested(value) {
        return Some("tool_use");
    }
    if !text_only_content(value) {
        return Some("multimodal");
    }
    None
}

/// return true when a messages block list contains tool-use or non-text content.
pub fn message_blocks_unsupported_reason(
    blocks: &[crate::models::MessageBlock],
) -> Option<&'static str> {
    if blocks
        .iter()
        .any(|block| block.kind == "tool_use" || block.kind == "tool_result")
    {
        return Some("tool_use");
    }
    if blocks
        .iter()
        .any(|block| !matches!(block.kind.as_str(), "text" | "input_text" | "output_text"))
    {
        return Some("multimodal");
    }
    None
}

/// return true when a responses input value can be flattened as plain text.
pub fn responses_text_only(input: &serde_json::Value) -> bool {
    match input {
        serde_json::Value::String(_) => true,
        serde_json::Value::Array(items) => items.iter().all(|item| {
            item.get("role")
                .and_then(|v| v.as_str())
                .map(|_| text_only_content(item.get("content").unwrap_or(item)))
                .unwrap_or_else(|| text_only_content(item))
        }),
        serde_json::Value::Object(map) => {
            map.get("role").and_then(|v| v.as_str()).is_some()
                || map.get("text").and_then(|v| v.as_str()).is_some()
                || map.get("value").and_then(|v| v.as_str()).is_some()
                || map.get("content").and_then(|v| v.as_str()).is_some()
                || map.get("parts").map(text_only_content).unwrap_or(false)
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_known_models() {
        assert_eq!(resolve_model(Some("claude-sonnet-4")), "claude-sonnet-4");
        assert_eq!(resolve_model(None), "claude-opus-4-6-thinking");
    }

    #[test]
    fn extracts_text_from_nested_values() {
        let value = serde_json::json!({"parts":[{"text":"hello"},{"value":" world"}]});
        assert_eq!(extract_text(&value).unwrap(), "hello");
        assert_eq!(
            extract_text(&serde_json::json!([{"text":"a"}, {"value":"b"}])).unwrap(),
            "ab"
        );
        assert_eq!(
            extract_text(&serde_json::json!({"content":"plain"})).unwrap(),
            "plain"
        );
        assert_eq!(extract_text(&serde_json::json!(true)).unwrap(), "true");
    }

    #[test]
    fn detects_unsupported_content() {
        assert!(tool_use_requested(&serde_json::json!({"type":"tool_use"})));
        assert_eq!(
            message_content_unsupported_reason(&serde_json::json!({"type":"image"})),
            Some("multimodal")
        );
        assert_eq!(
            message_blocks_unsupported_reason(&[MessageBlock {
                kind: "tool_use".into(),
                text: None,
                value: None
            }]),
            Some("tool_use")
        );
        assert!(responses_text_only(
            &serde_json::json!([{"role":"user","content":"hi"}] )
        ));
        assert!(text_only_content(
            &serde_json::json!({"type":"text","text":"hi"})
        ));
        assert_eq!(
            message_content_unsupported_reason(&serde_json::json!([{"type":"tool_use"}])),
            Some("tool_use")
        );
        assert!(!text_only_content(&serde_json::json!({"type":"image"})));
        assert!(!responses_text_only(&serde_json::json!({"type":"image"})));
    }

    #[test]
    fn builds_error_envelopes_and_urls() {
        assert_eq!(
            openai_error("nope", "bad_request", Some("bad_request"))["error"]["code"],
            "bad_request"
        );
        assert_eq!(
            anthropic_error("nope", "bad_request")["error"]["type"],
            "bad_request"
        );
        assert_eq!(
            responses_error("nope", "bad_request")["error"]["code"],
            "bad_request"
        );
        assert!(stream_generate_url().contains("streamGenerateContent"));
    }

    #[test]
    fn preserves_system_and_joins_response_input() {
        let input = serde_json::json!([
            {"role":"system","content":[{"text":"rules"}]},
            {"role":"developer","content":[{"value":"dev"}]},
            {"role":"user","content":[{"text":"hi"}]}
        ]);
        let (system, text) = responses_input_text(&input).unwrap();
        assert_eq!(system.as_deref(), Some("rules"));
        assert_eq!(text, "dev\nhi");
    }

    #[test]
    fn covers_remaining_text_extraction_shapes() {
        assert_eq!(
            extract_text(&serde_json::json!({"value":"hello"})).unwrap(),
            "hello"
        );
        assert_eq!(
            extract_text(&serde_json::json!({"content":"hello"})).unwrap(),
            "hello"
        );
        assert_eq!(extract_text(&serde_json::json!(true)).unwrap(), "true");
        assert_eq!(
            responses_input_text(&serde_json::json!(123)).unwrap().1,
            "123"
        );
        assert_eq!(
            responses_input_text(&serde_json::json!([
                {"role":"other","content":[{"text":"x"}]},
                {"parts":[{"text":"y"}]}
            ]))
            .unwrap()
            .1,
            "x\ny"
        );
    }

    #[test]
    fn covers_text_only_content_variants() {
        assert!(text_only_content(
            &serde_json::json!({"type":"input_text","value":"hi"})
        ));
        assert!(text_only_content(
            &serde_json::json!({"type":"output_text","content":"hi"})
        ));
        assert!(text_only_content(
            &serde_json::json!({"parts":[{"text":"hi"}]})
        ));
        assert!(!text_only_content(&serde_json::json!(null)));
        assert!(responses_text_only(&serde_json::json!({"role":"user"})));
    }
}
