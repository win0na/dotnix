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
    match cli.command {
        cli::Command::Setup => state::setup(&state).await,
        cli::Command::Login => oauth::login(&state).await,
        cli::Command::Ask { prompt } => server::ask(&state, prompt.join(" ")).await,
        cli::Command::Serve { port } => server::serve(state, port).await,
        cli::Command::Status => state::status(&state).await,
    }
}
