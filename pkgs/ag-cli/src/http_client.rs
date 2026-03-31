use anyhow::Result;
use axum::http::{HeaderMap, HeaderName, HeaderValue};
use serde::de::DeserializeOwned;

/// shared http client and upstream request headers.
pub const USER_AGENT: &str = "ag-cli/0.1.0";
pub const X_ANTIGRAVITY_CLIENT: &str = "x-antigravity-client";
pub const X_ANTIGRAVITY_SYSTEM_INSTRUCTION: &str = "x-antigravity-system-instruction";
pub const SYSTEM_INSTRUCTION: &str = "you are a helpful assistant.";

#[derive(Clone)]
pub struct HttpClient(pub reqwest::Client);
impl HttpClient {
    /// build a `reqwest::Client` with the fixed user agent.
    pub fn new() -> Result<Self> {
        Ok(Self(
            reqwest::Client::builder().user_agent(USER_AGENT).build()?,
        ))
    }

    /// build headers sent on every upstream request.
    pub fn header_map(&self) -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert(X_ANTIGRAVITY_CLIENT, HeaderValue::from_static(USER_AGENT));
        headers.insert(
            X_ANTIGRAVITY_SYSTEM_INSTRUCTION,
            HeaderValue::from_static(SYSTEM_INSTRUCTION),
        );
        headers
    }

    /// build authenticated request headers for google api calls.
    pub fn auth_headers(&self, access_token: &str) -> Result<HeaderMap> {
        let mut headers = self.header_map();
        headers.insert(
            http::header::AUTHORIZATION,
            HeaderValue::from_str(&format!("Bearer {access_token}"))?,
        );
        headers.insert(
            http::header::CONTENT_TYPE,
            HeaderValue::from_static("application/json"),
        );
        headers.insert(
            HeaderName::from_static("x-goog-api-client"),
            HeaderValue::from_static("google-cloud-sdk vscode_cloudshelleditor/0.1"),
        );
        headers.insert(
            HeaderName::from_static("client-metadata"),
            HeaderValue::from_static(
                "{\"ideType\":\"ANTIGRAVITY\",\"platform\":\"LINUX\",\"pluginType\":\"GEMINI\"}",
            ),
        );
        Ok(headers)
    }

    /// post a form body and decode the json response.
    pub async fn post_form<T: DeserializeOwned, S: serde::Serialize>(
        &self,
        url: &str,
        form: &S,
    ) -> Result<T> {
        Ok(self
            .0
            .post(url)
            .headers(self.header_map())
            .form(form)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{extract::Form, routing::post, Json, Router};
    use std::collections::HashMap;
    use tokio::net::TcpListener;

    #[test]
    fn builds_headers() {
        let client = HttpClient::new().unwrap();
        let headers = client.header_map();
        assert_eq!(headers.get(X_ANTIGRAVITY_CLIENT).unwrap(), USER_AGENT);
        let auth = client.auth_headers("token").unwrap();
        assert_eq!(
            auth.get(http::header::AUTHORIZATION).unwrap(),
            "Bearer token"
        );
    }

    #[tokio::test]
    async fn posts_form_and_decodes_json() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/",
            post(|Form(body): Form<HashMap<String, String>>| async move {
                Json(serde_json::json!({"ok": body.get("hello") == Some(&"world".into())}))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });

        let client = HttpClient::new().unwrap();
        let response: serde_json::Value = client
            .post_form(&format!("http://{addr}/"), &[("hello", "world")])
            .await
            .unwrap();
        assert_eq!(response["ok"], true);
    }

    #[tokio::test]
    async fn post_form_returns_error_on_non_success() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route("/", post(|| async { axum::http::StatusCode::BAD_REQUEST }));
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });

        let client = HttpClient::new().unwrap();
        let result = client
            .post_form::<serde_json::Value, _>(&format!("http://{addr}/"), &[("hello", "world")])
            .await;
        assert!(result.is_err());
    }
}
