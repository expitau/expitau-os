mod util;
use util::*;

use chrono;
use clap::{Parser, Subcommand};
use regex::Regex;
use std::io;
use std::io::Write;
use std::path::Path;
use std::process::{self, Command};

#[derive(Parser)]
#[command(name = "system")]
#[command(version = "1.0")]
#[command(about = "System administration toolkit", long_about = None)]
struct Cli {
    /// Btrfs subvolume directory
    #[clap(long, default_value = "/mnt")]
    subvolume_dir: String,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Display the system tree
    Tree,
    /// Create a system snapshot
    Snapshot,
    /// Delete a system snapshot
    Delete {
        /// Snapshot to delete
        snapshot_name: String,
    },
    /// Roll back to a specific snapshot
    Rollback {
        /// Snapshot to rollback to, will use latest if multiple snapshots exist
        #[clap(default_value = "")]
        snapshot_name: String,
    },
    /// Reset the system, optionally specifying a branch
    Reset {
        /// Branch to reset to, defaults to current
        branch: Option<String>,
    },
    /// Put the system in immutable mode
    Lock,
    /// Put the system in writable mode
    Unlock,
    /// Rebuild the system, then switch to the new version
    Migrate {
        /// Path to the new system binary
        file: Option<String>,
    },
}

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Tree => handle_tree(&cli),
        Commands::Snapshot => handle_snapshot(&cli),
        Commands::Rollback { snapshot_name } => handle_rollback(&cli, snapshot_name.to_string()),
        Commands::Migrate { file } => handle_migrate(&cli, file),
        Commands::Reset { branch } => handle_reset(&cli, branch),
        Commands::Delete { snapshot_name } => handle_delete(&cli, snapshot_name.to_string()),
        Commands::Lock => handle_lock(&cli),
        Commands::Unlock => handle_unlock(&cli),
    }
}

#[derive(Debug)]
struct SnapshotInfo {
    name: String,
    date: u32, // The date string with `_` omitted
    tag: Option<String>,
    number: u32,
}

impl SnapshotInfo {
    fn from_str(input: &str) -> Option<Self> {
        let re = Regex::new(r"^@snapshot-([\d_]+)(?:-([a-zA-Z]+))?-?(\d+)$").ok()?;

        let captures = re.captures(input)?;

        let name = input.to_string();
        let date_str = captures.get(1)?.as_str().replace('_', "");
        let date = date_str.parse::<u32>().ok()?;

        let tag = captures.get(2).map(|m| m.as_str().to_string());

        let number = captures.get(3)?.as_str().parse::<u32>().ok()?;

        Some(Self {
            name,
            date,
            tag,
            number,
        })
    }
}

fn handle_build(_cli: &Cli) {
    println!("Running build process...");

    run_command(
        Command::new("cargo")
            .current_dir("/usr/src/system")
            .args(&["build", "--release"]),
    )
    .unwrap_or_else(|e| {
        eprintln!("Failed to build system: {}", e);
        process::exit(1);
    });

    run_command(Command::new("cp").args(&[
        "/usr/src/system/target/release/system",
        "/usr/local/sbin/system",
    ]))
    .unwrap_or_else(|e| {
        eprintln!("Failed to copy system binary: {}", e);
        process::exit(1);
    });
}

// Handle `system list-snapshots --subvolume_dir=/mnt` command
fn handle_tree(cli: &Cli) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Print snapshots
    let snapshots = list_snapshots(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    for snapshot in snapshots {
        println!("{}", snapshot.name);
    }
}

// Handle `system snapshot --subvolume_dir=/mnt` command
fn handle_snapshot(cli: &Cli) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Name snapshot with current date
    let current_date = chrono::Local::now().format("%Y_%m_%d");

    // 3. Create snapshot, append suffix to ensure it is unique
    create_snapshot(
        Path::new(cli.subvolume_dir.as_str()),
        format!("@snapshot-{}", current_date),
    )
    .unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });
}

// Handle `system rollback --subvolume_dir=/mnt --snapshot_name=<query>` command
fn handle_rollback(cli: &Cli, snapshot_name: String) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Figure out what the most recent snapshot that matches the query is
    let mut snapshot_to_use: Option<SnapshotInfo> = None;
    let snapshots = list_snapshots(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // Loop over snapshots, and check if it starts with <snapshot_name> or @<snapshot_name> or @snapshot-<snapshot_name>
    for snapshot in snapshots {
        if snapshot.name.starts_with(&snapshot_name)
            || snapshot.name.starts_with(&format!("@{}", snapshot_name))
            || snapshot
                .name
                .starts_with(&format!("@snapshot-{}", snapshot_name))
        {
            // Choose whichever snapshot has the highest number (latest)
            match &snapshot_to_use {
                Some(existing_snapshot) => {
                    if snapshot.date > existing_snapshot.date
                        || (snapshot.date == existing_snapshot.date
                            && snapshot.number > existing_snapshot.number)
                    {
                        snapshot_to_use = Some(snapshot);
                    }
                }
                None => {
                    snapshot_to_use = Some(snapshot);
                }
            }
        }
    }

    let snapshot_name_full = snapshot_to_use
        .unwrap_or_else(|| {
            eprintln!("Snapshot {} not found", snapshot_name);
            process::exit(1);
        })
        .name;

    // 3. Ask for confirmation to rollback to snapshot
    if !get_confirmation(
        &format!("Rollback to snapshot '{}'?", snapshot_name_full),
        false,
    ) {
        println!("Rollback cancelled");
        process::exit(0);
    }

    // 4. Rollback
    // 4.1. If root is mounted as /mnt/@, move it to /mnt/@_tmp (delete /mnt/@_tmp if exists)
    // 4.2. Delete /mnt/@ if it exists
    // 4.3. Copy /mnt/@<snapshot> to /mnt/@
    println!("Rolling back to snapshot...");
    let root_path = Path::new(cli.subvolume_dir.as_str()).join("@");
    let tmp_root_path = Path::new(cli.subvolume_dir.as_str()).join("@_tmp");
    let new_root_path = Path::new(cli.subvolume_dir.as_str()).join(snapshot_name_full);

    let current_date = chrono::Local::now().format("%Y_%m_%d");
    create_snapshot(
        Path::new(cli.subvolume_dir.as_str()),
        format!("@snapshot-{}-rollback", current_date),
    )
    .unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // Check if root is mounted as @ or @_tmp
    let findmnt_output = run_command(Command::new("findmnt").args(&["-T", "/", "-o", "source"]))
        .unwrap_or_else(|e| {
            eprintln!("Failed to check if root is mounted as @ or @_tmp: {}", e);
            process::exit(1);
        });

    let lines: Vec<&str> = findmnt_output.split('\n').collect();
    let root_mounted_as_tmp = lines.iter().any(|line| line.contains("/@_tmp"));

    // If root is mounted as /mnt/@_tmp, delete /mnt/@
    if root_mounted_as_tmp && root_path.exists() {
        println!("Root is mounted as @_tmp, deleting /mnt/@");
        // If root is already mounted as @_tmp, delete /mnt/@
        run_command(Command::new("btrfs").args(&[
            "subvolume",
            "delete",
            root_path.to_str().unwrap_or_else(|| {
                eprintln!("Failed to convert root path to str");
                process::exit(1);
            }),
        ]))
        .unwrap_or_else(|e| {
            eprintln!("Failed to delete root subvolume: {}", e);
            process::exit(1);
        });
    // If root is mounted as anything else, delete /mnt/@_tmp and move root to /mnt/@_tmp
    } else if !root_mounted_as_tmp {
        println!("Root is not mounted as @_tmp, moving root to @_tmp");
        // If @_tmp already exists, delete it
        if tmp_root_path.exists() {
            println!("Deleting existing @_tmp...");
            run_command(Command::new("btrfs").args(&[
                "subvolume",
                "delete",
                tmp_root_path.to_str().unwrap_or_else(|| {
                    eprintln!("Failed to convert tmp root path to str");
                    process::exit(1);
                }),
            ]))
            .unwrap_or_else(|e| {
                eprintln!("Failed to delete tmp root subvolume: {}", e);
                process::exit(1);
            });
        }

        // Move @ to @_tmp
        run_command(Command::new("mv").args(&[
            root_path.to_str().unwrap_or_else(|| {
                eprintln!("Failed to convert root path to str");
                process::exit(1);
            }),
            tmp_root_path.to_str().unwrap_or_else(|| {
                eprintln!("Failed to convert tmp root path to str");
                process::exit(1);
            }),
        ]))
        .unwrap_or_else(|e| {
            eprintln!("Failed to move root to tmp root: {}", e);
            process::exit(1);
        });
    }

    // Now / -> /mnt/@_tmp, snapshot new root to /mnt/@
    run_command(Command::new("btrfs").args(&[
            "subvolume",
            "snapshot",
            new_root_path.to_str().unwrap_or_else(|| {
                eprintln!("Failed to convert new root path to str");
                process::exit(1);
            }),
            root_path.to_str().unwrap_or_else(|| {
                eprintln!("Failed to convert root path to str");
                process::exit(1);
            }),
        ])).unwrap_or_else(|e| {
            eprintln!("FATAL ERROR: Failed to copy snapshot subvolume to root: {}", e);
            eprintln!("Rollback failed in a dangerous state, attempt to recover manually with `sudo mv {:?} {:?}`", new_root_path, root_path);
            process::exit(1);
        });

    // 5. Ask confirmation then reboot
    if !get_confirmation("Rollback successful! Reboot now?", true) {
        println!("Reboot cancelled");
        process::exit(0);
    }

    run_command(&mut Command::new("reboot")).unwrap_or_else(|e| {
        eprintln!("Failed to reboot: {}", e);
        process::exit(0);
    });
}

fn handle_migrate(cli: &Cli, file: &Option<String>) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    if let Some(file_path) = file {
        // 2. Check if file path exists
        let file_path = Path::new(file_path);
        if !file_path.exists() {
            eprintln!("File {} does not exist", file_path.display());
            process::exit(1);
        }

        // 3. Check if file ends in .sqfs, otherwise prompt user to confirm
        if file_path.extension().unwrap_or_default() != "sqfs" {
            if !get_confirmation(
                "File does not end in .sqfs, are you sure you want to continue?",
                false,
            ) {
                println!("Migration cancelled");
                process::exit(0);
            }
        }

        // 4. Create new tree root

    }
}

fn handle_reset(cli: &Cli, branch: &Option<String>) {
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });
    
    todo!("Implement reset command");
}

fn handle_delete(cli: &Cli, snapshot_name: String) {
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    todo!("Implement delete command");
}

fn handle_lock(cli: &Cli) {
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    todo!("Implement lock command");
}

fn handle_unlock(cli: &Cli) {
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    todo!("Implement unlock command");
}
