use crate::models::{AppFamily, ScannedApp};
use crate::privilege::is_protected_path;
use crate::utils::file_walker::{dir_size, find_dirs_by_name};
use crate::utils::process::find_process_by_name;
use std::path::Path;
use std::process::Command;

/// AI agent name patterns to scan for.
const AGENT_PATTERNS: &[&str] = &["claw", "hermes", "oneclaw", "easyclaw", "openclaw"];

/// Run a command and return stdout as a string.
fn run_cmd(cmd: &str, args: &[&str]) -> String {
    Command::new(cmd)
        .args(args)
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default()
}

/// Scan dpkg packages for AI agent patterns.
fn scan_dpkg() -> Vec<(String, String)> {
    let output = run_cmd("dpkg", &["-l"]);
    let mut results = Vec::new();
    for line in output.lines() {
        let lower = line.to_lowercase();
        for pattern in AGENT_PATTERNS {
            if lower.contains(pattern) {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    results.push((parts[1].to_string(), parts[2].to_string()));
                }
            }
        }
    }
    results
}

/// Scan snap packages for AI agent patterns.
fn scan_snap() -> Vec<(String, String)> {
    let output = run_cmd("snap", &["list"]);
    let mut results = Vec::new();
    for line in output.lines().skip(1) {
        let lower = line.to_lowercase();
        for pattern in AGENT_PATTERNS {
            if lower.contains(pattern) {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    results.push((parts[0].to_string(), parts[1].to_string()));
                }
            }
        }
    }
    results
}

/// Scan common directories for AI agent installations.
fn scan_directories() -> Vec<(String, String)> {
    let search_dirs = [
        "/opt",
        "/usr/local/share",
        "/usr/share",
        "/snap",
    ];
    let mut results = Vec::new();
    for dir in &search_dirs {
        let path = Path::new(dir);
        if !path.exists() {
            continue;
        }
        for pattern in AGENT_PATTERNS {
            for found_path in find_dirs_by_name(path, pattern) {
                if let Some(name) = found_path.file_name().and_then(|n| n.to_str()) {
                    results.push((name.to_string(), found_path.to_string_lossy().to_string()));
                }
            }
        }
    }
    results
}

/// Scan user home directories for AI agent configs/caches.
fn scan_user_dirs() -> Vec<(String, String)> {
    let mut results = Vec::new();
    if let Ok(home) = std::env::var("HOME") {
        let home = Path::new(&home);
        for pattern in AGENT_PATTERNS {
            // Check ~/.config/<pattern>
            let config_dir = home.join(".config");
            for found in find_dirs_by_name(&config_dir, pattern) {
                if let Some(name) = found.file_name().and_then(|n| n.to_str()) {
                    results.push((name.to_string(), found.to_string_lossy().to_string()));
                }
            }
            // Check ~/.<pattern>
            let dot_dir = home.join(format!(".{}", pattern));
            if dot_dir.exists() {
                if let Some(name) = dot_dir.file_name().and_then(|n| n.to_str()) {
                    results.push((name.to_string(), dot_dir.to_string_lossy().to_string()));
                }
            }
            // Check ~/.<pattern>rc or ~/.<pattern> config files
            let dotfile = home.join(format!(".{}rc", pattern));
            if dotfile.exists() {
                if let Some(name) = dotfile.file_name().and_then(|n| n.to_str()) {
                    results.push((name.to_string(), dotfile.to_string_lossy().to_string()));
                }
            }
        }
    }
    results
}

/// Main scan function for Linux.
pub fn scan() -> Vec<ScannedApp> {
    let mut apps: Vec<ScannedApp> = Vec::new();
    let mut id_counter = 0;

    // 1. Scan dpkg packages
    for (name, version) in scan_dpkg() {
        let family = AppFamily::from_name(&name);
        let (is_running, pid) = find_process_by_name(&name);
        let install_path = format!("/usr/lib/{}", name);
        let size = dir_size(Path::new(&install_path));

        apps.push(ScannedApp {
            id: format!("app_{}", id_counter),
            name: name.clone(),
            family,
            version,
            size_bytes: size,
            install_path: install_path.clone(),
            residue_paths: find_residue_paths(&name),
            is_running,
            pid,
            requires_privilege: is_protected_path(&install_path),
            auto_start: check_autostart(&name),
        });
        id_counter += 1;
    }

    // 2. Scan snap packages (deduplicate against dpkg results)
    let dpkg_names: std::collections::HashSet<_> = apps.iter().map(|a| a.name.clone()).collect();
    for (name, version) in scan_snap() {
        if dpkg_names.contains(&name) {
            continue;
        }
        let family = AppFamily::from_name(&name);
        let (is_running, pid) = find_process_by_name(&name);
        let install_path = format!("/snap/{}", name);
        let size = dir_size(Path::new(&install_path));

        apps.push(ScannedApp {
            id: format!("app_{}", id_counter),
            name: name.clone(),
            family,
            version,
            size_bytes: size,
            install_path: install_path.clone(),
            residue_paths: find_residue_paths(&name),
            is_running,
            pid,
            requires_privilege: is_protected_path(&install_path),
            auto_start: check_autostart(&name),
        });
        id_counter += 1;
    }

    // 3. Scan directories (deduplicate)
    let known_names: std::collections::HashSet<_> = apps.iter().map(|a| a.name.clone()).collect();
    for (name, path) in scan_directories() {
        if known_names.contains(&name) {
            continue;
        }
        let family = AppFamily::from_name(&name);
        let (is_running, pid) = find_process_by_name(&name);
        let size = dir_size(Path::new(&path));

        apps.push(ScannedApp {
            id: format!("app_{}", id_counter),
            name: name.clone(),
            family,
            version: "unknown".to_string(),
            size_bytes: size,
            install_path: path.clone(),
            residue_paths: find_residue_paths(&name),
            is_running,
            pid,
            requires_privilege: is_protected_path(&path),
            auto_start: check_autostart(&name),
        });
        id_counter += 1;
    }

    // 4. Scan user directories for residue-only entries
    let all_known: std::collections::HashSet<_> = apps.iter().map(|a| a.name.clone()).collect();
    for (name, path) in scan_user_dirs() {
        if all_known.contains(&name) {
            continue;
        }
        let family = AppFamily::from_name(&name);
        let size = dir_size(Path::new(&path));

        apps.push(ScannedApp {
            id: format!("app_{}", id_counter),
            name: name.clone(),
            family,
            version: "unknown".to_string(),
            size_bytes: size,
            install_path: path.clone(),
            residue_paths: vec![path],
            is_running: false,
            pid: None,
            requires_privilege: false,
            auto_start: false,
        });
        id_counter += 1;
    }

    apps
}

/// Find residue paths (config, cache) for a given app name.
fn find_residue_paths(name: &str) -> Vec<String> {
    let mut paths = Vec::new();
    if let Ok(home) = std::env::var("HOME") {
        let home = Path::new(&home);
        let candidates = [
            format!(".config/{}", name),
            format!(".cache/{}", name),
            format!(".local/share/{}", name),
            format!(".{}", name),
            format!(".{}rc", name),
        ];
        for candidate in &candidates {
            let full_path = home.join(candidate);
            if full_path.exists() {
                paths.push(full_path.to_string_lossy().to_string());
            }
        }
    }
    paths
}

/// Check if an app has autostart entries.
fn check_autostart(name: &str) -> bool {
    if let Ok(home) = std::env::var("HOME") {
        let autostart_file = Path::new(&home)
            .join(".config")
            .join("autostart")
            .join(format!("{}.desktop", name));
        if autostart_file.exists() {
            return true;
        }
    }
    // Also check systemd user services
    if let Ok(home) = std::env::var("HOME") {
        let service_file = Path::new(&home)
            .join(".config")
            .join("systemd")
            .join("user")
            .join(format!("{}.service", name));
        if service_file.exists() {
            return true;
        }
    }
    false
}
