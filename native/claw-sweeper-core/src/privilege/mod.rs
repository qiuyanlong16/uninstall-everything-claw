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
