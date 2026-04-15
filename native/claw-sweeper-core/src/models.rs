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
