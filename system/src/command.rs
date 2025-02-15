use std::path::PathBuf;

use crate::command;
use crate::util;
use crate::Cli;

pub fn status(cli: &Cli) -> Result<(), String> {
    todo!("Implement status command");
}

pub fn snapshot(cli: &Cli) -> Result<(), String> {
    todo!("Implement snapshot command");
}

pub fn delete(cli: &Cli, id: String) -> Result<(), String> {
    todo!("Implement delete command");
}

pub fn rollback(cli: &Cli, id: String) -> Result<(), String> {
    todo!("Implement rollback command");
}

pub fn build(cli: &Cli) -> Result<(), String> {
    todo!("Implement build command");
}

pub fn lock(_cli: &Cli) -> Result<(), String> {
    util::run(command!("btrfs", "property", "set", "/", "ro", "true"))?;

    println!("Success! System is set to immutable");

    Ok(())
}

pub fn unlock(_cli: &Cli) -> Result<(), String> {
    util::run(command!("btrfs", "property", "set", "/", "ro", "false"))?;

    println!("Success! System is set to immutable");

    Ok(())
}

pub fn rebase(cli: &Cli, branch_name: String, image_path: &Option<PathBuf>) -> Result<(), String> {
    let canonicalized_path = match image_path {
        Some(path) => {
            path.canonicalize()
                .map_err(|e| format!("Failed to canonicalize image path: {}", e))?
        }
        None => {
            todo!("Implement rebase command without image path");
        }
    };
    println!("Rebasing {:?} to {}", canonicalized_path, branch_name);
    todo!("Implement rebase command");
}
