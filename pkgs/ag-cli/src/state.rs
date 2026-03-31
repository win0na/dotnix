use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tokio::{fs, io::AsyncWriteExt};

use crate::{config, http_client::HttpClient};

/// shared app state for cli commands and the local server.
///
/// stores the workspace root and the shared http client used for upstream
/// requests.
#[derive(Clone)]
pub struct AppState {
    pub root: PathBuf,
    pub http: HttpClient,
}

impl AppState {
    pub fn new(cwd: Option<PathBuf>) -> Result<Self> {
        Ok(Self {
            root: cwd.unwrap_or(std::env::current_dir()?),
            http: HttpClient::new()?,
        })
    }
}

/// persisted account list stored in `keys.json`.
#[derive(Debug, Serialize, Deserialize)]
pub struct KeysFile {
    #[serde(default)]
    pub accounts: Vec<AccountKeys>,
}

impl Default for KeysFile {
    fn default() -> Self {
        Self {
            accounts: Vec::new(),
        }
    }
}

/// oauth and access token state for one account.
#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct AccountKeys {
    pub id: String,
    #[serde(default)]
    pub oauth_code: Option<String>,
    #[serde(default)]
    pub refresh_token: Option<String>,
    #[serde(default)]
    pub access_token: Option<String>,
    #[serde(default)]
    pub token_expires_at: Option<String>,
    #[serde(default)]
    pub last_auth_failure_at: Option<u64>,
}

/// return the path to `config.json`.
pub fn config_path(root: &Path) -> PathBuf {
    root.join("config.json")
}
/// return the path to `keys.json`.
pub fn keys_path(root: &Path) -> PathBuf {
    root.join("keys.json")
}

/// read json from disk or return `Default` when the file is missing.
pub async fn read_json<T: Default + for<'de> Deserialize<'de>>(path: &Path) -> Result<T> {
    match fs::read(path).await {
        Ok(bytes) => Ok(serde_json::from_slice(&bytes)?),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(T::default()),
        Err(err) => Err(err.into()),
    }
}
/// write pretty-printed json to disk and end the file with a newline.
pub async fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).await.ok();
    }
    let mut file = fs::File::create(path).await?;
    file.write_all(serde_json::to_string_pretty(value)?.as_bytes())
        .await?;
    file.write_all(b"\n").await?;
    Ok(())
}

/// return the account entry for `id`, creating it when needed.
pub fn account_keys<'a>(keys: &'a mut KeysFile, id: &str) -> &'a mut AccountKeys {
    if let Some(index) = keys.accounts.iter().position(|a| a.id == id) {
        return &mut keys.accounts[index];
    }
    keys.accounts.push(AccountKeys {
        id: id.to_owned(),
        ..AccountKeys::default()
    });
    keys.accounts.last_mut().expect("just pushed")
}

/// create default config and key files when they do not exist.
pub async fn setup(state: &AppState) -> Result<()> {
    if !config_path(&state.root).exists() {
        write_json(&config_path(&state.root), &config::ConfigFile::default()).await?;
    }
    if !keys_path(&state.root).exists() {
        write_json(&keys_path(&state.root), &KeysFile::default()).await?;
    }
    println!(
        "initialized config.json and keys.json in {}\nfill in config.json, then run ag-cli login",
        state.root.display()
    );
    Ok(())
}

/// load accounts, refresh expired tokens, sort them, and persist the result.
pub async fn get_valid_accounts(state: &AppState) -> Result<KeysFile> {
    let config = config::load_config(&state.root).await?;
    let mut keys: KeysFile = read_json(&keys_path(&state.root)).await?;
    for account in &mut keys.accounts {
        if account.access_token.is_none() && account.refresh_token.is_some() {
            let _ = crate::oauth::refresh_account(&state.http, &config, account).await;
        }
    }
    keys.accounts.sort_by_key(account_sort_key);
    write_json(&keys_path(&state.root), &keys).await?;
    Ok(keys)
}

fn account_sort_key(account: &AccountKeys) -> (bool, u64) {
    (
        account.access_token.is_none(),
        account.last_auth_failure_at.unwrap_or(0),
    )
}

/// print config and account status for the current workspace.
pub async fn status(state: &AppState) -> Result<()> {
    let cfg = read_json::<config::ConfigFile>(&config_path(&state.root)).await?;
    let usable_cfg = config_is_usable(&cfg);
    let keys = get_valid_accounts(state).await?;
    println!("config usable: {}", usable_cfg);
    println!("config redirect uri: {}", cfg.redirect_uri);
    println!("keys accounts: {}", keys.accounts.len());
    if keys.accounts.is_empty() {
        println!("run ag-cli setup, then ag-cli login");
    } else {
        for account in &keys.accounts {
            println!(
                "- {} access_token={} refresh_token={}",
                account.id,
                account.access_token.is_some(),
                account.refresh_token.is_some()
            );
        }
    }
    Ok(())
}

fn config_is_usable(cfg: &config::ConfigFile) -> bool {
    !(cfg.client_id.is_empty()
        || cfg.client_secret.is_empty()
        || cfg.redirect_uri.is_empty()
        || cfg.client_id.starts_with("replace-with-")
        || cfg.client_secret.starts_with("replace-with-"))
}
