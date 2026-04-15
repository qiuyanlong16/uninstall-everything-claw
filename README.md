# ClawSweeper

<p align="center">
  <strong>Scan and uninstall any claw.</strong><br/>
  <em>什么claw都可以卸载和扫描出来</em>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.41.0-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-1.x-dea584?logo=rust&logoColor=white" alt="Rust"></a>
  <a href="#"><img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue" alt="Platforms"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green" alt="License"></a>
</p>

**ClawSweeper** (Claw清道夫) is a cross-platform desktop application that scans for and uninstalls AI coding agents -- including claw-series tools (oneclaw, easyclaw, openclaw, hermes, etc.) -- and cleans up their configuration files, caches, and autostart entries.

Built with **Flutter** for a fast native-feeling UI and **Rust** (via `dart:ffi`) for reliable system-level operations.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Usage](#usage)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Deep System Scanning** -- Detects AI coding agents installed via package managers (apt, snap, Homebrew, winget), common install paths, and user config/cache directories.
- **Process & Autostart Detection** -- Identifies running agent processes and startup entries that may block uninstallation.
- **Clear Privilege Indicators**
  - **Green** -- Removable without elevated privileges
  - **Orange** -- Requires administrator/root access
  - **Red** -- Process currently running (must be stopped first)
- **Batch Uninstall** -- Select multiple agents and remove them with real-time progress tracking.
- **Multi-Language** -- Full English and Chinese (简体中文) localization.
- **Silent Auto-Updates** -- Checks GitHub Releases for new versions and updates in the background.
- **Lightweight** -- Small package size, fast startup, native desktop feel.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Frontend                   │
│  BLoC State Management  │  UI Pages  │  Widgets     │
├─────────────────────────────────────────────────────┤
│              dart:ffi (JSON over C ABI)              │
├─────────────────────────────────────────────────────┤
│              Rust Core Library (FFI)                 │
│  Scanner  │  Uninstaller  │  Privilege  │  Utils    │
└─────────────────────────────────────────────────────┘
```

- **Flutter frontend** uses BLoC for predictable state management across all pages and widgets.
- **Rust core** (`claw-sweeper-core`) handles all system operations: directory walking, process detection, package manager queries, privilege escalation, and file removal.
- Data is exchanged as **JSON over C ABI** via `dart:ffi`, keeping the boundary clean and testable.

### Platform Support

| Platform | Scanner | Uninstaller | Privilege Escalation | Status |
|----------|---------|-------------|----------------------|--------|
| Linux    | Full    | Full (dpkg, snap, dir scan) | `pkexec` | Implemented |
| Windows  | Stub    | Stub        | UAC                  | Ready |
| macOS    | Stub    | Stub        | `osascript`          | Ready |

---

## Screenshots

<p align="center">
  <em>Screenshots coming soon.</em>
</p>

---

## Installation

Download the latest release from [GitHub Releases](https://github.com/your-org/claw-sweeper/releases).

### Linux

```bash
# Download the .deb package
wget https://github.com/your-org/claw-sweeper/releases/latest/download/claw-sweeper-linux.deb

# Install
sudo dpkg -i claw-sweeper-linux.deb
sudo apt-get install -f  # resolve dependencies if needed
```

### macOS

```bash
# Download the .dmg
curl -L -o ClawSweeper.dmg https://github.com/your-org/claw-sweeper/releases/latest/download/claw-sweeper-macos.dmg

# Mount and drag to Applications
open ClawSweeper.dmg
```

### Windows

```powershell
# Download and install the MSIX package
Invoke-WebRequest -Uri "https://github.com/your-org/claw-sweeper/releases/latest/download/claw-sweeper-windows.msix" -OutFile "claw-sweeper.msix"
Add-AppxPackage .\claw-sweeper.msix
```

---

## Usage

1. **Launch** ClawSweeper from your application menu or terminal (`claw-sweeper`).
2. **Scan** -- Click the "Scan" button to detect installed AI coding agents across your system.
3. **Review** -- Examine detected agents with their install method, size, and privilege level.
4. **Select** -- Check the agents you want to remove. Use filters to narrow by type or status.
5. **Uninstall** -- Click "Uninstall Selected" and monitor real-time progress.
6. **Settings** -- Configure language, scan depth, and update preferences in Settings.

> **Tip:** Running processes (shown in red) must be stopped before uninstallation. Close the agent or use your system's task manager first.

---

## Development

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.41.0 or later)
- [Rust](https://rustup.rs/) (stable channel)
- Linux: `build-essential`, `pkg-config`, `libgtk-3-dev`
- macOS: Xcode command-line tools
- Windows: Visual Studio Build Tools with C++ workload

### Setup

```bash
git clone https://github.com/your-org/claw-sweeper.git
cd claw-sweeper
flutter pub get
```

### Build the Rust Core

```bash
cd native/claw-sweeper-core
cargo build --release
```

The compiled library is automatically located by the Flutter app via platform-specific paths:
- Linux: `libclaw_sweeper_core.so`
- macOS: `libclaw_sweeper_core.dylib`
- Windows: `claw_sweeper_core.dll`

### Run the App

```bash
# From the project root
flutter run -d linux     # Linux
flutter run -d macos     # macOS
flutter run -d windows   # Windows
```

### Build for Release

```bash
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

### Project Structure

```
claw-sweeper/
├── lib/                    # Flutter app
│   ├── main.dart           # App entry
│   ├── bloc/               # BLoC state management
│   ├── models/             # Data models
│   ├── pages/              # UI pages
│   ├── widgets/            # Shared widgets
│   └── core/               # FFI bindings, updater
├── native/
│   └── claw-sweeper-core/  # Rust core library
│       └── src/
│           ├── scanner/    # Platform-specific scanning
│           ├── uninstaller/ # Platform-specific uninstallation
│           ├── privilege/  # Privilege escalation
│           └── utils/      # File walking, process detection
├── assets/i18n/            # Localization files
└── scripts/                # Build and release scripts
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

For large changes, please open an issue first to discuss the approach.

---

## License

[MIT](LICENSE) -- feel free to use, modify, and distribute.
