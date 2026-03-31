#[tokio::main]
async fn main() -> anyhow::Result<()> {
    ag_cli::run().await
}
