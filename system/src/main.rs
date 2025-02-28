mod command;
mod util;

use std::path::{Path, PathBuf};

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "system")]
#[command(version = "1.0")]
#[command(about = "System administration toolkit", long_about = None)]
struct Cli {
    /// Btrfs subvolume directory
    #[clap(long, default_value = "/mnt")]
    subvolume_dir: String,

    /// Build directory
    #[clap(long, default_value = "/usr/src/system")]
    build_dir: String,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Show the status of the system
    Status,
    /// Create a new snapshot
    Snapshot {
        id: String,
    },
    /// Delete a snapshot
    Delete {
        /// ID of the snapshot to delete
        id: String,
    },
    /// Rollback to a snapshot
    Rollback {
        /// ID of the snapshot to rollback to
        id: String,
    },
    /// Put the system in immutable mode
    Lock,
    /// Put the system in writable mode
    Unlock,
    /// Build a new system image, without rebasing to it
    Build,
    /// Rebase to filesystem image
    Rebase {
        /// Unique name for this branch
        branch_name: String,
        /// Path to the new system image (use local build if not provided)
        image_path: Option<PathBuf>,
    },
}

impl Cli {
    fn get_subvolume_dir(&self) -> Result<PathBuf, String> {
        let subvolume_path = Path::new(&self.subvolume_dir).canonicalize().map_err(|e| {
            format!(
                "Failed to canonicalize subvolume directory {}: {}",
                self.subvolume_dir, e
            )
        })?;

        // Get output of findmnt command
        let findmnt_output = util::run(command!(
            "findmnt",
            "-T",
            subvolume_path
                .to_str()
                .ok_or("Could not convert subvolume dir to string")?,
            "-o",
            "target,fstype"
        ))?;
        // Get each line of output and check if subvolume directory is mounted
        let lines: Vec<&str> = findmnt_output.split('\n').collect();

        for line in lines {
            if line.starts_with(&self.subvolume_dir) && line.contains("btrfs") {
                return Ok(subvolume_path.to_path_buf());
            }
        }

        return Err(format!(
            "Subvolume directory {} is not mounted",
            subvolume_path
                .to_str()
                .ok_or("Could not convert subvolume dir to string")?
        ));
    }

    fn get_build_dir(&self) -> Result<PathBuf, String> {
        let build_path = Path::new(&self.build_dir).canonicalize().map_err(|e| {
            format!(
                "Failed to canonicalize build directory {}: {}",
                self.build_dir, e
            )
        })?;

        if !build_path.exists() {
            return Err(format!(
                "Build directory {} does not exist",
                build_path
                    .to_str()
                    .ok_or("Could not convert build dir to string")?
            ));
        }

        Ok(build_path.to_path_buf())
    }
}

fn main() {
    let cli = Cli::parse();

    let result = match &cli.command {
        Commands::Status => command::status(&cli),
        Commands::Snapshot { id } => command::snapshot(&cli, id.to_string()),
        Commands::Delete { id } => command::delete(&cli, id.to_string()),
        Commands::Rollback { id } => command::rollback(&cli, id.to_string()),
        Commands::Lock => command::lock(&cli),
        Commands::Unlock => command::unlock(&cli),
        Commands::Build => command::build(&cli),
        Commands::Rebase {
            branch_name,
            image_path,
        } => command::rebase(&cli, branch_name.to_string(), image_path),
    };

    if let Err(e) = result {
        eprintln!("{}", e);
        std::process::exit(1);
    }

    std::process::exit(0);
}
