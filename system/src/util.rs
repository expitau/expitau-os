use std::{path::PathBuf, process::Command};

pub struct Snapshot {
    pub path: PathBuf,
    pub parent_id: Option<u32>,
    pub id: u32,
}

impl Snapshot {
    pub fn from_str(s: &str) -> Result<Self, String> {
        let parts: Vec<&str> = s.split('-').collect();

        // If does not start with @- or does not have 3 parts, return error
        if !s.starts_with("@-") || parts.len() != 3 {
            return Err(format!("Invalid snapshot string: {}", s));
        }

        todo!("Implement Snapshot::from_str")
    }
}

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
