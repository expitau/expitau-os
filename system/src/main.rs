use chrono;
use clap::{Parser, Subcommand};
use std::io;
use std::io::Write;
use std::path::Path;
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
    Snapshot {
        /// Btrfs subvolume directory
        #[clap(long, default_value = "/mnt")]
        subvolume_dir: String,
    },
    /// Rollback to previous state
    Rollback {
        /// Btrfs subvolume directory
        #[clap(long, default_value = "/mnt")]
        subvolume_dir: String,
        /// Snapshot to rollback to, will use latest if multiple snapshots exist
        snapshot_name: String,
    },
    /// List snapshots
    ListSnapshots {
        /// Btrfs subvolume directory
        #[clap(long, default_value = "/mnt")]
        subvolume_dir: String,
    },
    /// Reset system configuration
    Reset,
}

struct SnapshotInfo {
    name: String,
    number: u32,
}

fn handle_build() {
    println!("Running build process...");
    run_command("ls", &["-l", "-a"]).unwrap();
}

fn handle_update(file: &Option<String>) {
    println!("Running system update...");
    match file {
        Some(f) => run_command("ls", &[f]).unwrap(),
        None => run_command("ls", &[]).unwrap(),
    };
}

fn handle_snapshot(subvolume_dir: String) {
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    let current_date = chrono::Local::now().format("%Y_%m_%d");
    create_snapshot(
        Path::new(subvolume_dir.as_str()),
        format!("@snapshot-{}", current_date),
    )
    .unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });
}

fn handle_rollback(subvolume_dir: String, snapshot_name: String) {
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    let mut snapshot_to_use: Option<SnapshotInfo> = None;
    let snapshots = list_snapshots(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
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
                    if snapshot.number > existing_snapshot.number {
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

    // Ask for confirmation
    if !get_confirmation(
        &format!("Rollback to snapshot '{}'?", snapshot_name_full),
        false,
    ) {
        println!("Rollback cancelled");
        process::exit(0);
    }

    println!("Rolling back to snapshot...");
    let root_path = Path::new(subvolume_dir.as_str()).join("@");
    let new_root_path = Path::new(subvolume_dir.as_str()).join("@new_root");

    let current_date = chrono::Local::now().format("%Y_%m_%d");
    create_snapshot(
        Path::new(subvolume_dir.as_str()),
        format!("@snapshot-rollback-{}", current_date),
    )
    .unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    run_command("btrfs", &[
            "subvolume",
            "delete",
            root_path.to_str().unwrap_or_else(|| {
                eprintln!("Failed to convert root path to str");
                process::exit(1);
            }),
        ]).unwrap_or_else(|e| {
            eprintln!("Failed to delete root subvolume: {}", e);
            process::exit(1);
        });
    run_command("btrfsa", &[
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
        ]).unwrap_or_else(|e| {
            eprintln!("FATAL ERROR: Failed to copy snapshot subvolume to root: {}", e);
            eprintln!("Rollback failed in a dangerous state, attempt to recover manually with `sudo mv {:?} {:?}`", new_root_path, root_path);
            process::exit(1);
        });

    if !get_confirmation("Rollback successful! Reboot now?", true) {
        println!("Reboot cancelled");
        process::exit(0);
    }

    run_command("reboot", &[]).unwrap_or_else(|e| {
        eprintln!("Failed to reboot: {}", e);
        process::exit(0);
    });
}

fn handle_list_snapshots(subvolume_dir: String) {
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    let snapshots = list_snapshots(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    for snapshot in snapshots {
        println!("{}", snapshot.name);
    }
}

fn handle_reset() {
    println!("Resetting system configuration...");
    run_command("ls", &["-a", "/etc/default"]).unwrap();
}

fn check_subvolumes_mounted(subvolume_dir: &Path) -> Result<(), String> {
    let mount_path = subvolume_dir
        .to_str()
        .ok_or("Failed to convert subvolume directory path to str")?;

    // Get output of findmnt command
    let findmnt_output = run_command("findmnt", &["-T", mount_path, "-o", "target,fstype"])?;

    // Get each line of output and check if subvolume directory is mounted
    let lines: Vec<&str> = findmnt_output.split('\n').collect();

    for line in lines {
        if line.starts_with(mount_path) && line.contains("btrfs") {
            return Ok(());
        }
    }

    return Err(format!("Subvolume directory {} is not mounted", mount_path));
}

fn list_snapshots(subvolume_dir: &Path) -> Result<Vec<SnapshotInfo>, String> {
    let ls_output = run_command("ls", &[
            "-1",
            subvolume_dir
                .to_str()
                .ok_or("Failed to convert subvolume directory path to str")?,
        ])?;

    let snapshots: Vec<SnapshotInfo> = ls_output
        .split('\n')
        .map(|s| s.to_string())
        .filter_map(|s| {
            if s.starts_with("@snapshot") {
                let date = s.split('-').nth(1);
                let number = s.split('-').nth(2);

                return match (date, number) {
                    (Some(_), Some(n)) => match n.parse() {
                        Ok(num) => Some(SnapshotInfo {
                            name: s.clone(),
                            number: num,
                        }),
                        _ => None,
                    },
                    _ => None,
                };
            } else {
                None
            }
        })
        .collect();

    return Ok(snapshots);
}

fn create_snapshot(subvolume_dir: &Path, snapshot_name: String) -> Result<(), String> {
    let snapshots = list_snapshots(subvolume_dir)?;

    let mut latest_snapshot_num: Option<u32> = None;
    for snapshot in snapshots {
        // If snapshot name starts with @snapshot-<date>, parse the number
        if !snapshot.name.starts_with(&snapshot_name) {
            continue;
        }

        if let Some(num) = latest_snapshot_num {
            if snapshot.number > num {
                latest_snapshot_num = Some(snapshot.number);
            }
        } else {
            latest_snapshot_num = Some(snapshot.number);
        }
    }

    let snapshot_num = match latest_snapshot_num {
        Some(num) => num + 1,
        None => 1,
    };

    println!("Creating snapshot {}-{}...", snapshot_name, snapshot_num);
    run_command("btrfs", &[
        "subvolume",
        "snapshot",
        "/",
        subvolume_dir
            .join(Path::new(snapshot_name.as_str()))
            .to_str()
            .unwrap_or_else(|| {
                eprintln!("Failed to convert snapshot path to str");
                process::exit(1);
            }),
    ])?;

    Ok(())
}

fn get_confirmation(prompt: &str, default: bool) -> bool {
    if default {
        print!("{} [Y/n]: ", prompt);
    } else {
        print!("{} [y/N]: ", prompt);
    }

    io::stdout().flush().unwrap(); // Ensure the prompt is displayed immediately

    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();
    let input = input.trim().to_lowercase();

    if default {
        return matches!(input.as_str(), "n" | "no"); // Accepts 'n' or 'no' as rejection, default yes
    } else {
        return matches!(input.as_str(), "y" | "yes"); // Accepts 'y' or 'yes' as confirmation, default no
    }
}

fn run_command(command: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(command)
        .args(args)
        .stdout(std::process::Stdio::null())
        .output()
        .map_err(|e| format!("Failed to execute {}: {}", command, e))?;

    if !output.status.success() {
        return Err(format!("Command exited with error: {}", output.status));
    }

    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn main() {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Build => handle_build(),
        Commands::Update { file } => handle_update(file),
        Commands::Snapshot { subvolume_dir } => handle_snapshot(subvolume_dir.to_string()),
        Commands::Rollback {
            subvolume_dir,
            snapshot_name,
        } => handle_rollback(subvolume_dir.to_string(), snapshot_name.to_string()),
        Commands::ListSnapshots { subvolume_dir } => {
            handle_list_snapshots(subvolume_dir.to_string())
        }
        Commands::Reset => handle_reset(),
    }
}
