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
    Login,
    Ask {
        prompt: Vec<String>,
    },
    Serve {
        #[arg(long, default_value_t = DEFAULT_PORT)]
        port: u16,
    },
    Status,
}
