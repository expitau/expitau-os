use clap::{Parser, Subcommand};
use std::process::{self, Command};

#[derive(Parser)]
#[command(name = "system")]
#[command(version = "1.0")]
#[command(about = "System administration toolkit", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Build system components
    Build,
    /// Update system configuration
    Update {
        /// Optional file to update
        file: Option<String>,
    },
    /// Create system snapshot
    Snapshot,
    /// Rollback to previous state
    Rollback,
    /// Reset system configuration
    Reset,
}

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Build => handle_build(),
        Commands::Update { file } => handle_update(file),
        Commands::Snapshot => handle_snapshot(),
        Commands::Rollback => handle_rollback(),
        Commands::Reset => handle_reset(),
    }
}

fn handle_build() {
    println!("Running build process...");
    run_command("ls", &["-l", "-a"]);
}

fn handle_update(file: &Option<String>) {
    println!("Running system update...");
    match file {
        Some(f) => run_command("ls", &[f]),
        None => run_command("ls", &[]),
    }
}

fn handle_snapshot() {
    println!("Creating system snapshot...");
    run_command("ls", &["-l", "/var/snapshots"]);
}

fn handle_rollback() {
    println!("Rolling back system state...");
    run_command("ls", &["-l", "/var/backups"]);
}

fn handle_reset() {
    println!("Resetting system configuration...");
    run_command("ls", &["-a", "/etc/default"]);
}

fn run_command(command: &str, args: &[&str]) {
    let status = Command::new(command)
        .args(args)
        .status()
        .unwrap_or_else(|e| panic!("Failed to execute {}: {}", command, e));

    if !status.success() {
        eprintln!("Command exited with error: {}", status);
        process::exit(1);
    }
}
