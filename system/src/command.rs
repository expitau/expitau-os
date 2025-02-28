use std::fmt::format;
use std::path::PathBuf;

use crate::command;
use crate::util;
use crate::Cli;

pub fn status(cli: &Cli) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    // List all snapshots
    let snapshots = util::run(command!("btrfs", "subvolume", "list", subvolume_dir.to_string_lossy().as_ref()))?;

    println!("Snapshots: {}", snapshots);

    Ok(())
}

pub fn snapshot(cli: &Cli, id: String) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    util::run(command!("btrfs", "subvolume", "snapshot", "/", snapshot_path.to_string_lossy().as_ref()))?;

    println!("Snapshot {} created", id);

    Ok(())
}

pub fn delete(cli: &Cli, id: String) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    util::run(command!("btrfs", "subvolume", "delete", snapshot_path.to_string_lossy().as_ref()))?;

    println!("Snapshot {} deleted", id);

    Ok(())
}

pub fn rollback(cli: &Cli, id: String) -> Result<(), String> {
    // Rollback
    // 1. If root is mounted as /mnt/@, move it to /mnt/@_tmp (delete /mnt/@_tmp if exists)
    // 2. Delete /mnt/@ if it exists
    // 3. Copy /mnt/@<snapshot> to /mnt/@

    let subvolume_dir = cli.get_subvolume_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    let root_path = subvolume_dir.join("@");
    let root_tmp_path = subvolume_dir.join("@_tmp");
    let rollback_path = subvolume_dir.join(format!("@rollback-{}-{}", id, chrono::Local::now().format("%Y%m%d%H%M%S")));

    util::run(command!("btrfs", "subvolume", "snapshot", root_path.to_string_lossy().as_ref(), rollback_path.to_string_lossy().as_ref()))?;

    let findmnt_output = util::run(command!("findmnt", "-T", root_path.to_string_lossy().as_ref(), "-o", "target,fstype"))?;
    let lines: Vec<&str> = findmnt_output.split('\n').collect();
    let root_mounted_as_tmp = lines.iter().any(|line| line.contains("/@_tmp"));

    if root_path.exists() {
        if root_mounted_as_tmp {
            println!("Root is mounted as @_tmp, deleting /mnt/@");
            util::run(command!("btrfs", "subvolume", "delete", root_path.to_string_lossy().as_ref()))?;
        } else {
            println!("Root is not mounted as @_tmp, moving /mnt/@ to /mnt/@_tmp");
            util::run(command!("mv", root_path.to_string_lossy().as_ref(), root_tmp_path.to_string_lossy().as_ref()))?;
        }
    }

    // Now root_path does not exist, we can snapshot the rollback
    util::run(command!("btrfs", "subvolume", "snapshot", snapshot_path.to_string_lossy().as_ref(), root_path.to_string_lossy().as_ref()))?;

    Ok(())
}

pub fn build(cli: &Cli) -> Result<(), String> {
    println!(
        "{}, building...",
        cli.get_build_dir()?.to_string_lossy().as_ref()
    ); 
    
    ctrlc::set_handler(move || {
        println!("Ctrl+C pressed, shutting down...");
        util::run(command!("podman", "kill", "archbuild")).ok();
        util::run(command!("podman", "rm", "archbuild")).ok();
        std::process::exit(130);
    }).expect("Error setting Ctrl+C handler");

    println!("Loading {:?} file", cli.get_build_dir()?.join(".env"));
    dotenv::from_filename(cli.get_build_dir()?.join(".env")).map_err(|_| "Failed to load .env file")?;

    let user = std::env::var("USER").map_err(|_| format!("USER variable not set"))?;
    let pw = std::env::var("PW").map_err(|_| format!("PW variable not set"))?;

    // command!("ls", "-la").stdout(std::process::Stdio::inherit()).status().map_err(|e| format!("Failed to build: {}", e))?.success().then(|| 0).ok_or("Failed to build")?;
    util::run(
        command!("podman", "build", "-t", "archbuild", ".")
            .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
            .stdout(std::process::Stdio::inherit()),
    )?;

    util::run(
        command!(
            "podman",
            "run",
            "--sig-proxy=true",
            "--cap-add",
            "SYS_ADMIN",
            "--security-opt",
            "unmask=/proc/*",
            "--security-opt",
            "label=disable",
            "-v",
            "./cache:/var/cache/pacman/pkg",
            "--env",
            &format!("USER={}", user),
            "--env",
            &format!("PW={}", pw),
            "--name",
            "archbuild",
            "--replace",
            "archbuild"
        )
        .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
        .stdout(std::process::Stdio::inherit()),
    )?;

    util::run(
        command!("podman", "cp", "archbuild:/arch.sqfs", ".")
            .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
            .stdout(std::process::Stdio::inherit()),
    )?;

    util::run(
        command!("podman", "rm", "archbuild")
            .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
            .stdout(std::process::Stdio::inherit()),
    )?;

    Ok(())
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

pub fn rebase(cli: &Cli, id: String, image_path: &Option<PathBuf>) -> Result<(), String> {
    let canonicalized_path = match image_path {
        Some(path) => path
            .canonicalize()
            .map_err(|e| format!("Failed to canonicalize image path: {}", e))?,
        None => {
            todo!("Implement rebase command without image path");
        }
    };

    println!("Rebasing {:?} to new branch {}", canonicalized_path, id);

    util::run(command!(
        "btrfs",
        "subvolume",
        "create",
        &cli.get_subvolume_dir()?.join(&id).to_string_lossy()
    ))?;

    Ok(())
}
