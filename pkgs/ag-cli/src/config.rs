use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::Path;

use crate::state::{config_path, read_json};

pub const DEFAULT_CLIENT_ID: &str = "";
pub const DEFAULT_CLIENT_SECRET: &str = "";
pub const DEFAULT_REDIRECT_URI: &str = "http://127.0.0.1:57936/callback";
pub const GOOGLE_AUTH_CLIENTS_URL: &str = "https://console.cloud.google.com/apis/credentials";

/// oauth client settings loaded from `config.json`.
///
/// stores optional oauth overrides for the built-in login flow.
#[derive(Debug, Serialize, Deserialize)]
pub struct ConfigFile {
    #[serde(rename = "CLIENT_ID")]
    pub client_id: String,
    #[serde(rename = "CLIENT_SECRET")]
    pub client_secret: String,
    #[serde(rename = "REDIRECT_URI")]
    pub redirect_uri: String,
}

impl Default for ConfigFile {
    fn default() -> Self {
        Self {
            client_id: std::env::var("AG_CLI_CLIENT_ID")
                .unwrap_or_else(|_| DEFAULT_CLIENT_ID.to_owned()),
            client_secret: DEFAULT_CLIENT_SECRET.to_owned(),
            redirect_uri: DEFAULT_REDIRECT_URI.to_owned(),
        }
    }
}

/// read `config.json` and fall back to built-in oauth defaults when it is missing.
pub async fn load_config(root: &Path) -> Result<ConfigFile> {
    read_json(&config_path(root)).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_redirect_uri_is_stable() {
        assert_eq!(ConfigFile::default().redirect_uri, DEFAULT_REDIRECT_URI);
    }

    #[tokio::test]
    async fn loads_real_values() {
        let dir = tempfile::tempdir().unwrap();
        crate::state::write_json(
            &crate::state::config_path(dir.path()),
            &ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        assert_eq!(load_config(dir.path()).await.unwrap().client_id, "id");
    }

    #[tokio::test]
    async fn missing_file_uses_safe_defaults() {
        let dir = tempfile::tempdir().unwrap();
        let config = load_config(dir.path()).await.unwrap();
        assert_eq!(config.client_id, DEFAULT_CLIENT_ID);
        assert_eq!(config.client_secret, DEFAULT_CLIENT_SECRET);
        assert_eq!(config.redirect_uri, DEFAULT_REDIRECT_URI);
    }
}
