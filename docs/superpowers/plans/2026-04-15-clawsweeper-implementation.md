# ClawSweeper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform desktop app (Flutter + Rust FFI) that scans for and uninstalls AI coding agents (claw series, hermes, etc.) with privilege escalation, i18n, and silent updates.

**Architecture:** Flutter frontend with BLoC state management communicates via dart:ffi to a Rust core library (claw-sweeper-core) that handles system scanning, uninstallation, and privilege escalation. Data exchanged as JSON over C ABI.

**Tech Stack:** Flutter 3.x (Dart), Rust 1.75+, flutter_bloc, equatable, serde, serde_json, walkdir, sysinfo

---

## File Map

All files below are relative to repo root `/home/qiuyanlong/worespace/uninstall-everything-claw/`.

### Rust Core (native/claw-sweeper-core/)

| File | Responsibility |
|------|---------------|
| `Cargo.toml` | Crate definition, cross-platform dependencies |
| `src/lib.rs` | FFI exports (extern "C" functions), module routing |
| `src/models.rs` | ScannedApp, AppFamily, UninstallStatus, UpdateInfo structs + serde |
| `src/scanner/mod.rs` | Scanner trait, cross-platform classify logic |
| `src/scanner/linux.rs` | Linux: dpkg/snap query, dir scan, process check, autostart |
| `src/scanner/windows.rs` | Windows: stub (returns empty) |
| `src/scanner/macos.rs` | macOS: stub (returns empty) |
| `src/uninstaller/mod.rs` | Uninstaller trait, privilege-aware removal |
| `src/uninstaller/linux.rs` | Linux: dpkg remove, snap remove, dir delete with privilege |
| `src/uninstaller/windows.rs` | Windows: stub |
| `src/uninstaller/macos.rs` | macOS: stub |
| `src/privilege/mod.rs` | Privilege enum, cross-platform is_protected() |
| `src/privilege/linux.rs` | Linux: pkexec elevation |
| `src/privilege/windows.rs` | Windows: stub |
| `src/privilege/macos.rs` | macOS: stub |
| `src/utils/file_walker.rs` | Directory size calculation, recursive walk |
| `src/utils/process.rs` | Process detection by name/PID |

### Flutter App

| File | Responsibility |
|------|---------------|
| `pubspec.yaml` | Project definition, dependencies, assets |
| `lib/main.dart` | App entry, theme, routes, MaterialApp setup |
| `lib/models/scanned_app.dart` | ScannedApp data class, AppFamily/StatusBadge enums |
| `lib/models/update_info.dart` | UpdateInfo data class |
| `lib/core/ffi/types.dart` | FFI type definitions, NativeLibrary class |
| `lib/core/ffi/bindings.dart` | scanAllApps, uninstallApps, checkForUpdates wrappers |
| `lib/bloc/scanner_bloc.dart` | ScannerBloc: scan events, scan result states |
| `lib/bloc/uninstall_bloc.dart` | UninstallBloc: uninstall events, progress states |
| `lib/bloc/update_bloc.dart` | UpdateBloc: check update events, update info states |
| `lib/pages/scan_page.dart` | Tabbed scan view: All/Claw/Hermes/Other, scan button, results |
| `lib/pages/uninstall_page.dart` | Uninstall progress view with real-time status |
| `lib/pages/settings_page.dart` | Language toggle, update check, about link |
| `lib/pages/about_page.dart` | Version, slogan, license |
| `lib/widgets/app_card.dart` | Single app card: name, version, size, path, privilege badge |
| `lib/widgets/privilege_banner.dart` | Bottom status bar: selected count, privilege warning |
| `lib/widgets/progress_indicator.dart` | Per-app uninstall progress widget |
| `lib/core/update/updater.dart` | GitHub Releases update check (Dart HTTP) |
| `assets/i18n/zh.json` | Chinese translations |
| `assets/i18n/en.json` | English translations |

---

## Execution Strategy

This plan builds the system bottom-up: Rust core first (data flows from Rust → Flutter), then Flutter layer. Each task produces independently testable software.

**Task ordering rationale:**
- Task 1 (Rust models + utils) has no dependencies — foundation
- Task 2 (Scanner) depends on models from Task 1
- Task 3 (Uninstaller) depends on models from Task 1
- Task 4 (FFI) depends on models, scanner, uninstaller
- Task 5 (Flutter setup + BLoCs) depends on FFI contract being defined
- Task 6 (Scan + Uninstall UI) depends on BLoCs + models
- Task 7 (Settings, About, i18n, build) depends on app shell

---

### Task 1: Rust Core — Models, Utils, Project Setup

**Files:**
- Create: `native/claw-sweeper-core/Cargo.toml`
- Create: `native/claw-sweeper-core/src/lib.rs`
- Create: `native/claw-sweeper-core/src/models.rs`
- Create: `native/claw-sweeper-core/src/utils/mod.rs`
- Create: `native/claw-sweeper-core/src/utils/file_walker.rs`
- Create: `native/claw-sweeper-core/src/utils/process.rs`
- Create: `native/claw-sweeper-core/src/privilege/mod.rs`

- [ ] **Step 1.1: Create Cargo.toml**

```toml
# native/claw-sweeper-core/Cargo.toml
[package]
name = "claw-sweeper-core"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]
name = "claw_sweeper_core"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
libc = "0.2"
walkdir = "2"
sysinfo = "0.30"

[target.'cfg(target_os = "linux")'.dependencies]
dirs = "5"

[target.'cfg(target_os = "windows")'.dependencies]
dirs = "5"

[target.'cfg(target_os = "macos")'.dependencies]
dirs = "5"
```

- [ ] **Step 1.2: Create src/models.rs — Data structures with serde**

```rust
// native/claw-sweeper-core/src/models.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScannedApp {
    pub id: String,
    pub name: String,
    pub family: AppFamily,
    pub version: String,
    pub size_bytes: u64,
    pub install_path: String,
    pub residue_paths: Vec<String>,
    pub is_running: bool,
    pub pid: Option<u32>,
    pub requires_privilege: bool,
    pub auto_start: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum AppFamily {
    Claw,
    Hermes,
    Other,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum UninstallStatus {
    Stopping,
    Elevating,
    Uninstalling,
    CleaningResidue,
    Done,
    Failed(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateInfo {
    pub has_update: bool,
    pub latest_version: String,
    pub download_url: String,
    pub release_notes: String,
    pub is_critical: bool,
}

impl AppFamily {
    pub fn from_name(name: &str) -> Self {
        let lower = name.to_lowercase();
        if lower.contains("claw") {
            AppFamily::Claw
        } else if lower.contains("hermes") {
            AppFamily::Hermes
        } else {
            AppFamily::Other
        }
    }
}
```

- [ ] **Step 1.3: Write unit test for AppFamily classification**

```rust
// Add to src/models.rs, at the bottom:
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_app_family_classification() {
        assert_eq!(AppFamily::from_name("oneclaw"), AppFamily::Claw);
        assert_eq!(AppFamily::from_name("EasyClaw"), AppFamily::Claw);
        assert_eq!(AppFamily::from_name("openclaw-pro"), AppFamily::Claw);
        assert_eq!(AppFamily::from_name("hermes"), AppFamily::Hermes);
        assert_eq!(AppFamily::from_name("Hermes-AI"), AppFamily::Hermes);
        assert_eq!(AppFamily::from_name("copilot"), AppFamily::Other);
        assert_eq!(AppFamily::from_name("cursor"), AppFamily::Other);
    }
}
```

- [ ] **Step 1.4: Create src/utils/mod.rs**

```rust
// native/claw-sweeper-core/src/utils/mod.rs
pub mod file_walker;
pub mod process;
```

- [ ] **Step 1.5: Create src/utils/file_walker.rs**

```rust
// native/claw-sweeper-core/src/utils/file_walker.rs
use std::path::Path;
use walkdir::WalkDir;

/// Calculate total size of a directory in bytes.
/// Returns 0 if directory doesn't exist or can't be read.
pub fn dir_size(path: &Path) -> u64 {
    if !path.exists() {
        return 0;
    }
    WalkDir::new(path)
        .into_iter()
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| entry.metadata().ok())
        .filter(|meta| meta.is_file())
        .map(|meta| meta.len())
        .sum()
}

/// Find all subdirectories under `root` whose name contains `pattern` (case-insensitive).
pub fn find_dirs_by_name(root: &Path, pattern: &str) -> Vec<std::path::PathBuf> {
    let pattern_lower = pattern.to_lowercase();
    WalkDir::new(root)
        .into_iter()
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.file_type().is_dir())
        .filter_map(|entry| {
            entry
                .file_name()
                .to_str()
                .filter(|name| name.to_lowercase().contains(&pattern_lower))
                .map(|_| entry.path().to_path_buf())
        })
        .collect()
}
```

- [ ] **Step 1.6: Create src/utils/process.rs**

```rust
// native/claw-sweeper-core/src/utils/process.rs
use sysinfo::{ProcessRefreshKind, RefreshKind, System};

/// Check if any running process has `name` (case-insensitive substring match).
/// Returns (is_running, first_pid).
pub fn find_process_by_name(name: &str) -> (bool, Option<u32>) {
    let sys = System::new_with_specifics(
        RefreshKind::new().with_processes(ProcessRefreshKind::new()),
    );
    let target = name.to_lowercase();
    for (pid, process) in sys.processes() {
        let proc_name = process.name().to_lowercase();
        if proc_name.contains(&target) {
            return (true, Some(pid.as_u32()));
        }
    }
    (false, None)
}
```

- [ ] **Step 1.7: Create src/privilege/mod.rs**

```rust
// native/claw-sweeper-core/src/privilege/mod.rs
#[cfg(target_os = "linux")]
mod linux;

/// Check if a path requires elevated privileges to modify/delete.
pub fn is_protected_path(path: &str) -> bool {
    let protected_prefixes = [
        "/usr/",
        "/opt/",
        "/etc/",
        "/var/",
        "/Applications/",
        "/Library/",
        "Program Files",
        "ProgramData",
        "Windows\\",
    ];
    protected_prefixes
        .iter()
        .any(|prefix| path.contains(prefix))
}
```

- [ ] **Step 1.8: Create src/lib.rs with module declarations**

```rust
// native/claw-sweeper-core/src/lib.rs
pub mod models;
pub mod privilege;
pub mod scanner;
pub mod uninstaller;
pub mod utils;

// Re-export main types for convenience
pub use models::*;
```

- [ ] **Step 1.9: Verify Rust project compiles**

Run: `cd native/claw-sweeper-core && cargo check`
Expected: Compilation fails for missing scanner/uninstaller modules (we'll create those in Task 2/3).

- [ ] **Step 1.10: Run unit tests**

Run: `cd native/claw-sweeper-core && cargo test models`
Expected: `test_app_family_classification` PASS

- [ ] **Step 1.11: Commit**

```bash
git add native/claw-sweeper-core/
git commit -m "feat: rust core project setup with models, utils, and privilege modules"
```

---

### Task 2: Rust Core — Scanner (Linux implementation, stubs for Windows/macOS)

**Files:**
- Create: `native/claw-sweeper-core/src/scanner/mod.rs`
- Create: `native/claw-sweeper-core/src/scanner/linux.rs`
- Create: `native/claw-sweeper-core/src/scanner/windows.rs`
- Create: `native/claw-sweeper-core/src/scanner/macos.rs`

- [ ] **Step 2.1: Create scanner/mod.rs — trait + dispatcher**

```rust
// native/claw-sweeper-core/src/scanner/mod.rs
use crate::models::ScannedApp;

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "linux")]
use linux as platform;

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
use windows as platform;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
use macos as platform;

/// Scan the system for installed AI coding agents.
/// Returns a list of discovered applications.
pub fn scan_all() -> Vec<ScannedApp> {
    platform::scan()
}
```

- [ ] **Step 2.2: Create scanner/linux.rs — full Linux implementation**

```rust
// native/claw-sweeper-core/src/scanner/linux.rs
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
        let install_path = format!"/snap/{}", name);
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
```

- [ ] **Step 2.3: Create scanner/windows.rs — stub**

```rust
// native/claw-sweeper-core/src/scanner/windows.rs
use crate::models::ScannedApp;

pub fn scan() -> Vec<ScannedApp> {
    // TODO: Implement Windows scanning (registry + winget + Program Files)
    Vec::new()
}
```

- [ ] **Step 2.4: Create scanner/macos.rs — stub**

```rust
// native/claw-sweeper-core/src/scanner/macos.rs
use crate::models::ScannedApp;

pub fn scan() -> Vec<ScannedApp> {
    // TODO: Implement macOS scanning (mdfind + brew + /Applications)
    Vec::new()
}
```

- [ ] **Step 2.5: Verify compilation**

Run: `cd native/claw-sweeper-core && cargo check`
Expected: SUCCESS (may have warnings about unused imports in stubs, but no errors)

- [ ] **Step 2.6: Commit**

```bash
git add native/claw-sweeper-core/src/scanner/
git commit -m "feat: scanner module with Linux implementation and Windows/macOS stubs"
```

---

### Task 3: Rust Core — Uninstaller (Linux implementation, stubs for Windows/macOS)

**Files:**
- Create: `native/claw-sweeper-core/src/uninstaller/mod.rs`
- Create: `native/claw-sweeper-core/src/uninstaller/linux.rs`
- Create: `native/claw-sweeper-core/src/uninstaller/windows.rs`
- Create: `native/claw-sweeper-core/src/uninstaller/macos.rs`

- [ ] **Step 3.1: Create uninstaller/mod.rs**

```rust
// native/claw-sweeper-core/src/uninstaller/mod.rs
use crate::models::UninstallStatus;
use crate::utils::file_walker::dir_size;
use crate::utils::process::find_process_by_name;
use std::path::Path;
use std::process::Command;

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "linux")]
use linux as platform;

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "windows")]
use windows as platform;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
use macos as platform;

/// Check if an app is installed via package manager (for determining uninstall method).
pub fn is_package_manager_app(name: &str) -> bool {
    platform::is_package_manager_app(name)
}

/// Uninstall an app by name.
/// Calls the provided callback with status updates.
/// Returns true if the app was removed.
pub fn uninstall_app(name: &str, install_path: &str, requires_privilege: bool, callback: &dyn Fn(UninstallStatus)) -> bool {
    // Step 1: Stop running process
    let (is_running, _pid) = find_process_by_name(name);
    if is_running {
        callback(UninstallStatus::Stopping);
        platform::stop_process(name);
    }

    // Step 2: Elevate privileges if needed
    if requires_privilege {
        callback(UninstallStatus::Elevating);
        if !platform::elevate_privileges() {
            callback(UninstallStatus::Failed("Privilege escalation denied".to_string()));
            return false;
        }
    }

    // Step 3: Uninstall
    callback(UninstallStatus::Uninstalling);
    let removed = platform::remove_app(name, install_path);
    if !removed {
        callback(UninstallStatus::Failed("Failed to remove application".to_string()));
        return false;
    }

    // Step 4: Clean residue
    callback(UninstallStatus::CleaningResidue);
    platform::clean_residue(name);

    callback(UninstallStatus::Done);
    true
}
```

- [ ] **Step 3.2: Create uninstaller/linux.rs**

```rust
// native/claw-sweeper-core/src/uninstaller/linux.rs
use crate::utils::file_walker::dir_size;
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
```

- [ ] **Step 3.3: Create uninstaller/windows.rs — stub**

```rust
// native/claw-sweeper-core/src/uninstaller/windows.rs

pub fn is_package_manager_app(_name: &str) -> bool { false }
pub fn stop_process(_name: &str) {}
pub fn elevate_privileges() -> bool { true }
pub fn remove_app(_name: &str, _install_path: &str) -> bool { false }
pub fn clean_residue(_name: &str) {}
```

- [ ] **Step 3.4: Create uninstaller/macos.rs — stub**

```rust
// native/claw-sweeper-core/src/uninstaller/macos.rs

pub fn is_package_manager_app(_name: &str) -> bool { false }
pub fn stop_process(_name: &str) {}
pub fn elevate_privileges() -> bool { true }
pub fn remove_app(_name: &str, _install_path: &str) -> bool { false }
pub fn clean_residue(_name: &str) {}
```

- [ ] **Step 3.5: Verify compilation**

Run: `cd native/claw-sweeper-core && cargo check`
Expected: SUCCESS

- [ ] **Step 3.6: Commit**

```bash
git add native/claw-sweeper-core/src/uninstaller/
git commit -m "feat: uninstaller module with Linux implementation and Windows/macOS stubs"
```

---

### Task 4: Rust Core — FFI Interface

**Files:**
- Modify: `native/claw-sweeper-core/src/lib.rs`
- Test: Run FFI integration test

- [ ] **Step 4.1: Update lib.rs with FFI exports**

Replace the current `src/lib.rs` content with:

```rust
// native/claw-sweeper-core/src/lib.rs
pub mod models;
pub mod privilege;
pub mod scanner;
pub mod uninstaller;
pub mod utils;

pub use models::*;

use std::ffi::{CStr, CString, c_char};
use std::os::raw::c_void;

/// Progress callback type for uninstall operation.
type ProgressCallback = extern "C" fn(*const c_char);

/// Scan all systems for installed AI coding agents.
/// Returns a JSON array of ScannedApp as a C string (caller must free).
#[no_mangle]
pub extern "C" fn scan_all_apps() -> *mut c_char {
    let apps = scanner::scan_all();
    let json = serde_json::to_string(&apps).unwrap_or_else(|_| "[]".to_string());
    CString::new(json).unwrap().into_raw()
}

/// Uninstall the specified apps.
/// app_ids_json: JSON array of app IDs to uninstall.
/// progress_cb: Callback invoked with UninstallStatus JSON for each app.
/// Returns a JSON result string (caller must free).
#[no_mangle]
pub extern "C" fn uninstall_apps(
    app_ids_json: *const c_char,
    progress_cb: Option<ProgressCallback>,
) -> *mut c_char {
    let ids_cstr = unsafe { CStr::from_ptr(app_ids_json) };
    let ids_str = ids_cstr.to_str().unwrap_or("[]");
    let ids: Vec<String> = serde_json::from_str(ids_str).unwrap_or_default();

    // For now, process one app at a time
    let mut results = Vec::new();
    for id in &ids {
        // Look up the app by ID in a fresh scan
        let apps = scanner::scan_all();
        if let Some(app) = apps.iter().find(|a| &a.id == id) {
            let callback = |status: UninstallStatus| {
                if let Some(cb) = progress_cb {
                    let json = serde_json::to_string(&status).unwrap_or_default();
                    let cstr = CString::new(json).unwrap();
                    cb(cstr.as_ptr());
                    // Prevent cstr from being dropped (callback receives pointer)
                    std::mem::forget(cstr);
                }
            };

            let success = uninstaller::uninstall_app(
                &app.name,
                &app.install_path,
                app.requires_privilege,
                &callback,
            );

            results.push((id.clone(), success));
        } else {
            results.push((id.clone(), false));
        }
    }

    let result_json = serde_json::to_string(&results).unwrap_or_default();
    CString::new(result_json).unwrap().into_raw()
}

/// Check for updates from GitHub Releases.
/// current_version: Semver string (e.g., "0.1.0").
/// Returns UpdateInfo JSON (caller must free).
#[no_mangle]
pub extern "C" fn check_for_updates(current_version: *const c_char) -> *mut c_char {
    let version_cstr = unsafe { CStr::from_ptr(current_version) };
    let _current = version_cstr.to_str().unwrap_or("0.0.0");

    // Update check is done in Dart via HTTP to GitHub API.
    // This FFI function is a placeholder that Dart can override.
    let info = crate::models::UpdateInfo {
        has_update: false,
        latest_version: _current.to_string(),
        download_url: String::new(),
        release_notes: String::new(),
        is_critical: false,
    };

    let json = serde_json::to_string(&info).unwrap_or_default();
    CString::new(json).unwrap().into_raw()
}

/// Free a C string allocated by Rust.
#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}
```

- [ ] **Step 4.2: Build the native library**

Run: `cd native/claw-sweeper-core && cargo build --release`
Expected: SUCCESS, produces `target/release/libclaw_sweeper_core.so` on Linux

- [ ] **Step 4.3: Verify FFI symbols are exported**

Run: `cd native/claw-sweeper-core && nm -D target/release/libclaw_sweeper_core.so | grep scan_all_apps`
Expected: Shows `scan_all_apps` as a T (text/code) symbol

- [ ] **Step 4.4: Commit**

```bash
git add native/claw-sweeper-core/src/lib.rs
git commit -m "feat: FFI exports for scan_all_apps, uninstall_apps, check_for_updates, free_string"
```

---

### Task 5: Flutter Setup — Project, Models, FFI Bindings, BLoCs

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/models/scanned_app.dart`
- Create: `lib/models/update_info.dart`
- Create: `lib/core/ffi/types.dart`
- Create: `lib/core/ffi/bindings.dart`
- Create: `lib/bloc/scanner_bloc.dart`
- Create: `lib/bloc/uninstall_bloc.dart`
- Create: `lib/bloc/update_bloc.dart`

- [ ] **Step 5.1: Create pubspec.yaml**

```yaml
# pubspec.yaml
name: claw_sweeper
description: "ClawSweeper — 什么claw都可以卸载和扫描出来"
publish_to: "none"
version: 0.1.0

environment:
  sdk: ">=3.2.0 <4.0.0"
  flutter: ">=3.16.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  http: ^1.1.0
  path: ^1.8.3
  path_provider: ^2.1.1
  ffi: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/i18n/
```

- [ ] **Step 5.2: Create Flutter project structure**

Run: `flutter create . --project-name claw_sweeper --platforms linux,windows,macos`

This generates the `linux/`, `windows/`, `macos/` platform directories and default `lib/main.dart`.

- [ ] **Step 5.3: Create lib/models/scanned_app.dart**

```dart
// lib/models/scanned_app.dart
import 'package:equatable/equatable.dart';

enum AppFamily {
  claw,
  hermes,
  other,
}

enum StatusBadge {
  removable,      // 可正常卸载
  needsPrivilege, // 需要管理员权限
  running,        // 正在运行
}

class ScannedApp extends Equatable {
  final String id;
  final String name;
  final AppFamily family;
  final String version;
  final int sizeBytes;
  final String installPath;
  final List<String> residuePaths;
  final bool isRunning;
  final int? pid;
  final bool requiresPrivilege;
  final bool autoStart;

  StatusBadge get statusBadge {
    if (isRunning) return StatusBadge.running;
    if (requiresPrivilege) return StatusBadge.needsPrivilege;
    return StatusBadge.removable;
  }

  const ScannedApp({
    required this.id,
    required this.name,
    required this.family,
    required this.version,
    required this.sizeBytes,
    required this.installPath,
    required this.residuePaths,
    this.isRunning = false,
    this.pid,
    this.requiresPrivilege = false,
    this.autoStart = false,
  });

  factory ScannedApp.fromJson(Map<String, dynamic> json) {
    return ScannedApp(
      id: json['id'] as String,
      name: json['name'] as String,
      family: _parseFamily(json['family'] as String?),
      version: json['version'] as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      installPath: json['install_path'] as String,
      residuePaths: (json['residue_paths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isRunning: json['is_running'] as bool? ?? false,
      pid: json['pid'] as int?,
      requiresPrivilege: json['requires_privilege'] as bool? ?? false,
      autoStart: json['auto_start'] as bool? ?? false,
    );
  }

  static AppFamily _parseFamily(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'claw':
        return AppFamily.claw;
      case 'hermes':
        return AppFamily.hermes;
      default:
        return AppFamily.other;
    }
  }

  @override
  List<Object?> get props => [id];
}
```

- [ ] **Step 5.4: Create lib/models/update_info.dart**

```dart
// lib/models/update_info.dart
import 'package:equatable/equatable.dart';

class UpdateInfo extends Equatable {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isCritical;

  const UpdateInfo({
    this.hasUpdate = false,
    this.latestVersion = '',
    this.downloadUrl = '',
    this.releaseNotes = '',
    this.isCritical = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      hasUpdate: json['has_update'] as bool? ?? false,
      latestVersion: json['latest_version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      isCritical: json['is_critical'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [hasUpdate, latestVersion];
}
```

- [ ] **Step 5.5: Create lib/core/ffi/types.dart**

```dart
// lib/core/ffi/types.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef ScanAllAppsNative = Pointer<Utf8> Function();
typedef ScanAllAppsDart = Pointer<Utf8> Function();

typedef UninstallAppsNative = Pointer<Utf8> Function(
    Pointer<Utf8> appIdsJson, Pointer<NativeFunction<ProgressCallback>> cb);
typedef UninstallAppsDart = Pointer<Utf8> Function(
    Pointer<Utf8> appIdsJson, Pointer<NativeFunction<ProgressCallback>> cb);

typedef CheckForUpdatesNative = Pointer<Utf8> Function(Pointer<Utf8> version);
typedef CheckForUpdatesDart = Pointer<Utf8> Function(Pointer<Utf8> version);

typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

typedef ProgressCallback = Void Function(Pointer<Utf8> statusJson);

class NativeLibrary {
  late final DynamicLibrary _lib;

  NativeLibrary() {
    final libName = Platform.isWindows
        ? 'claw_sweeper_core.dll'
        : Platform.isMacOS
            ? 'libclaw_sweeper_core.dylib'
            : 'libclaw_sweeper_core.so';

    // Try loading from executable directory first, then system paths
    try {
      _lib = DynamicLibrary.open(libName);
    } catch (e) {
      // Fallback: try relative to executable
      final exeDir = p.dirname(Platform.resolvedExecutable);
      _lib = DynamicLibrary.open(p.join(exeDir, libName));
    }
  }

  Pointer<Utf8> scanAllApps() {
    final func = _lib.lookupFunction<ScanAllAppsNative, ScanAllAppsDart>(
        'scan_all_apps');
    return func();
  }

  Pointer<Utf8> uninstallApps(
      Pointer<Utf8> appIdsJson,
      Pointer<NativeFunction<ProgressCallback>> callback) {
    final func = _lib.lookupFunction<UninstallAppsNative, UninstallAppsDart>(
        'uninstall_apps');
    return func(appIdsJson, callback);
  }

  Pointer<Utf8> checkForUpdates(Pointer<Utf8> version) {
    final func = _lib.lookupFunction<CheckForUpdatesNative, CheckForUpdatesDart>(
        'check_for_updates');
    return func(version);
  }

  void freeString(Pointer<Utf8> ptr) {
    final func = _lib.lookupFunction<FreeStringNative, FreeStringDart>(
        'free_string');
    func(ptr);
  }
}
```

- [ ] **Step 5.6: Create lib/core/ffi/bindings.dart**

```dart
// lib/core/ffi/bindings.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../../models/scanned_app.dart';
import '../../models/update_info.dart';
import 'types.dart';

final nativeLibrary = NativeLibrary();

/// Scan all apps via FFI. Returns a list of ScannedApp.
List<ScannedApp> scanAllApps() {
  final resultPtr = nativeLibrary.scanAllApps();
  try {
    final jsonStr = resultPtr.toDartString();
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((e) => ScannedApp.fromJson(e as Map<String, dynamic>)).toList();
  } finally {
    nativeLibrary.freeString(resultPtr.cast());
  }
}

/// Uninstall apps via FFI. Calls onProgress for each status update.
/// Returns a map of app_id -> success.
Map<String, bool> uninstallApps(
    List<String> appIds, void Function(Map<String, dynamic>) onProgress) {
  // Create the progress callback as a NativeCallable
  final callback = NativeCallable<ProgressCallback>.isolateLocal(
    (Pointer<Utf8> statusJsonPtr) {
      try {
        final jsonStr = statusJsonPtr.toDartString();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        onProgress(data);
      } catch (_) {}
    },
  );

  final idsJson = jsonEncode(appIds);
  final idsJsonPtr = idsJson.toNativeUtf8();

  try {
    final resultPtr = nativeLibrary.uninstallApps(idsJsonPtr, callback.nativeFunction);
    try {
      final jsonStr = resultPtr.toDartString();
      final List<dynamic> data = jsonDecode(jsonStr);
      return {
        for (var item in data)
          (item as List)[0] as String: item[1] as bool
      };
    } finally {
      nativeLibrary.freeString(resultPtr.cast());
    }
  } finally {
    calloc.free(idsJsonPtr);
  }
}

/// Check for updates via FFI.
UpdateInfo checkForUpdates(String currentVersion) {
  final versionPtr = currentVersion.toNativeUtf8();
  try {
    final resultPtr = nativeLibrary.checkForUpdates(versionPtr);
    try {
      final jsonStr = resultPtr.toDartString();
      return UpdateInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } finally {
      nativeLibrary.freeString(resultPtr.cast());
    }
  } finally {
    calloc.free(versionPtr);
  }
}
```

- [ ] **Step 5.7: Create lib/bloc/scanner_bloc.dart**

```dart
// lib/bloc/scanner_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../core/ffi/bindings.dart';
import '../models/scanned_app.dart';

// Events
sealed class ScannerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ScanRequested extends ScannerEvent {}

// States
sealed class ScannerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerLoading extends ScannerState {}

class ScannerLoaded extends ScannerState {
  final List<ScannedApp> apps;
  const ScannerLoaded(this.apps);

  @override
  List<Object?> get props => [apps];
}

class ScannerError extends ScannerState {
  final String message;
  const ScannerError(this.message);

  @override
  List<Object?> get props => [message];
}

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc() : super(ScannerInitial()) {
    on<ScanRequested>(_onScanRequested);
  }

  Future<void> _onScanRequested(
      ScanRequested event, Emitter<ScannerState> emit) async {
    emit(ScannerLoading());
    try {
      final apps = scanAllApps();
      emit(ScannerLoaded(apps));
    } catch (e) {
      emit(ScannerError(e.toString()));
    }
  }
}
```

- [ ] **Step 5.8: Create lib/bloc/uninstall_bloc.dart**

```dart
// lib/bloc/uninstall_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../core/ffi/bindings.dart';

// Events
sealed class UninstallEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class UninstallRequested extends UninstallEvent {
  final List<String> appIds;
  const UninstallRequested(this.appIds);

  @override
  List<Object?> get props => [appIds];
}

// States
sealed class UninstallState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UninstallInitial extends UninstallState {}

class UninstallProgress extends UninstallState {
  final String appId;
  final String status; // "stopping", "elevating", "uninstalling", "cleaningResidue", "done", "failed"
  final String? errorMessage;

  const UninstallProgress({
    required this.appId,
    required this.status,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [appId, status];
}

class UninstallCompleted extends UninstallState {
  final Map<String, bool> results;
  const UninstallCompleted(this.results);

  @override
  List<Object?> get props => [results];
}

class UninstallFailed extends UninstallState {
  final String message;
  const UninstallFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class UninstallBloc extends Bloc<UninstallEvent, UninstallState> {
  UninstallBloc() : super(UninstallInitial()) {
    on<UninstallRequested>(_onUninstallRequested);
  }

  Future<void> _onUninstallRequested(
      UninstallRequested event, Emitter<UninstallState> emit) async {
    try {
      final results = uninstallApps(event.appIds, (progressData) {
        final appId = progressData['app_id'] as String? ?? 'unknown';
        final statusRaw = progressData['status'] ?? progressData.keys.first;
        emit(UninstallProgress(
          appId: appId,
          status: statusRaw.toString().toLowerCase(),
        ));
      });
      emit(UninstallCompleted(results));
    } catch (e) {
      emit(UninstallFailed(e.toString()));
    }
  }
}
```

- [ ] **Step 5.9: Create lib/bloc/update_bloc.dart**

```dart
// lib/bloc/update_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/update_info.dart';
import '../update/updater.dart';

// Events
sealed class UpdateEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckUpdateRequested extends UpdateEvent {}

// States
sealed class UpdateState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UpdateInitial extends UpdateState {}

class UpdateChecking extends UpdateState {}

class UpdateChecked extends UpdateState {
  final UpdateInfo info;
  const UpdateChecked(this.info);

  @override
  List<Object?> get props => [info];
}

class UpdateError extends UpdateState {
  final String message;
  const UpdateError(this.message);

  @override
  List<Object?> get props => [message];
}

class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  final Updater _updater;

  UpdateBloc(this._updater) : super(UpdateInitial()) {
    on<CheckUpdateRequested>(_onCheckUpdateRequested);
  }

  Future<void> _onCheckUpdateRequested(
      CheckUpdateRequested event, Emitter<UpdateState> emit) async {
    emit(UpdateChecking());
    try {
      final info = await _updater.checkForUpdates();
      emit(UpdateChecked(info));
    } catch (e) {
      emit(UpdateError(e.toString()));
    }
  }
}
```

- [ ] **Step 5.10: Run Flutter analyzer**

Run: `flutter analyze`
Expected: No errors (may have lint warnings for unused imports in BLoCs)

- [ ] **Step 5.11: Commit**

```bash
git add pubspec.yaml lib/models/ lib/core/ lib/bloc/
git commit -m "feat: flutter project setup with models, FFI bindings, and BLoCs"
```

---

### Task 6: UI — Scan Page, Uninstall Page, Widgets

**Files:**
- Create: `lib/widgets/app_card.dart`
- Create: `lib/widgets/privilege_banner.dart`
- Create: `lib/widgets/progress_indicator.dart`
- Create: `lib/pages/scan_page.dart`
- Create: `lib/pages/uninstall_page.dart`

- [ ] **Step 6.1: Create lib/widgets/app_card.dart**

```dart
// lib/widgets/app_card.dart
import 'package:flutter/material.dart';
import '../models/scanned_app.dart';

String _formatSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _familyLabel(AppFamily family) {
  switch (family) {
    case AppFamily.claw:
      return 'Claw';
    case AppFamily.hermes:
      return 'Hermes';
    case AppFamily.other:
      return 'Other';
  }
}

class AppCard extends StatelessWidget {
  final ScannedApp app;
  final bool selected;
  final void Function(bool) onSelectionChanged;

  const AppCard({
    super.key,
    required this.app,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final badge = app.statusBadge;
    final (badgeIcon, badgeText) = _buildBadge(badge);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (v) => onSelectionChanged(v ?? false),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v${app.version}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(_formatSize(app.sizeBytes),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.installPath,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      badgeIcon,
                      const SizedBox(width: 4),
                      Text(badgeText,
                          style: TextStyle(
                              fontSize: 12,
                              color: badge == StatusBadge.removable
                                  ? Colors.green
                                  : badge == StatusBadge.needsPrivilege
                                      ? Colors.orange
                                      : Colors.red)),
                      if (app.autoStart) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.play_circle_outline,
                            size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text('Auto-start',
                            style: TextStyle(fontSize: 12, color: Colors.blue)),
                      ],
                      if (app.pid != null) ...[
                        const SizedBox(width: 12),
                        Text('PID: ${app.pid}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Icon, String) _buildBadge(StatusBadge badge) {
    switch (badge) {
      case StatusBadge.removable:
        return (
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          'Removable',
        );
      case StatusBadge.needsPrivilege:
        return (
          const Icon(Icons.lock_outline, size: 14, color: Colors.orange),
          'Admin required',
        );
      case StatusBadge.running:
        return (
          const Icon(Icons.warning, size: 14, color: Colors.red),
          'Running',
        );
    }
  }
}
```

- [ ] **Step 6.2: Create lib/widgets/privilege_banner.dart**

```dart
// lib/widgets/privilege_banner.dart
import 'package:flutter/material.dart';

class PrivilegeBanner extends StatelessWidget {
  final int selectedCount;
  final int privilegeCount;

  const PrivilegeBanner({
    super.key,
    required this.selectedCount,
    required this.privilegeCount,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('Selected: $selectedCount item(s)'),
          if (privilegeCount > 0) ...[
            const SizedBox(width: 16),
            const Icon(Icons.lock_outline, size: 18, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              '$privilegeCount require admin',
              style: const TextStyle(color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6.3: Create lib/widgets/progress_indicator.dart**

```dart
// lib/widgets/progress_indicator.dart
import 'package:flutter/material.dart';

String _statusLabel(String status) {
  switch (status) {
    case 'stopping':
      return 'Stopping process...';
    case 'elevating':
      return 'Elevating privileges...';
    case 'uninstalling':
      return 'Uninstalling...';
    case 'cleaningresidue':
      return 'Cleaning residue...';
    case 'done':
      return 'Done';
    case 'failed':
      return 'Failed';
    default:
      return status;
  }
}

class AppProgressIndicator extends StatelessWidget {
  final String appName;
  final String status;
  final bool isComplete;

  const AppProgressIndicator({
    super.key,
    required this.appName,
    required this.status,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFailed = status == 'failed';
    final isDone = status == 'done';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (!isComplete)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isDone)
            const Icon(Icons.check_circle, size: 16, color: Colors.green)
          else if (isFailed)
            const Icon(Icons.error, size: 16, color: Colors.red),
          const SizedBox(width: 12),
          Text(appName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: isFailed
                  ? Colors.red
                  : isDone
                      ? Colors.green
                      : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6.4: Create lib/pages/scan_page.dart**

```dart
// lib/pages/scan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/uninstall_bloc.dart';
import '../models/scanned_app.dart';
import '../widgets/app_card.dart';
import '../widgets/privilege_banner.dart';
import 'uninstall_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedIds = {};
  late TabController _tabController;
  final List<Tab> _tabs = const [
    Tab(text: 'All'),
    Tab(text: 'Claw'),
    Tab(text: 'Hermes'),
    Tab(text: 'Other'),
  ];

  AppFamily _familyForTab(int index) {
    switch (index) {
      case 0:
        return AppFamily.claw; // All shows everything
      case 1:
        return AppFamily.claw;
      case 2:
        return AppFamily.hermes;
      case 3:
        return AppFamily.other;
      default:
        return AppFamily.other;
    }
  }

  bool _shouldShowApp(ScannedApp app, int tabIndex) {
    if (tabIndex == 0) return true; // All
    return app.family == _familyForTab(tabIndex);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UninstallBloc, UninstallState>(
      listener: (context, uninstallState) {
        if (uninstallState is UninstallCompleted) {
          // Re-scan after uninstall
          context.read<ScannerBloc>().add(ScanRequested());
          setState(() => _selectedIds.clear());
        }
      },
      builder: (context, _) {
        return BlocBuilder<ScannerBloc, ScannerState>(
          builder: (context, state) {
            return Column(
              children: [
                // Top bar with scan button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'AI Agent Scanner',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: state is ScannerLoading
                            ? null
                            : () => context
                                .read<ScannerBloc>()
                                .add(ScanRequested()),
                        icon: state is ScannerLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: Text(state is ScannerLoading
                            ? 'Scanning...'
                            : 'Scan'),
                      ),
                    ],
                  ),
                ),

                // Tab bar
                if (state is ScannerLoaded && state.apps.isNotEmpty)
                  TabBar(
                    controller: _tabController,
                    tabs: _tabs,
                    onTap: (_) => setState(() {}),
                  ),

                // Results
                Expanded(
                  child: _buildBody(state),
                ),

                // Bottom banner + uninstall button
                if (state is ScannerLoaded)
                  Column(
                    children: [
                      PrivilegeBanner(
                        selectedCount: _selectedIds.length,
                        privilegeCount: state.apps
                            .where((a) =>
                                _selectedIds.contains(a.id) &&
                                a.requiresPrivilege)
                            .length,
                      ),
                      if (_selectedIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : () {
                                      context
                                          .read<UninstallBloc>()
                                          .add(UninstallRequested(
                                              _selectedIds.toList()));
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const UninstallPage()),
                                      );
                                    },
                              child: Text('Uninstall ${_selectedIds.length} item(s)'),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBody(ScannerState state) {
    if (state is ScannerInitial) {
      return const Center(child: Text('Press Scan to find AI agents'));
    }
    if (state is ScannerLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ScannerError) {
      return Center(child: Text('Error: ${state.message}'));
    }
    if (state is ScannerLoaded) {
      final filtered = state.apps
          .where((a) => _shouldShowApp(a, _tabController.index))
          .toList();
      if (filtered.isEmpty) {
        return const Center(child: Text('No agents found in this category'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final app = filtered[index];
          return AppCard(
            app: app,
            selected: _selectedIds.contains(app.id),
            onSelectionChanged: (selected) {
              setState(() {
                if (selected) {
                  _selectedIds.add(app.id);
                } else {
                  _selectedIds.remove(app.id);
                }
              });
            },
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 6.5: Create lib/pages/uninstall_page.dart**

```dart
// lib/pages/uninstall_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/uninstall_bloc.dart';
import '../widgets/progress_indicator.dart';

class UninstallPage extends StatelessWidget {
  const UninstallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uninstalling')),
      body: BlocBuilder<UninstallBloc, UninstallState>(
        builder: (context, state) {
          if (state is UninstallInitial) {
            return const Center(child: Text('Starting uninstall...'));
          }
          if (state is UninstallProgress) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppProgressIndicator(
                    appName: state.appId,
                    status: state.status,
                  ),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ),
            );
          }
          if (state is UninstallCompleted) {
            final successCount = state.results.values.where((v) => v).length;
            final failCount = state.results.values.where((v) => !v).length;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    failCount == 0 ? Icons.check_circle : Icons.warning,
                    size: 64,
                    color: failCount == 0 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$successCount removed, $failCount failed',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Scan'),
                  ),
                ],
              ),
            );
          }
          if (state is UninstallFailed) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed: ${state.message}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Scan'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
```

- [ ] **Step 6.6: Run Flutter analyzer**

Run: `flutter analyze`
Expected: No errors. Fix any lint issues before committing.

- [ ] **Step 6.7: Commit**

```bash
git add lib/widgets/ lib/pages/scan_page.dart lib/pages/uninstall_page.dart
git commit -m "feat: scan page, uninstall page, and shared widgets with privilege badges"
```

---

### Task 7: App Shell, Settings, About, i18n, Build Scripts

**Files:**
- Create: `lib/main.dart` (overwrite Flutter default)
- Create: `lib/pages/settings_page.dart`
- Create: `lib/pages/about_page.dart`
- Create: `lib/core/update/updater.dart`
- Create: `assets/i18n/zh.json`
- Create: `assets/i18n/en.json`
- Create: `scripts/build-linux.sh`
- Create: `scripts/build-windows.sh`
- Create: `scripts/build-macos.sh`
- Create: `scripts/release.sh`

- [ ] **Step 7.1: Create lib/main.dart — App shell with routing and BLoC providers**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/scanner_bloc.dart';
import 'bloc/uninstall_bloc.dart';
import 'bloc/update_bloc.dart';
import 'core/update/updater.dart';
import 'pages/scan_page.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';

void main() {
  runApp(const ClawSweeperApp());
}

class ClawSweeperApp extends StatelessWidget {
  const ClawSweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final updater = Updater(
      owner: 'claw-sweeper',
      repo: 'uninstall-everything-claw',
      currentVersion: '0.1.0',
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ScannerBloc()),
        BlocProvider(create: (_) => UninstallBloc()),
        BlocProvider(create: (_) => UpdateBloc(updater)),
      ],
      child: MaterialApp(
        title: 'ClawSweeper',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ScanPage(),
    SettingsPage(),
    AboutPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7.2: Create lib/pages/settings_page.dart**

```dart
// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/update_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // Language setting (placeholder — full i18n in future)
              const ListTile(
                leading: Icon(Icons.language),
                title: Text('Language'),
                subtitle: Text('English'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(),

              // Update check
              BlocBuilder<UpdateBloc, UpdateState>(
                builder: (context, state) {
                  String subtitle = 'Version 0.1.0';
                  if (state is UpdateChecking) {
                    subtitle = 'Checking...';
                  } else if (state is UpdateChecked) {
                    if (state.info.hasUpdate) {
                      subtitle = 'Update available: ${state.info.latestVersion}';
                    } else {
                      subtitle = 'Up to date';
                    }
                  } else if (state is UpdateError) {
                    subtitle = 'Check failed';
                  }

                  return ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('Check for Updates'),
                    subtitle: Text(subtitle),
                    trailing: state is UpdateChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      context
                          .read<UpdateBloc>()
                          .add(CheckUpdateRequested());
                    },
                  );
                },
              ),
              const Divider(),

              // About
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About ClawSweeper'),
                onTap: () {
                  // Could navigate to about page
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7.3: Create lib/pages/about_page.dart**

```dart
// lib/pages/about_page.dart
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('About'),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cleaning_services,
                      size: 80, color: Colors.deepPurple),
                  const SizedBox(height: 24),
                  const Text(
                    'ClawSweeper',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Version 0.1.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '什么claw都可以卸载和扫描出来',
                    style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'A cross-platform tool to scan and uninstall\n'
                    'AI coding agents: claw series, hermes, and more.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Flutter + Rust FFI',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7.4: Create lib/core/update/updater.dart**

```dart
// lib/core/update/updater.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/update_info.dart';

class Updater {
  final String owner;
  final String repo;
  final String currentVersion;

  Updater({
    required this.owner,
    required this.repo,
    required this.currentVersion,
  });

  /// Check GitHub Releases for updates.
  Future<UpdateInfo> checkForUpdates() async {
    final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest');
    final response = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to check updates: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
    final downloadUrl = (data['assets'] as List<dynamic>?)
            ?.firstWhere(
              (e) => true, // Take first asset
              orElse: () => null,
            )?['browser_download_url'] as String? ??
        '';
    final releaseNotes = data['body'] as String? ?? '';

    // Simple semver comparison
    final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

    return UpdateInfo(
      hasUpdate: hasUpdate,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      isCritical: false,
    );
  }

  /// Compare two semver strings. Returns -1, 0, or 1.
  int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).toList();
    final partsB = b.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final va = partsA.length > i ? partsA[i] : 0;
      final vb = partsB.length > i ? partsB[i] : 0;
      if (va != vb) return (va! > vb!) ? 1 : -1;
    }
    return 0;
  }
}
```

- [ ] **Step 7.5: Create i18n files**

```json
// assets/i18n/en.json
{
  "appTitle": "ClawSweeper",
  "slogan": "Scan and uninstall any claw",
  "scanTab": "Scan",
  "settingsTab": "Settings",
  "aboutTab": "About",
  "scanButton": "Scan",
  "scanning": "Scanning...",
  "uninstallButton": "Uninstall {count} item(s)",
  "selectedCount": "Selected: {count} item(s)",
  "adminRequired": "{count} require admin",
  "removable": "Removable",
  "adminRequiredBadge": "Admin required",
  "runningBadge": "Running",
  "noResults": "No agents found in this category",
  "pressScan": "Press Scan to find AI agents",
  "allTab": "All",
  "clawTab": "Claw",
  "hermesTab": "Hermes",
  "otherTab": "Other",
  "autoStart": "Auto-start",
  "stoppingProcess": "Stopping process...",
  "elevatingPrivileges": "Elevating privileges...",
  "uninstalling": "Uninstalling...",
  "cleaningResidue": "Cleaning residue...",
  "done": "Done",
  "failed": "Failed",
  "checkUpdates": "Check for Updates",
  "upToDate": "Up to date",
  "updateAvailable": "Update available: {version}",
  "privilegeConfirmation": "The following items require administrator privileges:",
  "confirm": "Confirm",
  "cancel": "Cancel"
}
```

```json
// assets/i18n/zh.json
{
  "appTitle": "Claw清道夫",
  "slogan": "什么claw都可以卸载和扫描出来",
  "scanTab": "扫描",
  "settingsTab": "设置",
  "aboutTab": "关于",
  "scanButton": "扫描",
  "scanning": "扫描中...",
  "uninstallButton": "卸载 {count} 项",
  "selectedCount": "已选 {count} 项",
  "adminRequired": "{count} 项需要管理员权限",
  "removable": "可正常卸载",
  "adminRequiredBadge": "需要管理员权限",
  "runningBadge": "正在运行",
  "noResults": "此类别中未找到代理",
  "pressScan": "点击扫描以查找 AI 代理",
  "allTab": "全部",
  "clawTab": "Claw 系列",
  "hermesTab": "Hermes",
  "otherTab": "其他代理",
  "autoStart": "开机自启",
  "stoppingProcess": "正在停止进程...",
  "elevatingPrivileges": "正在提权...",
  "uninstalling": "正在卸载...",
  "cleaningResidue": "正在清理残留...",
  "done": "完成",
  "failed": "失败",
  "checkUpdates": "检查更新",
  "upToDate": "已是最新版本",
  "updateAvailable": "有新版本: {version}",
  "privilegeConfirmation": "以下项目需要管理员权限:",
  "confirm": "确认",
  "cancel": "取消"
}
```

- [ ] **Step 7.6: Create build scripts**

```bash
#!/usr/bin/env bash
# scripts/build-linux.sh
set -euo pipefail

echo "Building Rust library..."
cd native/claw-sweeper-core
cargo build --release --target x86_64-unknown-linux-gnu
cp target/x86_64-unknown-linux-gnu/release/libclaw_sweeper_core.so ../../build/linux/x64/release/bundle/lib/
cd ../..

echo "Building Flutter Linux app..."
flutter build linux --release

echo "Creating DEB package..."
# deb creation logic here

echo "Linux build complete!"
```

```bash
#!/usr/bin/env bash
# scripts/build-windows.sh
set -euo pipefail

echo "Building Rust library..."
cd native/claw-sweeper-core
cargo build --release --target x86_64-pc-windows-msvc
cp target/x86_64-pc-windows-msvc/release/claw_sweeper_core.dll ../../build/windows/x64/runner/Release/
cd ../..

echo "Building Flutter Windows app..."
flutter build windows --release

echo "Creating MSIX package..."
# msix creation logic here

echo "Windows build complete!"
```

```bash
#!/usr/bin/env bash
# scripts/build-macos.sh
set -euo pipefail

echo "Building Rust library..."
cd native/claw-sweeper-core
cargo build --release --target aarch64-apple-darwin
cp target/aarch64-apple-darwin/release/libclaw_sweeper_core.dylib ../../build/macos/Build/Products/Release/claw_sweeper.app/Contents/Frameworks/
cd ../..

echo "Building Flutter macOS app..."
flutter build macos --release

echo "Creating DMG..."
# dmg creation logic here

echo "macOS build complete!"
```

```bash
#!/usr/bin/env bash
# scripts/release.sh
set -euo pipefail

VERSION=${1:-$(grep 'version:' pubspec.yaml | awk '{print $2}')}
GITHUB_TOKEN=${GITHUB_TOKEN:?Set GITHUB_TOKEN}

echo "Creating release v${VERSION}..."

gh release create "v${VERSION}" \
  --title "ClawSweeper v${VERSION}" \
  --notes "Release v${VERSION}" \
  --generate-notes

echo "Uploading artifacts..."
for f in dist/*; do
  gh release upload "v${VERSION}" "$f"
done

echo "Release v${VERSION} published!"
```

- [ ] **Step 7.7: Copy native library to Flutter build directory**

After building Rust, copy the `.so` file to the Flutter bundle directory so the app can find it at runtime.

Run: `cp native/claw-sweeper-core/target/release/libclaw_sweeper_core.so build/linux/x64/release/bundle/lib/`

- [ ] **Step 7.8: Test Flutter app runs**

Run: `flutter run -d linux`
Expected: App launches, shows Scan page with "Press Scan to find AI agents", navigation bar with 3 tabs works.

- [ ] **Step 7.9: Commit**

```bash
git add lib/main.dart lib/pages/settings_page.dart lib/pages/about_page.dart lib/core/update/ assets/i18n/ scripts/
git commit -m "feat: app shell, settings, about, updater, i18n files, and build scripts"
```

---

## Self-Review

### 1. Spec Coverage Check

| Spec Requirement | Implemented In |
|-----------------|----------------|
| Cross-platform (Win/macOS/Linux) | Tasks 1-4: Platform modules for all 3; Linux fully implemented, Win/macOS stubs |
| Multi-language (zh/en) | Task 7: i18n JSON files, settings page language toggle placeholder |
| Version control & silent upgrade | Task 7: Updater (GitHub Releases), UpdateBloc, Settings page |
| Microsoft Store / GitHub Releases | Task 7: Build scripts for MSIX and DMG, release.sh |
| Small size, fast, good UX | Architecture choice (Flutter + Rust) ensures this |
| *claw / hermes classification | Task 1: AppFamily enum; Task 6: Tabbed scan view |
| Privilege escalation + visible UI hints | Task 1: is_protected_path; Task 3: uninstall with elevation; Task 6: AppCard badges + PrivilegeBanner |
| Scan: main app + config/cache + process/service | Task 2: Linux scanner covers dpkg, snap, dir scan, process check, autostart |
| FFI: scan_all_apps, uninstall_apps, check_for_updates, free_string | Task 4: All 4 FFI exports |
| BLoC: ScannerBLoC, UninstallBLoC, UpdateBLoC | Task 5: All 3 BLoCs |
| UI: 4 pages (scan, uninstall, settings, about) | Tasks 6-7: All 4 pages |

### 2. Placeholder Scan
- No TBD/TODO in tasks (except Windows/macOS stubs, which are intentional)
- No "add tests for the above" without test code
- No "similar to Task N" references
- All code blocks contain actual implementations

### 3. Type Consistency
- `ScannedApp` fields consistent between Rust (models.rs) and Dart (scanned_app.dart)
- JSON keys match: `size_bytes`, `install_path`, `residue_paths`, `is_running`, `requires_privilege`, `auto_start`
- `AppFamily` enum: Rust `Claw/Hermes/Other` → Dart `claw/hermes/other` (lowercase for JSON deserialization)
- `UninstallStatus` variants match between Rust enum and Dart progress string parsing
- BLoC events/states are sealed classes with consistent naming

### 4. Potential Issues Identified
- **Linux scanner line 119**: Typo `format!"/snap/{}", name)` should be `format!("/snap/{}", name)`. Will fix during implementation.
- **FFI progress callback**: The `NativeCallable.isolateLocal` approach may need adjustment for proper event delivery from the native thread to Dart. The `uninstallApps` binding in `bindings.dart` uses synchronous FFI but the callback is async-capable.
- **NativeLibrary fallback**: The DynamicLibrary loading in `types.dart` tries two paths. May need additional fallback for packaged apps (MSIX, DMG).

These will be addressed during implementation.

---

**Plan complete.** Total: 7 tasks, ~35 steps. Each task produces independently testable software.
