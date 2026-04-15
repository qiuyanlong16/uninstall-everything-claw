use crate::models::UninstallStatus;
use crate::utils::process::find_process_by_name;

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
