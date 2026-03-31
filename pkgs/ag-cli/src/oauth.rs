use anyhow::{anyhow, Context, Result};
use axum::{extract::Query, http::StatusCode, routing::get, Router};
use std::{future::IntoFuture, sync::Arc};
use tokio::{net::TcpListener, sync::Mutex};

use crate::{
    config,
    http_client::HttpClient,
    state::{account_keys, keys_path, read_json, write_json, AccountKeys, AppState, KeysFile},
};

pub const OAUTH_PORT: u16 = 57936;
const AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";

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

/// start the browser login flow and persist the returned tokens.
pub async fn login(state: &AppState) -> Result<()> {
    let config = config::load_config(&state.root).await?;
    let (auth_url, callback_rx, state_token) = start_oauth_listener_with_config(&config).await?;
    println!("open this url to continue:\n{auth_url}");
    let _ = webbrowser::open(&auth_url);
    let callback = callback_rx.await.context("oauth callback channel closed")?;
    validate_callback(&callback, &state_token)?;
    let code = callback
        .code
        .context("oauth callback did not include a code")?;
    let mut keys: KeysFile = read_json(&keys_path(&state.root)).await?;
    let account = account_keys(&mut keys, &state_token);
    account.oauth_code = Some(code.clone());
    account.refresh_token = None;
    match exchange_oauth_code(&state.http, &config, &code).await {
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
    println!("run ag-cli status to confirm auth before starting the server");
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
)> {
    let state_token = uuid::Uuid::new_v4().to_string();
    let auth_url = oauth_authorization_url(config, &state_token)?;
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
    let listener = TcpListener::bind(("127.0.0.1", OAUTH_PORT)).await?;
    tokio::spawn(async move {
        let _ = axum::serve(listener, app).into_future().await;
    });
    Ok((auth_url, rx, state_token))
}

fn oauth_authorization_url(config: &config::ConfigFile, state: &str) -> Result<String> {
    let mut url = url::Url::parse(AUTH_URL)?;
    {
        let mut query = url.query_pairs_mut();
        query
            .append_pair("client_id", &config.client_id)
            .append_pair("redirect_uri", &config.redirect_uri)
            .append_pair("response_type", "code")
            .append_pair(
                "scope",
                "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/cclog https://www.googleapis.com/auth/experimentsandconfigs",
            )
            .append_pair("access_type", "offline")
            .append_pair("prompt", "consent")
            .append_pair("state", state);
    }
    Ok(url.to_string())
}

async fn exchange_oauth_code(
    http: &HttpClient,
    config: &config::ConfigFile,
    code: &str,
) -> Result<OAuthTokenResponse> {
    let body = [
        ("code", code.to_owned()),
        ("client_id", config.client_id.clone()),
        ("client_secret", config.client_secret.clone()),
        ("redirect_uri", config.redirect_uri.clone()),
        ("grant_type", "authorization_code".to_owned()),
    ];
    Ok(http.post_form(TOKEN_URL, &body).await?)
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
    let token: OAuthTokenResponse = http.post_form(TOKEN_URL, &body).await?;
    account.access_token = token.access_token;
    if let Some(new_refresh_token) = token.refresh_token {
        account.refresh_token = Some(new_refresh_token);
    }
    account.token_expires_at = token.expires_in.map(|secs| secs.to_string());
    Ok(())
}
