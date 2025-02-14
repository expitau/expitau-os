use crate::*;

#[derive(Debug)]
pub struct SnapshotInfo {
    pub path: PathBuf,
    pub uuid: String,
    pub root: String,
    pub root_id: u32,
    pub tag: String,
    pub tag_id: u32,
    pub date: u32,
}

impl SnapshotInfo {
    fn from_str(input: &str) -> Result<Self, String> {
        // @_arch-1-snapshot-2-20251231
        let re = Regex::new(r"uuid ([a-z0-9-]+) path @_([a-zA-Z\d_]+)-(\d+)-([a-zA-Z\d_]+)-(\d+)-(\d{8})$").map_err(|e| format!("Failed to execute regex on input: {}", e))?;

        let captures = re.captures(input).ok_or("Failed to match regex")?;

        let path = PathBuf::from(input).canonicalize().map_err(|e| format!("Failed to canonicalize snapshot path {}: {}", input, e))?;
        let uuid = captures.get(1).ok_or("Failed to get UUID")?.as_str().to_string();
        let root = captures.get(2).ok_or("Failed to get root name")?.as_str();
        let root_id = captures.get(3).ok_or("Failed to get root ID")?.as_str().parse().map_err(|e| format!("Failed to parse root ID: {}", e))?;
        let tag = captures.get(4).ok_or("Failed to get tag name")?.as_str();
        let tag_id = captures.get(5).ok_or("Failed to get tag ID")?.as_str().parse().map_err(|e| format!("Failed to parse tag ID: {}", e))?;
        let date = captures.get(6).ok_or("Failed to get date")?.as_str().parse().map_err(|e| format!("Failed to parse date: {}", e))?;


        Ok(Self {
            path,
            uuid,
            root: root.to_string(),
            root_id,
            tag: tag.to_string(),
            tag_id,
            date,
        })
    }
}

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
        Command::new("btrfs").args(&[
            "subvolume",
            "list",
            "-u",
            subvolume_dir
                .to_str()
                .ok_or("Failed to convert subvolume directory path to str")?,
        ]),
    )?;

    let snapshots: Vec<SnapshotInfo> = ls_output
        .split('\n')
        .filter_map(|s| SnapshotInfo::from_str(s).map_err(|e| println!("Failed to parse snapshot info: {}", e)).ok())
        .collect();

    return Ok(snapshots);
}

pub fn get_snapshot_by_name(subvolume_dir: &Path, name: &str) -> Result<SnapshotInfo, String> {
    let mut snapshot_to_use: Option<SnapshotInfo> = None;
    let snapshots = list_snapshots(subvolume_dir)?;

    // Loop over snapshots, and check if its tag is <name>
    for snapshot in snapshots {
        if snapshot.tag == name
        {
            // Choose whichever snapshot has the highest number (latest)
            match &snapshot_to_use {
                Some(existing_snapshot) => {
                    if snapshot.date > existing_snapshot.date
                        || (snapshot.date == existing_snapshot.date
                            && snapshot.tag_id > existing_snapshot.tag_id)
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

    return snapshot_to_use.ok_or(format!("No snapshot found with tag {}", name));
}

pub fn get_root_branch(subvolume_dir: &Path) -> Result<SnapshotInfo, String> {
    // Get uuid of parent of root (/) subvolume
    let root_uuid_all = run_command(
        Command::new("btrfs")
            .args(&["subvolume", "show", "/"]),
    )?;

    // Parse uuid from output
    let re = Regex::new(r"UUID:\s*([a-f0-9-]+)").map_err(|e| format!("Failed to execute regex on input: {}", e))?;
    let root_uuid = re.captures(&root_uuid_all).ok_or("Failed to match regex")?.get(1).ok_or(format!("Failed to get parent UUID"))?.as_str();

    // If root uuid is -, then it is the core
    if root_uuid == "-" {
        return Err("Root subvolume is the core".to_string());
    }

    // Get snapshot from root uuid
    let snapshot = list_snapshots(subvolume_dir)?
        .into_iter()
        .find(|s| s.uuid == root_uuid)
        .ok_or(format!("No snapshot found with root UUID {}", root_uuid))?;

    return Ok(snapshot);
}

pub fn create_snapshot(subvolume_dir: &Path, tag: String) -> Result<(), String> {
    let current_date = chrono::Local::now().format("%Y%m%d");
    let root = "arch";

    let snapshots = list_snapshots(subvolume_dir)?;

    let mut latest_snapshot_num: Option<u32> = None;
    // Get largest snapshot number
    for snapshot in snapshots {
        if let Some(num) = latest_snapshot_num {
            if snapshot.tag_id > num {
                latest_snapshot_num = Some(snapshot.tag_id);
            }
        } else {
            latest_snapshot_num = Some(snapshot.tag_id);
        }
    }

    let snapshot_num = match latest_snapshot_num {
        Some(num) => num + 1,
        None => 1,
    };

    let snapshot_name = format!("@_{}-{}-{}-{}-{}", "root", "1", tag, snapshot_num, current_date);
    println!("Creating snapshot {}...", snapshot_name);
    run_command(
        Command::new("btrfs").args(&[
            "subvolume",
            "snapshot",
            "-r",
            "/",
            subvolume_dir
                .join(snapshot_name.as_str())
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
