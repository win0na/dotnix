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
