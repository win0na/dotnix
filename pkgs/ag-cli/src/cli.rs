use clap::{Parser, Subcommand};
use std::path::PathBuf;

use crate::server::DEFAULT_PORT;

#[derive(Parser)]
#[command(name = "ag-cli", version, about = "ag-cli")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,

    #[arg(long, global = true)]
    pub cwd: Option<PathBuf>,
}

#[derive(Subcommand)]
pub enum Command {
    Setup,
    Login {
        #[arg(long)]
        no_browser: bool,
    },
    Ask {
        prompt: Vec<String>,
    },
    Serve {
        #[arg(long, default_value_t = DEFAULT_PORT)]
        port: u16,
    },
    Status,
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;

    #[test]
    fn parses_setup_and_status() {
        assert!(matches!(
            Cli::parse_from(["ag-cli", "setup"]).command,
            Command::Setup
        ));
        assert!(matches!(
            Cli::parse_from(["ag-cli", "status"]).command,
            Command::Status
        ));
        assert!(matches!(
            Cli::parse_from(["ag-cli", "login"]).command,
            Command::Login { no_browser: false }
        ));
        assert!(matches!(
            Cli::parse_from(["ag-cli", "login", "--no-browser"]).command,
            Command::Login { no_browser: true }
        ));
    }

    #[test]
    fn parses_ask_and_serve_options() {
        let cli = Cli::parse_from(["ag-cli", "--cwd", "/tmp", "ask", "hello", "world"]);
        assert_eq!(cli.cwd.unwrap(), PathBuf::from("/tmp"));
        match cli.command {
            Command::Ask { prompt } => assert_eq!(prompt, vec!["hello", "world"]),
            _ => panic!("expected ask command"),
        }

        match Cli::parse_from(["ag-cli", "serve"]).command {
            Command::Serve { port } => assert_eq!(port, DEFAULT_PORT),
            _ => panic!("expected serve command"),
        }
    }
}
