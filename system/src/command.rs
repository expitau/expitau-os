use std::path::{Path, PathBuf};

use crate::command;
use crate::util;
use crate::util::get_subvolume_tree;
use crate::Cli;

pub fn status(cli: &Cli) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    let efi_dir = cli.get_efi_dir()?;

    get_subvolume_tree(Path::new(subvolume_dir.to_string_lossy().as_ref()).to_path_buf())?;
    // // List all snapshots
    // let snapshots = util::run(command!("btrfs", "qgroup", "show", subvolume_dir.to_string_lossy().as_ref()))?;

    // // For each snapshot
    // for snapshot in snapshots.lines() {
    //     // Regex match line
    //     // (?:qgroupid) (referenced) (exclusive) (path)
    //     let matches = regex::Regex::new(r"[\d/]+\s+(\S+)\s+(\S+)\s+(\S+)\s*").unwrap().captures(snapshot);
    //     if let Some(matches) = matches {
    //         let referenced = matches.get(0).unwrap().as_str();
    //         let exclusive = matches.get(1).unwrap().as_str();
    //         let path = matches.get(2).unwrap().as_str();

    //         println!("{}", path);
    //     }

    // }

    let snapshots = util::run(command!(
        "ls",
        "-1",
        subvolume_dir.to_string_lossy().as_ref()
    ))?;
    let default_output = util::run(command!(
        "btrfs",
        "subvolume",
        "get-default",
        subvolume_dir.to_string_lossy().as_ref()
    ))?;
    let default = default_output
        .split_whitespace()
        .last()
        .ok_or("Could not get default subvolume")?
        .trim();

    // For each snapshot
    for snapshot in snapshots.lines() {
        // Check if {snapshot}.conf exists in {efi_dir}/loader/entries
        let entry_path = efi_dir
            .join("loader/entries")
            .join(format!("{}.conf", snapshot));

        println!(
            "{}{}{}",
            if snapshot == default { "⭐" } else { "  " },
            if entry_path.exists() { " 📌" } else { "  " },
            snapshot
        );
    }

    Ok(())
}

pub fn snapshot(cli: &Cli, id: String) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    util::run(command!(
        "btrfs",
        "subvolume",
        "snapshot",
        "-r",
        "/",
        snapshot_path.to_string_lossy().as_ref()
    ))?;

    println!("Snapshot {} created", id);

    Ok(())
}

pub fn delete(cli: &Cli, id: String) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    util::run(command!(
        "btrfs",
        "subvolume",
        "delete",
        snapshot_path.to_string_lossy().as_ref()
    ))?;

    println!("Snapshot {} deleted", id);

    Ok(())
}

pub fn rollback(cli: &Cli, id: String) -> Result<(), String> {
    // Rollback
    // 1. Set default subvolume
    // 2. Copy EFI files

    let subvolume_dir = cli.get_subvolume_dir()?;
    let efi_dir = cli.get_efi_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    util::run(command!(
        "btrfs",
        "subvolume",
        "set-default",
        snapshot_path.to_string_lossy().as_ref()
    ))?;

    let kernel_path = PathBuf::from("usr/lib/kernel/arch-linux.efi");
    let kernel_dest = efi_dir.join("EFI/Arch").join("arch-linux.efi");

    util::run(command!(
        "chattr",
        "-i",
        kernel_dest.to_string_lossy().as_ref()
    )).map_err(|e| {
        format!(
            "Failed to remove immutable flag from kernel: {}\nWARNING: Default subvolume has incorrect kernel",
            e
        )
    })?;

    std::fs::copy(snapshot_path.join(&kernel_path), &kernel_dest).map_err(|e| {
        format!(
            "Failed to copy kernel to boot directory: {}\nWARNING: Kernel image not immutable\nWARNING:Default subvolume has incorrect kernel",
            e
        )
    })?;

    util::run(command!(
        "chattr",
        "+i",
        kernel_dest.to_string_lossy().as_ref()
    ))
    .map_err(|e| {
        format!(
            "Failed to set immutable flag on kernel: {}\nWARNING: Kernel image not immutable",
            e
        )
    })?;

    Ok(())
}

pub fn build(cli: &Cli) -> Result<(), String> {
    println!(
        "{}, building...",
        cli.get_build_dir()?.to_string_lossy().as_ref()
    );

    ctrlc::set_handler(move || {
        println!("Ctrl+C pressed, shutting down...");
        util::run(command!("podman", "kill", "expitauos")).ok();
        util::run(command!("podman", "rm", "expitauos")).ok();
        std::process::exit(130);
    })
    .expect("Error setting Ctrl+C handler");

    println!("Loading {:?} file", cli.get_build_dir()?.join(".env"));
    dotenv::from_filename(cli.get_build_dir()?.join(".env"))
        .map_err(|_| "Failed to load .env file")
        .ok();

    let user = std::env::var("SYSTEM_USER").map_err(|_| format!("USER variable not set"))?;
    let pw = std::env::var("SYSTEM_PW").map_err(|_| format!("PW variable not set"))?;

    // command!("ls", "-la").stdout(std::process::Stdio::inherit()).status().map_err(|e| format!("Failed to build: {}", e))?.success().then(|| 0).ok_or("Failed to build")?;
    util::run(
        command!(
            "podman",
            "build",
            "--cap-add",
            "ALL",
            "--build-context",
            "cache=/var/cache/pacman/pkg",
            "--build-arg",
            format!("SYSTEM_USER={}", user).as_str(),
            "--build-arg",
            format!("SYSTEM_PW={}", pw).as_str(),
            "-t",
            "expitauos",
            "."
        )
        .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
        .stdout(std::process::Stdio::inherit()),
    )?;

    util::run(
        command!(
            "podman",
            "create",
            "--name",
            "expitauos",
            "--replace",
            "expitauos"
        )
        .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
        .stdout(std::process::Stdio::inherit()),
    )?;

    util::run(
        command!("podman", "cp", "expitauos:/arch.sqfs", ".")
            .current_dir(cli.get_build_dir()?.to_string_lossy().as_ref())
            .stdout(std::process::Stdio::inherit()),
    )?;

    util::run(
        command!("podman", "rm", "expitauos")
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

pub fn pin(cli: &Cli, id: String) -> Result<(), String> {
    let efi_dir = cli.get_efi_dir()?;
    let subvolume_dir = cli.get_subvolume_dir()?;

    // Check id exists
    let snapshot_path = subvolume_dir.join(&id);
    if !snapshot_path.exists() {
        return Err(format!("Snapshot {} does not exist", id));
    }

    let template = include_str!("./entry.conf")
        .replace("{{title}}", format!("Arch Linux ({})", &id).as_str())
        .replace("{{efi_path}}", "/EFI/Arch/arch-linux.efi")
        .replace("{{root_label}}", "ARCH_ROOT")
        .replace("{{root_options}}", format!("subvol={}", &id).as_str());

    println!("{}", template);

    let entry_path = efi_dir.join("loader/entries").join(format!("{}.conf", id));
    std::fs::write(&entry_path, template).map_err(|e| {
        format!(
            "Failed to write entry file {}: {}",
            entry_path.to_str().unwrap_or("ERR_GET_ENTRY_PATH"),
            e
        )
    })?;

    // Set the entry file immutable
    util::run(command!(
        "chattr",
        "+i",
        entry_path.to_string_lossy().as_ref()
    ))?;

    Ok(())
}

pub fn unpin(cli: &Cli, id: String) -> Result<(), String> {
    let efi_dir = cli.get_efi_dir()?;

    let entry_path = efi_dir.join("loader/entries").join(format!("{}.conf", id));
    std::fs::remove_file(&entry_path).map_err(|e| {
        format!(
            "Failed to remove entry file {}: {}",
            entry_path.to_str().unwrap_or("ERR_GET_ENTRY_PATH"),
            e
        )
    })?;

    Ok(())
}

pub fn rebase(cli: &Cli, id: String, image_path: &Option<String>) -> Result<(), String> {
    let full_image_path = match image_path {
        Some(path) => std::path::Path::new(path)
            .canonicalize()
            .map_err(|e| format!("Failed to canonicalize image path: {}", e))?,
        None => {
            todo!("Implement rebase command without image path");
        }
    };

    let full_subvolume_path = cli.get_subvolume_dir()?.join(&id);

    println!("Rebasing {:?} to new branch {}", full_image_path, id);

    util::run(command!(
        "btrfs",
        "subvolume",
        "create",
        full_subvolume_path.to_string_lossy().as_ref()
    ))?;

    util::run(command!(
        "unsquashfs",
        "-d",
        full_subvolume_path.to_string_lossy().as_ref(),
        full_image_path.to_string_lossy().as_ref()
    ))?;

    Ok(())
}

pub fn update_kernel(cli: &Cli) -> Result<(), String> {
    let kernel_path = PathBuf::from("/usr/lib/kernel/arch-linux.efi");
    let efi_path = cli.get_efi_dir()?;

    if !kernel_path.exists() {
        return Err(format!(
            "Kernel file {} does not exist",
            kernel_path.to_str().unwrap_or("ERR_GET_KERNEL_PATH")
        ));
    }

    let kernel_dest = efi_path.join("EFI/Arch").join("arch-linux.efi");

    util::run(command!("mkinitcpio", "-p", "linux"))?;

    util::run(command!(
        "chattr",
        "-i",
        kernel_dest.to_string_lossy().as_ref()
    ))?;

    std::fs::copy(kernel_path, &kernel_dest).map_err(|e| {
        format!(
            "Failed to copy kernel to boot directory: {}\nWARNING: Kernel image not immutable",
            e
        )
    })?;

    util::run(command!(
        "chattr",
        "+i",
        kernel_dest.to_string_lossy().as_ref()
    ))
    .map_err(|e| format!("{}\nWARNING: Kernel image not immutable", e))?;

    Ok(())
}
