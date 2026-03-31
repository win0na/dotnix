use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::path::Path;

use crate::state::{config_path, read_json};

pub const DEFAULT_REDIRECT_URI: &str = "http://127.0.0.1:57936/callback";

/// oauth client settings loaded from `config.json`.
///
/// stores the google client id, client secret, and redirect uri used for the
/// local login flow.
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
            client_id: "replace-with-google-oauth-client-id".to_owned(),
            client_secret: "replace-with-google-oauth-client-secret".to_owned(),
            redirect_uri: DEFAULT_REDIRECT_URI.to_owned(),
        }
    }
}

/// read `config.json` and reject empty or placeholder oauth values.
pub async fn load_config(root: &Path) -> Result<ConfigFile> {
    let config: ConfigFile = read_json(&config_path(root)).await?;
    if config.client_id.is_empty()
        || config.client_secret.is_empty()
        || config.redirect_uri.is_empty()
        || config.client_id.starts_with("replace-with-")
        || config.client_secret.starts_with("replace-with-")
    {
        return Err(anyhow!(
            "config.json is missing CLIENT_ID / CLIENT_SECRET; run ag-cli setup and fill them in"
        ));
    }
    Ok(config)
}
