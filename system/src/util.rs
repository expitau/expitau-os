use std::{path::PathBuf, process::Command};

pub fn run(command: &mut Command) -> Result<String, String> {
    println!("Running command {:?}", command);
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

pub fn get_current_id(subvolume_path: &PathBuf) -> Result<String, String> {
    let output = run(command!(
        "btrfs",
        "subvolume",
        "show",
        subvolume_path.to_string_lossy().as_ref()
    ))?;

    let id_line = output
        .lines()
        .next()
        .ok_or("Could not get subvolume ID line")?;

    Ok(id_line.trim().to_string())
}
