use std::path::PathBuf;

use crate::command;
use crate::util;
use crate::Cli;

pub fn status(cli: &Cli) -> Result<(), String> {
    let subvolume_dir = cli.get_subvolume_dir()?;
    let efi_dir = cli.get_efi_dir()?;
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
    
    let current = util::get_current_id(&subvolume_dir)?;

    // For each snapshot
    for snapshot in snapshots.lines() {
        // Check if {snapshot}.conf exists in {efi_dir}/loader/entries
        let entry_path = efi_dir
            .join("loader/entries")
            .join(format!("{}.conf", snapshot));

        println!(
            "{}{}{}{}",
            snapshot,
            if snapshot == default {
                " (DEFAULT)"
            } else {
                ""
            },
            if snapshot == current {
                " (CURRENT)"
            } else {
                ""
            },
            if entry_path.exists() { " (PINNED)" } else { "" }
        );
    }

    println!("Snapshots: {}", snapshots);

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
    // 1. If root is mounted as /mnt/@, move it to /mnt/@_tmp (delete /mnt/@_tmp if exists)
    // 2. Delete /mnt/@ if it exists
    // 3. Copy /mnt/@<snapshot> to /mnt/@

    let subvolume_dir = cli.get_subvolume_dir()?;
    let snapshot_path = subvolume_dir.join(&id);

    let root_path = subvolume_dir.join("@");
    let root_tmp_path = subvolume_dir.join("@_tmp");
    let rollback_path = subvolume_dir.join(format!(
        "@rollback-{}-{}",
        id,
        chrono::Local::now().format("%Y%m%d%H%M%S")
    ));

    util::run(command!(
        "btrfs",
        "subvolume",
        "snapshot",
        root_path.to_string_lossy().as_ref(),
        rollback_path.to_string_lossy().as_ref()
    ))?;

    let findmnt_output = util::run(command!(
        "findmnt",
        "-T",
        root_path.to_string_lossy().as_ref(),
        "-o",
        "target,fstype"
    ))?;
    let lines: Vec<&str> = findmnt_output.split('\n').collect();
    let root_mounted_as_tmp = lines.iter().any(|line| line.contains("/@_tmp"));

    if root_path.exists() {
        if root_mounted_as_tmp {
            println!("Root is mounted as @_tmp, deleting /mnt/@");
            util::run(command!(
                "btrfs",
                "subvolume",
                "delete",
                root_path.to_string_lossy().as_ref()
            ))?;
        } else {
            println!("Root is not mounted as @_tmp, moving /mnt/@ to /mnt/@_tmp");
            util::run(command!(
                "mv",
                root_path.to_string_lossy().as_ref(),
                root_tmp_path.to_string_lossy().as_ref()
            ))?;
        }
    }

    // Now root_path does not exist, we can snapshot the rollback
    util::run(command!(
        "btrfs",
        "subvolume",
        "snapshot",
        snapshot_path.to_string_lossy().as_ref(),
        root_path.to_string_lossy().as_ref()
    ))?;

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
    })
    .expect("Error setting Ctrl+C handler");

    println!("Loading {:?} file", cli.get_build_dir()?.join(".env"));
    dotenv::from_filename(cli.get_build_dir()?.join(".env"))
        .map_err(|_| "Failed to load .env file")
        .ok();

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

pub fn pin(cli: &Cli, id: String) -> Result<(), String> {
    let efi_dir = cli.get_efi_dir()?;
    let subvolume_dir = cli.get_subvolume_dir()?;

    // Check id exists
    let snapshot_path = subvolume_dir.join(&id);
    if !snapshot_path.exists() {
        return Err(format!("Snapshot {} does not exist", id));
    }

    let template = include_str!("./entry.conf")
        .replace("{{title}}", "Arch Linux (default)")
        .replace("{{efi_path}}", "/EFI/Arch/arch-linux.efi")
        .replace("{{root_label}}", "ARCH_ROOT")
        .replace("{{root_options}}", "@");

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

pub fn rebase(cli: &Cli, id: String, image_path: &Option<PathBuf>) -> Result<(), String> {
    let full_image_path = match image_path {
        Some(path) => path
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
