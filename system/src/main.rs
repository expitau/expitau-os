use std::process::Command;

fn main() {
    println!("Hello, world!");
    let ls = Command::new("ls")
        .arg("-l")
        .output()
        .expect("ls command failed to start");
    println!("\n{}", String::from_utf8(ls.stdout).expect("ls output is not valid UTF-8"));
}
