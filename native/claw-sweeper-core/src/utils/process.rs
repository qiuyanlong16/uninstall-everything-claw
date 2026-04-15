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
