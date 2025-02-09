use chrono;
use clap::{Parser, Subcommand};
use std::os::linux::raw::stat;
use std::path::Path;
use std::process::{self, Command};
use std::io;
use std::io::Write;

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
        /// Default: /mnt
        #[clap(short, long, default_value = "/mnt")]
        subvolume_dir: String,
    },
    /// Rollback to previous state
    Rollback {
        /// Btrfs subvolume directory
        /// Default: /mnt
        #[clap(short, long, default_value = "/mnt")]
        subvolume_dir: String,
        /// Snapshot to rollback to, will use latest if multiple snapshots exist
        snapshot_name: String,
    },
    /// Reset system configuration
    Reset,
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

fn handle_snapshot(subvolume_dir: String) {
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    let current_date = chrono::Local::now().format("%Y%m%d");
    let snapshots = list_snapshots(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    let mut latest_snapshot_num: Option<u32> = None;
    for snapshot in snapshots {
        // If snapshot name starts with @snapshot-<date>, parse the number
        if !snapshot.name.starts_with("@snapshot-") {
            continue;
        }

        if !snapshot.date.contains(&current_date.to_string()) {
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
    let snapshot_name = format!("@snapshot-{}-{}", current_date, snapshot_num);

    println!("Creating snapshot {}...", snapshot_name);
    Command::new("btrfs")
        .args(&[
            "subvolume",
            "snapshot",
            "/",
            Path::new(subvolume_dir.as_str())
                .join(Path::new(snapshot_name.as_str()))
                .to_str()
                .unwrap_or_else(|| {
                    eprintln!("Failed to convert snapshot path to str");
                    process::exit(1);
                }),
        ])
        .status()
        .unwrap_or_else(|e| {
            eprintln!("Failed to execute btrfs: {}", e);
            process::exit(1);
        });
}

struct SnapshotInfo {
    name: String,
    date: String,
    number: u32,
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
                .date
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

    let snapshot_name_full = snapshot_to_use.unwrap_or_else(|| {
        eprintln!("Snapshot {} not found", snapshot_name);
        process::exit(1);
    }).name;

    // Ask for confirmation
    if !get_confirmation(&format!(
        "Rollback to snapshot '{}'? [y/N]: ",
        snapshot_name_full
    )) {
        println!("Rollback cancelled");
        process::exit(0);
    }

    println!("Rolling back to snapshot...");
    let root = Path::new(subvolume_dir.as_str()).join("@");
    let root_bak = Path::new(subvolume_dir.as_str()).join("@_old");
    let new_root = Path::new(subvolume_dir.as_str()).join(&snapshot_name_full);
    
    Command::new("mv")
        .args(&[root.as_os_str(), root_bak.as_os_str()])
        .status()
        .unwrap_or_else(|e| {
            eprintln!("Failed to execute mv: {}", e);
            process::exit(1);
        });
    

    Command::new("mv")
        .args(&[new_root.as_os_str(), root.as_os_str()])
        .status()
        .unwrap_or_else(|e| {
            eprintln!("Failed to execute mv: {}", e);
            process::exit(1);
        });

    println!("Rollback successful! Reboot now? [Y/n]: ");
    if !get_confirmation("") {
        println!("Reboot cancelled");
        process::exit(0);
    }

    Command::new("reboot")
        .status()
        .unwrap_or_else(|e| {
            eprintln!("Failed to execute reboot: {}", e);
            process::exit(1);
        });
}

fn handle_reset() {
    println!("Resetting system configuration...");
    run_command("ls", &["-a", "/etc/default"]);
}

fn check_subvolumes_mounted(subvolume_dir: &Path) -> Result<(), String> {
    let mount_path = subvolume_dir
        .to_str()
        .ok_or("Failed to convert subvolume directory path to str")?;

    // Get output of findmnt command
    let output = Command::new("findmnt")
        .args(&["-T", mount_path, "-o", "target,fstype"])
        .output()
        .map_err(|e| format!("Failed to execute findmnt command: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "Command findmnt exited with error: {}",
            output.status.code().unwrap()
        ));
    }

    // Get each line of output and check if subvolume directory is mounted
    let output_str = String::from_utf8_lossy(&output.stdout);
    let lines: Vec<&str> = output_str.split('\n').collect();

    for line in lines {
        if line.starts_with(mount_path) && line.contains("btrfs") {
            return Ok(());
        }
    }

    return Err(format!("Subvolume directory {} is not mounted", mount_path));
}

fn list_snapshots(subvolume_dir: &Path) -> Result<Vec<SnapshotInfo>, String> {
    let snapshots_ls = Command::new("ls")
        .args(&[
            "-1",
            subvolume_dir
                .to_str()
                .ok_or("Failed to convert subvolume directory path to str")?,
        ])
        .output()
        .map_err(|e| format!("Failed to execute ls: {}", e))?;

    let snapshots_ls_output = String::from_utf8_lossy(&snapshots_ls.stdout);
    let snapshots: Vec<SnapshotInfo> = snapshots_ls_output
        .split('\n')
        .map(|s| s.to_string())
        .filter_map(|s| {
            if s.starts_with("@snapshot") {
                let date = s.split('-').nth(1);
                let number = s.split('-').nth(2);

                return match (date, number) {
                    (Some(d), Some(n)) => match n.parse() {
                        Ok(num) => Some(SnapshotInfo {
                            name: s.clone(),
                            date: d.to_string(),
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

fn get_confirmation(prompt: &str) -> bool {
    print!("{}", prompt);
    io::stdout().flush().unwrap(); // Ensure the prompt is displayed immediately

    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();
    let input = input.trim().to_lowercase();

    matches!(input.as_str(), "y" | "yes") // Accepts 'y' or 'yes' as confirmation
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
