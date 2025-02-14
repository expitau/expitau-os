mod util;
use util::*;

use chrono;
use clap::{Parser, Subcommand};
use regex::Regex;
use std::io;
use std::io::Write;
use std::path::{Path, PathBuf};
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
    Test,
    /// Display the system tree
    #[clap(aliases = &["ls", "list"])]
    Tree,
    /// Create a system snapshot
    Snapshot,
    /// Delete a system snapshot
    #[clap(aliases = &["rm"])]
    Delete {
        /// Snapshot to delete
        snapshot_name: String,
    },
    /// Roll back to a specific snapshot
    #[clap(aliases = &["restore", "revert"])]
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
    /// Rebuild the system, then switch to the new root
    Migrate {
        /// Path to the new system binary
        file: Option<String>,
    },
}

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Test => handle_test(&cli),
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

fn handle_test(cli: &Cli) {
    println!("Test command");
    println!("{:?}", get_root_branch(Path::new(cli.subvolume_dir.as_str())));
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
        println!("{}", snapshot.tag);
    }
}

// Handle `system snapshot --subvolume_dir=/mnt` command
fn handle_snapshot(cli: &Cli) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 3. Create snapshot, append suffix to ensure it is unique
    create_snapshot(Path::new(cli.subvolume_dir.as_str()), format!("snapshot")).unwrap_or_else(
        |e| {
            eprintln!("{}", e);
            process::exit(1);
        },
    );
}

// Handle `system rollback --subvolume_dir=/mnt --snapshot_name=<query>` command
fn handle_rollback(cli: &Cli, snapshot_name: String) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Figure out what the most recent snapshot that matches the query is
    let snapshot_to_use =
        get_snapshot_by_name(Path::new(cli.subvolume_dir.as_str()), &snapshot_name).unwrap_or_else(
            |e| {
                eprintln!("{}", e);
                process::exit(1);
            },
        );

    let snapshot_name_full = snapshot_to_use.path.file_name().unwrap_or_else(|| {
        eprintln!("Failed to get snapshot name");
        process::exit(1);
    }).to_str().unwrap_or_else(|| {
        eprintln!("Failed to convert snapshot name to str");
        process::exit(1);
    });

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
        format!("rollback"),
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
        let root_name = file_path
            .file_stem()
            .unwrap_or_else(|| {
                eprintln!("Failed to get file stem from path {}", file_path.display());
                process::exit(1);
            })
            .to_str()
            .unwrap_or_else(|| {
                eprintln!("Failed to convert root name to str");
                process::exit(1);
            });

        let snapshots = list_snapshots(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
            eprintln!("{}", e);
            process::exit(1);
        });

        let mut latest_root_id: u32 = 1;

        for snapshot in snapshots {
            if snapshot.root_id > latest_root_id {
                latest_root_id = snapshot.root_id;
            }
        }

        run_command(
            Command::new("btrfs").args(&[
                "subvolume",
                "create",
                &Path::new(cli.subvolume_dir.as_str())
                    .join(format!(
                        "@_{}-{}-0-{}",
                        root_name,
                        latest_root_id + 1,
                        chrono::Local::now().format("%Y%m%d"),
                    ))
                    .as_os_str()
                    .to_str()
                    .unwrap_or_else(|| {
                        eprintln!("Failed to convert snapshot path to str");
                        process::exit(1);
                    }),
            ]),
        )
        .unwrap_or_else(|e| {
            eprintln!("Failed to create new root subvolume: {}", e);
            process::exit(1);
        });
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

    let snapshot_to_delete =
        get_snapshot_by_name(Path::new(cli.subvolume_dir.as_str()), &snapshot_name).unwrap_or_else(
            |e| {
                eprintln!("{}", e);
                process::exit(1);
            },
        );

    let snapshot_name_full = snapshot_to_delete.path.file_name().unwrap_or_else(|| {
        eprintln!("Failed to get snapshot name");
        process::exit(1);
    }).to_str().unwrap_or_else(|| {
        eprintln!("Failed to convert snapshot name to str");
        process::exit(1);
    });

    if !get_confirmation(
        &format!("Delete snapshot '{}'?", snapshot_name_full),
        false,
    ) {
        println!("Delete cancelled");
        process::exit(0);
    }

    run_command(Command::new("btrfs").args(&[
        "subvolume",
        "delete",
        snapshot_to_delete.path.to_str().unwrap_or_else(|| {
            eprintln!("Failed to convert snapshot path to str");
            process::exit(1);
        }),
    ])).unwrap_or_else(|e| {
        eprintln!("Failed to delete snapshot: {}", e);
        process::exit(1);
    });
}

fn handle_lock(cli: &Cli) {
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    run_command(Command::new("btrfs").args(&["property", "set", "/", "ro", "true"]))
        .unwrap_or_else(|e| {
            eprintln!("Failed to lock system: {}", e);
            process::exit(1);
        });

    println!("Success! System is set to immutable")
}

fn handle_unlock(cli: &Cli) {
    check_subvolumes_mounted(Path::new(cli.subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    run_command(Command::new("btrfs").args(&["property", "set", "/", "ro", "false"]))
        .unwrap_or_else(|e| {
            eprintln!("Failed to unlock system: {}", e);
            process::exit(1);
        });

    println!("Success! System is set to mutable")
}
