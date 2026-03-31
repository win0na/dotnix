use anyhow::{anyhow, Context, Result};
use axum::{extract::Query, http::StatusCode, routing::get, Router};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use sha2::{Digest, Sha256};
use std::{future::IntoFuture, io::Write, sync::Arc};
use tokio::{net::TcpListener, sync::Mutex};

use crate::{
    config,
    http_client::HttpClient,
    state::{account_keys, keys_path, read_json, write_json, AccountKeys, AppState, KeysFile},
};

const AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const NO_BROWSER_REDIRECT_URI: &str = "https://codeassist.google.com/authcode";

/// query parameters returned to the local oauth callback.
#[derive(Debug, serde::Deserialize)]
struct OAuthCallback {
    code: Option<String>,
    state: Option<String>,
    error: Option<String>,
}

/// token fields returned by the google oauth endpoints.
#[derive(Debug, serde::Serialize, serde::Deserialize)]
struct OAuthTokenResponse {
    access_token: Option<String>,
    refresh_token: Option<String>,
    expires_in: Option<u64>,
    token_type: Option<String>,
    scope: Option<String>,
    error: Option<String>,
    error_description: Option<String>,
}

/// start the browser login flow or the pasted-code login flow.
pub async fn login(state: &AppState, no_browser: bool) -> Result<()> {
    let config = configured_oauth_client(&state.root).await?;
    if no_browser {
        login_no_browser_with(state, &config, read_authorization_code).await
    } else {
        login_with(state, &config, true, webbrowser::open).await
    }
}

pub async fn login_with(
    state: &AppState,
    config: &config::ConfigFile,
    open_browser_enabled: bool,
    open_browser: impl FnOnce(&str) -> std::result::Result<(), std::io::Error>,
) -> Result<()> {
    let (auth_url, callback_rx, state_token, redirect_uri, code_verifier) =
        start_oauth_listener_with_config(config).await?;
    println!("waiting for oauth callback on {redirect_uri}");
    println!("open this url to continue:\n{auth_url}");
    if open_browser_enabled {
        if let Err(err) = open_browser(&auth_url) {
            println!("failed to open a browser automatically: {err}");
            println!("open the url above manually");
        }
    } else {
        println!("browser auto-open disabled; open the url above manually");
    }
    let callback = callback_rx.await.context("oauth callback channel closed")?;
    println!("oauth callback captured; finishing login");
    validate_callback(&callback, &state_token)?;
    complete_login(
        state,
        config,
        &state_token,
        callback
            .code
            .context("oauth callback did not include a code")?,
        &redirect_uri,
        Some(&code_verifier),
    )
    .await
}

async fn login_no_browser_with(
    state: &AppState,
    config: &config::ConfigFile,
    read_code: impl FnOnce(&str) -> Result<String>,
) -> Result<()> {
    let state_token = uuid::Uuid::new_v4().to_string();
    let code_verifier = generate_code_verifier();
    let auth_url = oauth_authorization_url(
        config,
        &state_token,
        NO_BROWSER_REDIRECT_URI,
        Some(&oauth_code_challenge(&code_verifier)),
    )?;
    println!("no-browser login does not start a local callback server");
    println!("open this url to continue:\n{auth_url}");
    println!("after login, paste the authorization code here");
    complete_login(
        state,
        config,
        &state_token,
        read_code("authorization code")?,
        NO_BROWSER_REDIRECT_URI,
        Some(&code_verifier),
    )
    .await
}

pub async fn configured_oauth_client(root: &std::path::Path) -> Result<config::ConfigFile> {
    let config = config::load_config(root).await?;
    if config.client_id.trim().is_empty() || config.client_secret.trim().is_empty() {
        return Err(anyhow!(
            "oauth client is not configured; write CLIENT_ID and CLIENT_SECRET in config.json"
        ));
    }
    Ok(config)
}

async fn complete_login(
    state: &AppState,
    config: &config::ConfigFile,
    state_token: &str,
    code: String,
    redirect_uri: &str,
    code_verifier: Option<&str>,
) -> Result<()> {
    let mut keys: KeysFile = read_json(&keys_path(&state.root)).await?;
    let account = account_keys(&mut keys, state_token);
    account.oauth_code = Some(code.clone());
    account.refresh_token = None;
    match exchange_oauth_code(&state.http, config, &code, redirect_uri, code_verifier).await {
        Ok(token) => {
            account.access_token = token.access_token.clone();
            account.refresh_token = token.refresh_token.clone();
            account.token_expires_at = token.expires_in.map(|secs| secs.to_string());
            println!("oauth code exchanged and stored");
        }
        Err(err) => {
            println!("oauth callback captured, but token exchange failed: {err}");
            println!("the raw oauth code was saved to keys.json for manual recovery");
        }
    }
    write_json(&keys_path(&state.root), &keys).await?;
    println!(
        "run ag-cli --cwd \"{}\" status to confirm auth before starting the server",
        state.root.display()
    );
    Ok(())
}

fn validate_callback(callback: &OAuthCallback, expected_state: &str) -> Result<()> {
    if let Some(err) = &callback.error {
        return Err(anyhow!("oauth callback error: {err}"));
    }
    if callback.state.as_deref() != Some(expected_state) {
        return Err(anyhow!("oauth callback state mismatch"));
    }
    Ok(())
}

async fn start_oauth_listener_with_config(
    config: &config::ConfigFile,
) -> Result<(
    String,
    tokio::sync::oneshot::Receiver<OAuthCallback>,
    String,
    String,
    String,
)> {
    let state_token = uuid::Uuid::new_v4().to_string();
    let code_verifier = generate_code_verifier();
    let (tx, rx) = tokio::sync::oneshot::channel();
    let tx = Arc::new(Mutex::new(Some(tx)));
    let tx2 = tx.clone();
    let app = Router::new().route(
        "/callback",
        get(move |Query(query): Query<OAuthCallback>| {
            let tx = tx2.clone();
            async move {
                if let Some(sender) = tx.lock().await.take() {
                    let _ = sender.send(query);
                }
                (StatusCode::OK, "login captured; return to the cli")
            }
        }),
    );
    let listener = TcpListener::bind(("127.0.0.1", 0)).await?;
    let redirect_uri = format!(
        "http://127.0.0.1:{}/callback",
        listener.local_addr()?.port()
    );
    let auth_url = oauth_authorization_url(
        config,
        &state_token,
        &redirect_uri,
        Some(&oauth_code_challenge(&code_verifier)),
    )?;
    tokio::spawn(async move {
        let _ = axum::serve(listener, app).into_future().await;
    });
    Ok((auth_url, rx, state_token, redirect_uri, code_verifier))
}

fn oauth_authorization_url(
    config: &config::ConfigFile,
    state: &str,
    redirect_uri: &str,
    code_challenge: Option<&str>,
) -> Result<String> {
    let mut url = url::Url::parse(&oauth_authorization_base_url())?;
    {
        let mut query = url.query_pairs_mut();
        query
            .append_pair("client_id", &config.client_id)
            .append_pair("redirect_uri", redirect_uri)
            .append_pair("response_type", "code")
            .append_pair(
                "scope",
                "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile",
            )
            .append_pair("access_type", "offline")
            .append_pair("prompt", "consent")
            .append_pair("state", state);
        if let Some(code_challenge) = code_challenge {
            query
                .append_pair("code_challenge_method", "S256")
                .append_pair("code_challenge", code_challenge);
        }
    }
    Ok(url.to_string())
}

fn oauth_authorization_base_url() -> String {
    std::env::var("AG_CLI_OAUTH_AUTH_URL").unwrap_or_else(|_| AUTH_URL.to_owned())
}

fn oauth_token_url() -> String {
    std::env::var("AG_CLI_OAUTH_TOKEN_URL").unwrap_or_else(|_| TOKEN_URL.to_owned())
}

fn generate_code_verifier() -> String {
    let mut bytes = [0_u8; 32];
    bytes[..16].copy_from_slice(uuid::Uuid::new_v4().as_bytes());
    bytes[16..].copy_from_slice(uuid::Uuid::new_v4().as_bytes());
    URL_SAFE_NO_PAD.encode(bytes)
}

fn oauth_code_challenge(code_verifier: &str) -> String {
    URL_SAFE_NO_PAD.encode(Sha256::digest(code_verifier.as_bytes()))
}

fn read_authorization_code(prompt: &str) -> Result<String> {
    let mut code = String::new();
    print!("paste the {prompt}: ");
    std::io::stdout().flush()?;
    std::io::stdin().read_line(&mut code)?;
    read_authorization_code_from(prompt, &code)
}

fn read_authorization_code_from(prompt: &str, input: &str) -> Result<String> {
    let code = input.trim().to_owned();
    if code.is_empty() {
        return Err(anyhow!("{prompt} is required"));
    }
    Ok(code)
}

async fn exchange_oauth_code(
    http: &HttpClient,
    config: &config::ConfigFile,
    code: &str,
    redirect_uri: &str,
    code_verifier: Option<&str>,
) -> Result<OAuthTokenResponse> {
    let mut body = vec![
        ("code", code.to_owned()),
        ("client_id", config.client_id.clone()),
        ("client_secret", config.client_secret.clone()),
        ("redirect_uri", redirect_uri.to_owned()),
        ("grant_type", "authorization_code".to_owned()),
    ];
    if let Some(code_verifier) = code_verifier {
        body.push(("code_verifier", code_verifier.to_owned()));
    }
    http.post_form(&oauth_token_url(), &body).await
}

/// refresh one account in place and update stored token fields.
pub async fn refresh_account(
    http: &HttpClient,
    config: &config::ConfigFile,
    account: &mut AccountKeys,
) -> Result<()> {
    let refresh_token = account
        .refresh_token
        .clone()
        .context("no refresh_token available")?;
    let body = [
        ("client_id", config.client_id.clone()),
        ("client_secret", config.client_secret.clone()),
        ("refresh_token", refresh_token),
        ("grant_type", "refresh_token".to_owned()),
    ];
    let token: OAuthTokenResponse = http.post_form(&oauth_token_url(), &body).await?;
    account.access_token = token.access_token;
    if let Some(new_refresh_token) = token.refresh_token {
        account.refresh_token = Some(new_refresh_token);
    }
    account.token_expires_at = token.expires_in.map(|secs| secs.to_string());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{routing::post, Json, Router};
    use std::sync::OnceLock;
    use tokio::net::TcpListener;

    fn oauth_test_lock() -> &'static tokio::sync::Mutex<()> {
        static LOCK: OnceLock<tokio::sync::Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| tokio::sync::Mutex::new(()))
    }

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

    fn callback_url(auth_url: &str) -> Result<String> {
        let url = url::Url::parse(auth_url)?;
        let redirect_uri = url
            .query_pairs()
            .find(|(key, _)| key == "redirect_uri")
            .map(|(_, value)| value.to_string())
            .context("redirect_uri missing from auth url")?;
        Ok(redirect_uri)
    }

    #[test]
    fn validates_callback_state() {
        let ok = OAuthCallback {
            code: Some("c".into()),
            state: Some("s".into()),
            error: None,
        };
        assert!(validate_callback(&ok, "s").is_ok());
        let bad = OAuthCallback {
            code: None,
            state: None,
            error: Some("denied".into()),
        };
        assert!(validate_callback(&bad, "s").is_err());
    }

    #[test]
    fn oauth_helpers_use_env_overrides() {
        let _auth = EnvGuard::set("AG_CLI_OAUTH_AUTH_URL", "https://example.com/auth".into());
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", "https://example.com/token".into());
        let cfg = config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: "http://localhost/callback".into(),
        };
        let url =
            oauth_authorization_url(&cfg, "state", "http://localhost/callback", None).unwrap();
        assert!(url.starts_with("https://example.com/auth?"));
        assert!(url.contains("state=state"));
        assert_eq!(oauth_token_url(), "https://example.com/token");
    }

    #[test]
    fn validate_callback_rejects_error_and_state_mismatch() {
        assert!(validate_callback(
            &OAuthCallback {
                code: None,
                state: Some("bad".into()),
                error: None,
            },
            "s"
        )
        .is_err());
        assert!(validate_callback(
            &OAuthCallback {
                code: None,
                state: Some("s".into()),
                error: Some("denied".into()),
            },
            "s"
        )
        .is_err());
    }

    #[test]
    fn builds_authorization_url() {
        let cfg = config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
        };
        let url = oauth_authorization_url(
            &cfg,
            "state",
            "http://127.0.0.1:9999/callback",
            Some("challenge"),
        )
        .unwrap();
        assert!(url.contains("client_id=id"));
        assert!(url.contains("state=state"));
        assert!(url.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A9999%2Fcallback"));
        assert!(url.contains("code_challenge_method=S256"));
        assert!(url.contains("code_challenge=challenge"));
    }

    #[test]
    fn code_verifier_and_challenge_are_url_safe() {
        let verifier = generate_code_verifier();
        assert!(verifier.len() >= 43);
        assert!(!verifier.contains('='));
        let challenge = oauth_code_challenge(&verifier);
        assert!(!challenge.contains('='));
    }

    #[test]
    fn read_authorization_code_rejects_empty_input() {
        assert!(read_authorization_code_from("authorization code", "   ").is_err());
    }

    #[tokio::test]
    async fn refresh_account_uses_override_token_url() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/token",
            post(|| async {
                Json(serde_json::json!({
                    "access_token": "new-token",
                    "refresh_token": "new-refresh",
                    "expires_in": 123
                }))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let old = std::env::var("AG_CLI_OAUTH_TOKEN_URL").ok();
        std::env::set_var("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));

        let http = HttpClient::new().unwrap();
        let cfg = config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
        };
        let mut account = AccountKeys {
            id: "a".into(),
            refresh_token: Some("refresh".into()),
            ..Default::default()
        };
        refresh_account(&http, &cfg, &mut account).await.unwrap();
        assert_eq!(account.access_token.as_deref(), Some("new-token"));
        assert_eq!(account.refresh_token.as_deref(), Some("new-refresh"));
        assert_eq!(account.token_expires_at.as_deref(), Some("123"));

        match old {
            Some(value) => std::env::set_var("AG_CLI_OAUTH_TOKEN_URL", value),
            None => std::env::remove_var("AG_CLI_OAUTH_TOKEN_URL"),
        }
    }

    #[tokio::test]
    async fn refresh_account_keeps_existing_refresh_token_when_missing() {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/token",
            post(|| async { Json(serde_json::json!({"access_token": "fresh", "expires_in": 99})) }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _guard = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));

        let http = HttpClient::new().unwrap();
        let cfg = config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
        };
        let mut account = AccountKeys {
            id: "a".into(),
            refresh_token: Some("refresh".into()),
            ..Default::default()
        };
        refresh_account(&http, &cfg, &mut account).await.unwrap();
        assert_eq!(account.access_token.as_deref(), Some("fresh"));
        assert_eq!(account.refresh_token.as_deref(), Some("refresh"));
        assert_eq!(account.token_expires_at.as_deref(), Some("99"));
    }

    #[tokio::test]
    async fn refresh_account_requires_refresh_token() {
        let http = HttpClient::new().unwrap();
        let cfg = config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
        };
        let mut account = AccountKeys {
            id: "a".into(),
            ..Default::default()
        };
        assert!(refresh_account(&http, &cfg, &mut account).await.is_err());
    }

    #[tokio::test]
    async fn complete_login_stores_exchanged_tokens() {
        let dir = tempfile::tempdir().unwrap();
        write_json(
            &crate::state::config_path(dir.path()),
            &config::ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        write_json(
            &keys_path(dir.path()),
            &KeysFile {
                accounts: vec![AccountKeys {
                    id: "account".into(),
                    ..Default::default()
                }],
            },
        )
        .await
        .unwrap();
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/token",
            post(|| async {
                Json(serde_json::json!({"access_token":"new-token","refresh_token":"new-refresh","expires_in":60}))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _guard = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = AppState::new(Some(dir.path().to_path_buf())).unwrap();
        let config = config::load_config(&state.root).await.unwrap();
        complete_login(
            &state,
            &config,
            "account",
            "code".into(),
            "http://localhost",
            None,
        )
        .await
        .unwrap();
        let keys: KeysFile = read_json(&keys_path(&state.root)).await.unwrap();
        assert_eq!(keys.accounts[0].access_token.as_deref(), Some("new-token"));
    }

    #[tokio::test]
    async fn complete_login_stores_oauth_code_when_exchange_fails() {
        let dir = tempfile::tempdir().unwrap();
        write_json(
            &crate::state::config_path(dir.path()),
            &config::ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route("/token", post(|| async { StatusCode::BAD_REQUEST }));
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _guard = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = AppState::new(Some(dir.path().to_path_buf())).unwrap();
        let config = config::load_config(&state.root).await.unwrap();

        complete_login(
            &state,
            &config,
            "account",
            "code".into(),
            "http://localhost",
            None,
        )
        .await
        .unwrap();

        let keys: KeysFile = read_json(&keys_path(&state.root)).await.unwrap();
        assert_eq!(keys.accounts[0].id, "account");
        assert_eq!(keys.accounts[0].oauth_code.as_deref(), Some("code"));
        assert_eq!(keys.accounts[0].access_token, None);
        assert_eq!(keys.accounts[0].refresh_token, None);
    }

    #[tokio::test]
    async fn login_with_captures_callback_and_persists_tokens() {
        let _guard = oauth_test_lock().lock().await;
        let dir = tempfile::tempdir().unwrap();
        write_json(
            &crate::state::config_path(dir.path()),
            &config::ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/token",
            post(|| async {
                Json(serde_json::json!({
                    "access_token":"new-token",
                    "refresh_token":"new-refresh",
                    "expires_in":60
                }))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = AppState::new(Some(dir.path().to_path_buf())).unwrap();
        let config = config::load_config(&state.root).await.unwrap();
        let client = reqwest::Client::new();

        login_with(&state, &config, true, |auth_url| {
            let state_param = url::Url::parse(auth_url)
                .unwrap()
                .query_pairs()
                .find(|(key, _)| key == "state")
                .map(|(_, value)| value.to_string())
                .unwrap();
            let callback_url = callback_url(auth_url).unwrap();
            let client = client.clone();
            tokio::spawn(async move {
                let _ = client
                    .get(format!("{callback_url}?state={state_param}&code=test-code"))
                    .send()
                    .await;
            });
            Ok(())
        })
        .await
        .unwrap();

        let keys: KeysFile = read_json(&keys_path(&state.root)).await.unwrap();
        assert_eq!(keys.accounts.len(), 1);
        assert_eq!(keys.accounts[0].oauth_code.as_deref(), Some("test-code"));
        assert_eq!(keys.accounts[0].access_token.as_deref(), Some("new-token"));
        assert_eq!(
            keys.accounts[0].refresh_token.as_deref(),
            Some("new-refresh")
        );
    }

    #[tokio::test]
    async fn login_with_survives_browser_open_failure() {
        let _guard = oauth_test_lock().lock().await;
        let dir = tempfile::tempdir().unwrap();
        write_json(
            &crate::state::config_path(dir.path()),
            &config::ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/token",
            post(|| async {
                Json(serde_json::json!({
                    "access_token":"new-token",
                    "refresh_token":"new-refresh",
                    "expires_in":60
                }))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = AppState::new(Some(dir.path().to_path_buf())).unwrap();
        let client = reqwest::Client::new();

        let config = config::load_config(&state.root).await.unwrap();

        login_with(&state, &config, true, |auth_url| {
            let state_param = url::Url::parse(auth_url)
                .unwrap()
                .query_pairs()
                .find(|(key, _)| key == "state")
                .map(|(_, value)| value.to_string())
                .unwrap();
            let callback_url = callback_url(auth_url).unwrap();
            let client = client.clone();
            tokio::spawn(async move {
                let _ = client
                    .get(format!("{callback_url}?state={state_param}&code=test-code"))
                    .send()
                    .await;
            });
            Err(std::io::Error::other("no browser"))
        })
        .await
        .unwrap();
    }

    #[tokio::test]
    async fn login_no_browser_exchanges_pasted_code() {
        let dir = tempfile::tempdir().unwrap();
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let addr = listener.local_addr().unwrap();
        let app = Router::new().route(
            "/token",
            post(|| async {
                Json(serde_json::json!({
                    "access_token":"new-token",
                    "refresh_token":"new-refresh",
                    "expires_in":60
                }))
            }),
        );
        tokio::spawn(async move {
            let _ = axum::serve(listener, app).await;
        });
        let _token = EnvGuard::set("AG_CLI_OAUTH_TOKEN_URL", format!("http://{addr}/token"));
        let state = AppState::new(Some(dir.path().to_path_buf())).unwrap();
        let config = config::ConfigFile {
            client_id: "id".into(),
            client_secret: "secret".into(),
            redirect_uri: config::DEFAULT_REDIRECT_URI.into(),
        };

        login_no_browser_with(&state, &config, |_| Ok("test-code".into()))
            .await
            .unwrap();

        let keys: KeysFile = read_json(&keys_path(&state.root)).await.unwrap();
        assert_eq!(keys.accounts.len(), 1);
        assert_eq!(keys.accounts[0].oauth_code.as_deref(), Some("test-code"));
        assert_eq!(keys.accounts[0].access_token.as_deref(), Some("new-token"));
    }
}
