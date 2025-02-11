use crate::*;

pub fn check_subvolumes_mounted(subvolume_dir: &Path) -> Result<(), String> {
    let mount_path = subvolume_dir
        .to_str()
        .ok_or("Failed to convert subvolume directory path to str")?;

    // Get output of findmnt command
    let findmnt_output =
        run_command(Command::new("findmnt").args(&["-T", mount_path, "-o", "target,fstype"]))?;

    // Get each line of output and check if subvolume directory is mounted
    let lines: Vec<&str> = findmnt_output.split('\n').collect();

    for line in lines {
        if line.starts_with(mount_path) && line.contains("btrfs") {
            return Ok(());
        }
    }

    return Err(format!("Subvolume directory {} is not mounted", mount_path));
}

pub fn list_snapshots(subvolume_dir: &Path) -> Result<Vec<SnapshotInfo>, String> {
    let ls_output = run_command(
        Command::new("ls").args(&[
            "-1",
            subvolume_dir
                .to_str()
                .ok_or("Failed to convert subvolume directory path to str")?,
        ]),
    )?;

    let snapshots: Vec<SnapshotInfo> = ls_output
        .split('\n')
        .filter_map(|s| SnapshotInfo::from_str(s))
        .collect();

    return Ok(snapshots);
}

pub fn create_snapshot(subvolume_dir: &Path, snapshot_name: String) -> Result<(), String> {
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
        Command::new("btrfs").args(&[
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
        ]),
    )?;

    Ok(())
}

pub fn get_confirmation(prompt: &str, default: bool) -> bool {
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

pub fn run_command(command: &mut Command) -> Result<String, String> {
    let output = command.output().map_err(|e| {
        format!(
            "Failed to execute {}: {}",
            command.get_program().to_str().unwrap_or("ERR_GET_COMMAND"),
            e
        )
    })?;

    if !output.status.success() {
        return Err(format!(
            "Command {} exited with error: {}",
            command.get_program().to_str().unwrap_or("ERR_GET_COMMAND"),
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
