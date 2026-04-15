pub fn is_package_manager_app(_name: &str) -> bool { false }
pub fn stop_process(_name: &str) {}
pub fn elevate_privileges() -> bool { true }
pub fn remove_app(_name: &str, _install_path: &str) -> bool { false }
pub fn clean_residue(_name: &str) {}
