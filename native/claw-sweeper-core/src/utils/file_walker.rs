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
