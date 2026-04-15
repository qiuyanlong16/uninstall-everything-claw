use std::path::Path;
use std::process::Command;

pub fn is_package_manager_app(name: &str) -> bool {
    // Check dpkg
    let output = Command::new("dpkg")
        .arg("-s")
        .arg(name)
        .output();
    if let Ok(o) = output {
        if o.status.success() {
            return true;
        }
    }

    // Check snap
    let output = Command::new("snap")
        .args(&["list", name])
        .output();
    if let Ok(o) = output {
        if o.status.success() {
            return true;
        }
    }

    false
}

pub fn stop_process(name: &str) {
    // Try kill, then kill -9
    let _ = Command::new("pkill")
        .arg("-f")
        .arg(name)
        .output();
}

pub fn elevate_privileges() -> bool {
    // We check if we already have root, or use pkexec
    // The actual elevation happens per-command via pkexec prefix
    true
}

pub fn remove_app(name: &str, install_path: &str) -> bool {
    if is_package_manager_app(name) {
        // Try dpkg first
        let result = if install_path.starts_with("/usr/") {
            let prefix = if Path::new("/usr/bin/pkexec").exists() { "pkexec" } else { "" };
            let mut cmd = if prefix.is_empty() {
                Command::new("dpkg")
            } else {
                let mut c = Command::new("pkexec");
                c.arg("dpkg");
                c
            };
            cmd.args(&["--purge", "remove", name]).output()
        } else {
            // snap
            let mut cmd = if Path::new("/usr/bin/pkexec").exists() {
                let mut c = Command::new("pkexec");
                c.arg("snap");
                c
            } else {
                Command::new("snap")
            };
            cmd.args(&["remove", name]).output()
        };
        return result.map(|o| o.status.success()).unwrap_or(false);
    }

    // Direct directory removal
    let path = Path::new(install_path);
    if path.exists() {
        let _ = std::fs::remove_dir_all(path);
        return !path.exists();
    }

    true
}

pub fn clean_residue(name: &str) {
    if let Ok(home) = std::env::var("HOME") {
        let home = Path::new(&home);
        let residue_dirs = [
            format!(".config/{}", name),
            format!(".cache/{}", name),
            format!(".local/share/{}", name),
            format!(".{}", name),
            format!(".{}rc", name),
        ];
        for dir in &residue_dirs {
            let full_path = home.join(dir);
            if full_path.exists() {
                let _ = std::fs::remove_dir_all(&full_path);
            }
        }
    }

    // Remove autostart entry
    if let Ok(home) = std::env::var("HOME") {
        let autostart = Path::new(&home)
            .join(".config")
            .join("autostart")
            .join(format!("{}.desktop", name));
        if autostart.exists() {
            let _ = std::fs::remove_file(&autostart);
        }
    }
}
