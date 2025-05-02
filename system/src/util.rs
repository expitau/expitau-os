use std::path::PathBuf;
use std::process::Command;

pub fn run(command: &mut Command) -> Result<String, String> {
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

#[macro_export]
macro_rules! command {
    ($cmd:expr) => {
        &mut std::process::Command::new($cmd)
    };
    ($cmd:expr, $($args:expr),+) => {
        &mut std::process::Command::new($cmd).args(&[$($args),+])
    };
}

pub fn get_current_id() -> Result<String, String> {
    let output = run(command!("btrfs", "subvolume", "show", "/"))?;

    let id_line = output
        .lines()
        .next()
        .ok_or("Could not get subvolume ID line")?;

    Ok(id_line.trim().to_string())
}

// Returns an ordered list of <indents, subvolume_name>
pub fn get_subvolume_tree(subvolume_dir: PathBuf) -> Result<Vec<(u32, String)>, String> {
    let output = run(command!(
        "btrfs",
        "subvolume",
        "list",
        "-o",
        subvolume_dir
            .to_str()
            .ok_or("Could not convert subvolume dir to string")?
    ))?;

    let mut subvolumes: Vec<String> = Vec::new();

    for line in output.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 2 {
            continue;
        }

        let subvolume_name = parts.last().ok_or("Could not get subvolume name")?;

        let subvolume_details = run(command!("btrfs", "subvolume", "show", subvolume_dir.join(subvolume_name).to_str().ok_or("Could not convert subvolume name to string")?))?;

        // Regex match for Snapshot(s):(\s+\S+)* Quota
        let re = regex::Regex::new(r"Snapshot\(s\):\s+((?:\s*\S+)*)\s*Quota").map_err(|e| format!("Failed to create regex: {}", e))?;
        let captures = re.captures(&subvolume_details).ok_or("Failed to capture snapshot")?.get(1).map_or(None, |c| Some(c.as_str().split_whitespace().collect::<String>()));

        println!("{:?}", captures);
    }

    todo!()
}
