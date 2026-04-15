pub mod models;
pub mod privilege;
pub mod scanner;
pub mod uninstaller;
pub mod utils;

pub use models::*;

use std::ffi::{CStr, CString, c_char};

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
    let current = version_cstr.to_str().unwrap_or("0.0.0");

    // Update check is done in Dart via HTTP to GitHub API.
    // This FFI function is a placeholder that Dart can override.
    let info = crate::models::UpdateInfo {
        has_update: false,
        latest_version: current.to_string(),
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
