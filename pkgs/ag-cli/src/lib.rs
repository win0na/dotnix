//! top-level command dispatch for `ag-cli`.
//!
//! parses cli arguments, builds shared app state, and routes each subcommand to
//! the module that does the work.

pub mod cli;
pub mod config;
pub mod http_client;
pub mod models;
pub mod oauth;
pub mod server;
pub mod state;

use anyhow::Result;
use clap::Parser;

/// parse the command line, build shared state, and run the selected command.
pub async fn run() -> Result<()> {
    tracing_subscriber::fmt::init();
    let cli = cli::Cli::parse();
    let state = state::AppState::new(cli.cwd)?;
    dispatch(&state, cli.command).await
}

pub async fn dispatch(state: &state::AppState, command: cli::Command) -> Result<()> {
    match command {
        cli::Command::Setup => state::setup(state).await,
        cli::Command::Login { no_browser } => oauth::login(state, no_browser).await,
        cli::Command::Ask { prompt } => server::ask(state, prompt.join(" ")).await,
        cli::Command::Serve { port } => server::serve(state.clone(), port).await,
        cli::Command::Status => state::status(state).await,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn dispatch_handles_setup_and_status() {
        let dir = tempfile::tempdir().unwrap();
        let state = state::AppState::new(Some(dir.path().to_path_buf())).unwrap();
        dispatch(&state, cli::Command::Setup).await.unwrap();
        state::write_json(
            &state::config_path(&state.root),
            &crate::config::ConfigFile {
                client_id: "id".into(),
                client_secret: "secret".into(),
                redirect_uri: crate::config::DEFAULT_REDIRECT_URI.into(),
            },
        )
        .await
        .unwrap();
        dispatch(&state, cli::Command::Status).await.unwrap();
    }
}
