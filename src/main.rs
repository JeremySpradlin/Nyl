use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Parser, Debug)]
#[command(name = "nyl", version, about = "Local-first Obsidian driven Assistant")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Manage known obsidian vaults
    Vault(VaultArgs),
}

#[derive(Parser, Debug)]
struct VaultArgs {
    #[command(subcommand)]
    action: VaultAction,
}

#[derive(Subcommand, Debug)]
enum VaultAction {
    /// List all known vaults
    List,
    /// Add a new vault (Local Path)
    Add {
        /// Path to the Obsidian vault folder
        path: PathBuf,
    },
}

// --Config Structure------------------------------------------------------------------

#[derive(Serialize, Deserialize, Debug, Default)]
struct Config {
    #[serde(default)]
    vaults: Vec<VaultEntry>,
}

#[derive(Serialize, Deserialize, Debug)]
struct VaultEntry {
    name: String,
    path: String,
}

// --Config File Handling--------------------------------------------------------------

fn config_path() -> PathBuf {
    let mut path = dirs::config_dir().expect("Could not find config directory");
    path.push("nyl");
    path.push("config.toml");
    path
}

fn load_config() -> Result<Config> {
    let path = config_path();

    if !path.exists() {
        return Ok(Config::default());
    }

    let content = fs::read_to_string(&path)
        .context("Failed to read config file")?;
    let config: Config = toml::from_str(&content)
        .context("Failed to parse config TOML")?;

    Ok(config)
}

fn save_config(config: &Config) -> Result<()> {
    let path = config_path();

    // Create parent directories if needed
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).context("Failed to create config directory")?;
    }

    let content = toml::to_string_pretty(config)
        .context("Failed to serialize config to TOML")?;

    fs::write(&path, content).context("Failed to write config file")?;

    Ok(())
}

// --Helpers---------------------------------------------------------------------------

fn derive_vault_name(path: &Path) -> String {
    path.file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("unnamed")
        .to_string()
}

fn validate_vault_path(path: &Path) -> Result<()> {
    if !path.exists() {
        anyhow::bail!("Path does not exist: {}", path.display());
    }
    if !path.is_dir() {
        anyhow::bail!("Path is not a directory: {}", path.display());
    }
    Ok(())
}

// --Main Logic-----------------------------------------------------------------------

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Vault(vault_args) => match vault_args.action {
            VaultAction::List => {
                let config = load_config()?;
                if config.vaults.is_empty() {
                    println!("No known vaults yet.  Add one with: nul vault add <path>");
                } else {
                    println!("Known Vaults:");
                    for (i, vault) in config.vaults.iter().enumerate() {
                        println!(" {:2}. {} -> {}", i + 1, vault.name, vault.path)
                    }
                }
            }

            VaultAction::Add { path } => {
                // Make path absolute for consistency
                let abs_path = path.canonicalize()
                    .context("Invalid or accessible path")?;

                validate_vault_path(&abs_path)?;

                let mut config = load_config()?;

                let name = derive_vault_name(&abs_path);

                // Avoid duplicates by path
                if config.vaults.iter().any(|v| v.path == abs_path.to_string_lossy()) {
                    println!("Vault already known: {}", name);
                    return Ok(())
                }

                config.vaults.push(VaultEntry {
                    name: name.clone(), 
                    path: abs_path.to_string_lossy().into_owned(),
                });

                save_config(&config)?;
                println!("Added vault: {} ({})", name, abs_path.display());
            }
        },
    }
    Ok(())
}
