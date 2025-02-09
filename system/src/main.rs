use chrono;
use clap::{Parser, Subcommand};
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
        /// Default: /mnt
        #[clap(short, long, default_value = "/mnt")]
        subvolume_dir: String,
    },
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
        Commands::Snapshot { subvolume_dir } => handle_snapshot(subvolume_dir.to_string()),
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

fn handle_snapshot(subvolume_dir: String) {
    check_subvolumes_mounted(Path::new(subvolume_dir.as_str())).unwrap_or_else(|e| {
        eprintln!("{}", e);
        process::exit(1);
    });

    let current_date = chrono::Local::now().format("%Y-%m-%d");
    let subvolumes_ls = Command::new("ls")
        .args(&["-1", &subvolume_dir])
        .output()
        .unwrap_or_else(|e| {
            eprintln!("Failed to execute ls: {}", e);
            process::exit(1);
        });
    
    let subvolumes_ls_output = String::from_utf8_lossy(&subvolumes_ls.stdout);
    let subvolumes: Vec<&str> = subvolumes_ls_output
        .split('\n')
        .collect();

    let mut latest_snapshot_num: Option<u32> = None;
    for subvolume in subvolumes {
        // If snapshot name starts with @snapshot-<date>, parse the number
        if !subvolume.starts_with("@snapshot-") {
            continue;
        } 
        
        if !subvolume.contains(&current_date.to_string()) {
            continue;
        }

        let snapshot_num: u32 = subvolume
            .split('-')
            .last()
            .unwrap_or_else(|| {
                eprintln!("Failed to parse snapshot number");
                process::exit(1);
            })
            .parse()
            .unwrap_or_else(|e| {
                eprintln!("Failed to parse snapshot number: {}", e);
                process::exit(1);
            });
        
        if let Some(num) = latest_snapshot_num {
            if snapshot_num > num {
                latest_snapshot_num = Some(snapshot_num);
            }
        } else {
            latest_snapshot_num = Some(snapshot_num);
        }
    }

    let snapshot_num = match latest_snapshot_num {
        Some(num) => num + 1,
        None => 1,
    };
    let snapshot_name = format!("@snapshot-{}-{}", current_date, snapshot_num);

    println!("Creating snapshot {}...", snapshot_name);
}

fn handle_rollback() {
    println!("Rolling back system state...");
    run_command("ls", &["-l", "/var/backups"]);
}

fn handle_reset() {
    println!("Resetting system configuration...");
    run_command("ls", &["-a", "/etc/default"]);
}

fn check_subvolumes_mounted(mount_dir: &Path) -> Result<(), String> {
    let mount_path = mount_dir
        .to_str()
        .expect("Failed to convert mount_dir to str");

    // Get output of findmnt command
    let output = match Command::new("findmnt")
        .args(&["-T", mount_path, "-o", "target,fstype"])
        .output()
    {
        Ok(output) => output,
        Err(e) => {
            return Err(format!("Failed to execute findmnt command: {}", e));
        }
    };

    if !output.status.success() {
        return Err(format!(
            "Command findmnt exited with error: {}",
            output.status.code().unwrap()
        ));
    }

    let output_str = String::from_utf8_lossy(&output.stdout);
    let lines: Vec<&str> = output_str.split('\n').collect();

    for line in lines {
        if line.starts_with(mount_path) && line.contains("btrfs") {
            return Ok(());
        }
    }

    return Err(format!("Subvolume directory {} is not mounted", mount_path));
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
