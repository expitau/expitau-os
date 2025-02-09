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
        #[clap(long, default_value = "")]
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

fn handle_build() {
    println!("Running build process...");
    run_command("ls", &["-l", "-a"]).unwrap();
}

fn handle_update(file: &Option<String>) {
    let tests = vec![
        "@snapshot-2025_02_03-rollback-1",
        "@snapshot-2025_12_29-3",
        "@data",
    ];
    for test in tests {
        let snapshot = SnapshotInfo::from_str(test);
        println!("{:?}", snapshot);
    }
}

// Handle `system snapshot --subvolume_dir=/mnt` command
fn handle_snapshot(subvolume_dir: String) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Name snapshot with current date
    let current_date = chrono::Local::now().format("%Y_%m_%d");

    // 3. Create snapshot, append suffix to ensure it is unique
    create_snapshot(
        Path::new(subvolume_dir.as_str()),
        format!("@snapshot-{}", current_date),
    )
    .unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });
}

// Handle `system rollback --subvolume_dir=/mnt --snapshot_name=<query>` command
fn handle_rollback(subvolume_dir: String, snapshot_name: String) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Figure out what the most recent snapshot that matches the query is
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
    let root_path = Path::new(subvolume_dir.as_str()).join("@");
    let tmp_root_path = Path::new(subvolume_dir.as_str()).join("@_tmp");
    let new_root_path = Path::new(subvolume_dir.as_str()).join(snapshot_name_full);

    let current_date = chrono::Local::now().format("%Y_%m_%d");
    create_snapshot(
        Path::new(subvolume_dir.as_str()),
        format!("@snapshot-{}-rollback", current_date),
    )
    .unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // Check if root is mounted as @ or @_tmp
    let findmnt_output = run_command("findmnt", &["-T", "/", "-o", "source"]).unwrap_or_else(|e| {
        eprintln!("Failed to check if root is mounted as @ or @_tmp: {}", e);
        process::exit(1);
    });

    let lines: Vec<&str> = findmnt_output.split('\n').collect();
    let root_mounted_as_tmp = lines.iter().any(|line| line.contains("/@_tmp"));

    // If root is mounted as /mnt/@_tmp, delete /mnt/@
    if root_mounted_as_tmp && root_path.exists() {
        println!("Root is mounted as @_tmp, deleting /mnt/@");
        // If root is already mounted as @_tmp, delete /mnt/@
        run_command(
            "btrfs",
            &[
                "subvolume",
                "delete",
                root_path.to_str().unwrap_or_else(|| {
                    eprintln!("Failed to convert root path to str");
                    process::exit(1);
                }),
            ],
        )
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
            run_command(
                "btrfs",
                &[
                    "subvolume",
                    "delete",
                    tmp_root_path.to_str().unwrap_or_else(|| {
                        eprintln!("Failed to convert tmp root path to str");
                        process::exit(1);
                    }),
                ],
            )
            .unwrap_or_else(|e| {
                eprintln!("Failed to delete tmp root subvolume: {}", e);
                process::exit(1);
            });
        }

        // Move @ to @_tmp
        run_command(
            "mv",
            &[
                root_path.to_str().unwrap_or_else(|| {
                    eprintln!("Failed to convert root path to str");
                    process::exit(1);
                }),
                tmp_root_path.to_str().unwrap_or_else(|| {
                    eprintln!("Failed to convert tmp root path to str");
                    process::exit(1);
                }),
            ],
        )
        .unwrap_or_else(|e| {
            eprintln!("Failed to move root to tmp root: {}", e);
            process::exit(1);
        });
    }

    // Now / -> /mnt/@_tmp, snapshot new root to /mnt/@
    run_command("btrfs", &[
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

    // 5. Ask confirmation then reboot
    if !get_confirmation("Rollback successful! Reboot now?", true) {
        println!("Reboot cancelled");
        process::exit(0);
    }

    run_command("reboot", &[]).unwrap_or_else(|e| {
        eprintln!("Failed to reboot: {}", e);
        process::exit(0);
    });
}

// Handle `system list-snapshots --subvolume_dir=/mnt` command
fn handle_list_snapshots(subvolume_dir: String) {
    // 1. Check if subvolume directory is mounted as btrfs
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    // 2. Print snapshots
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
    let ls_output = run_command(
        "ls",
        &[
            "-1",
            subvolume_dir
                .to_str()
                .ok_or("Failed to convert subvolume directory path to str")?,
        ],
    )?;

    let snapshots: Vec<SnapshotInfo> = ls_output
        .split('\n')
        .filter_map(|s| SnapshotInfo::from_str(s))
        .collect();

    return Ok(snapshots);
}

fn create_snapshot(subvolume_dir: &Path, snapshot_name: String) -> Result<(), String> {
    let snapshots = list_snapshots(subvolume_dir)?;

    let mut latest_snapshot_num: Option<u32> = None;
    // Get largest snapshot number
    for snapshot in snapshots {
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
    run_command(
        "btrfs",
        &[
            "subvolume",
            "snapshot",
            "/",
            subvolume_dir
                .join(Path::new(
                    format!("{}-{}", snapshot_name, snapshot_num).as_str(),
                ))
                .to_str()
                .unwrap_or_else(|| {
                    eprintln!("Failed to convert snapshot path to str");
                    process::exit(1);
                }),
        ],
    )?;

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
        return !matches!(input.as_str(), "n" | "no"); // Accepts 'n' or 'no' as rejection, default yes
    } else {
        return matches!(input.as_str(), "y" | "yes"); // Accepts 'y' or 'yes' as confirmation, default no
    }
}

fn run_command(command: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(command)
        .args(args)
        .output()
        .map_err(|e| format!("Failed to execute {}: {}", command, e))?;

    if !output.status.success() {
        return Err(format!(
            "Command {} exited with error: {}",
            command,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
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
