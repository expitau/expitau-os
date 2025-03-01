use std::process::Command;

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
