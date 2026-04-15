# ClawSweeper 设计文档

> **Slogan**: 什么claw都可以卸载和扫描出来
> **日期**: 2026-04-15
> **状态**: 待审批

## 1. 概述

ClawSweeper（中文名：Claw清道夫）是一款跨平台桌面应用，用于扫描和卸载市面上各类 AI 编码代理（claw 系列、hermes 等），并清理其残留配置文件和缓存。

**核心需求：**
- 跨平台：Windows / macOS / Ubuntu Linux
- 多语言：中文 / 英文
- 版本控制和静默升级：通过 GitHub Releases 管理
- 分发：Windows 上架 Microsoft Store；macOS/Linux 通过 GitHub Releases 直接分发
  - 注：Mac App Store 的沙盒限制不允许扫描/卸载第三方应用，因此 macOS 不上架 MAS
- 产品特性：包体积小、运行快、体验好

**技术栈：**
- Flutter (Dart) — 前端 UI
- Rust (FFI) — 底层系统操作（扫描、卸载、进程检测、提权）

## 2. 架构设计

```
┌─────────────────────────────────────────────────────┐
│                 ClawSweeper (Flutter)                 │
│  ┌───────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │  扫描页    │ │  卸载页   │ │  设置页   │ │ 关于页  │ │
│  │ (分类标签)  │ │ (进度/结果) │ │ (语言/升级) │ │ (版本)  │ │
│  └───────────┘ └──────────┘ └──────────┘ └────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │         Dart 业务层 (BLoC 状态管理)            │   │
│  │   ScannerBLoC │ UninstallBLoC │ UpdateBLoC    │   │
│  └──────────────────────────────────────────────┘   │
│                         │                           │
│  ┌──────────────────────────────────────────────┐   │
│  │          Rust FFI 调用层 (dart:ffi)           │   │
│  │   libclaw_sweeper_core.{dll,dylib,so}         │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────┘
                      │ FFI
┌─────────────────────▼───────────────────────────────┐
│          Rust 核心库 (claw-sweeper-core)              │
│                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌──────────────┐  │
│  │  Scanner     │ │ Uninstaller │ │  Updater      │  │
│  │  ├Windows    │ │ ├Windows    │ │  │(GitHub     │  │
│  │  ├macOS      │ │ ├macOS      │ │  │ Releases)  │  │
│  │  └Linux      │ │ └Linux      │  │              │  │
│  └─────────────┘ └─────────────┘ └──────────────┘  │
│                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌──────────────┐  │
│  │  I18n        │ │  Privilege  │ │  FileWalker   │  │
│  │ (zh/en)      │ │ (UAC/pkexec │ │  (residue     │  │
│  │              │ │  |auth)     │ │   scanner)    │  │
│  └─────────────┘ └─────────────┘ └──────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 分发策略

| 平台 | 分发渠道 | 打包格式 | 提权方式 |
|------|----------|----------|----------|
| Windows | Microsoft Store + GitHub Releases | MSIX | UAC 弹窗 |
| macOS | GitHub Releases | DMG / ZIP | 密码输入框 (AuthorizationExecuteWithPrivileges) |
| Linux (Ubuntu) | GitHub Releases | DEB / AppImage | pkexec |

## 3. 扫描范围与分类

### 3.1 扫描目标

1. **主程序本体** — 通过包管理器（winget/brew/cask/dpkg 等）和常见安装路径扫描
2. **配置文件和缓存** — 用户目录下的配置文件夹（如 `~/.claude/`、`~/.config/hermes/`）
3. **运行中的进程和服务** — 检测对应 PID、后台 Daemon、开机自启项

### 3.2 分类维度

采用**分类标签视图**，用户可按标签切换：

| 标签 | 包含内容 |
|------|----------|
| 全部 | 所有检测到的 AI 代理实例 |
| Claw 系列 | oneclaw, easyclaw, openclaw 等所有 *claw 命名的工具 |
| Hermes | hermes 系列 |
| 其他代理 | 其他 AI 编码代理 |

## 4. 权限提示机制

### 4.1 权限三态

| 标识 | 含义 | 触发条件 |
|------|------|----------|
| 可正常卸载 | 用户目录下的文件，普通权限可删除 | `~/*`, `~/.*` 等 |
| 需要管理员权限 | 安装在受保护目录 | `/Applications`, `Program Files`, `/opt` 等 |
| 正在运行 | 进程活跃中，无法直接删除 | 扫描到对应 PID |

### 4.2 UI 提示层级

- **列表项级别**：每个应用卡片旁显示对应权限标识
- **底部状态栏**：汇总已选项，若有需要提权的项显示锁图标 + 数量 + "需要管理员权限"
- **卸载前确认弹窗**：列出哪些应用需要提权，请求用户确认
- **卸载进度反馈**：实时显示 "正在提权 → 正在停止进程 → 正在删除文件 → 正在清理缓存"

### 4.3 提权流程

1. 用户点击"开始卸载"
2. 检查选中应用是否有 `requires_privilege = true` 的项
3. 如有，弹出确认框，列出需要提权的应用
4. 用户确认后，弹出系统级提权框（UAC / 密码输入 / pkexec）
5. 提权成功后执行卸载，失败则回退尝试用户权限可操作的部分

## 5. 数据模型

### 5.1 ScannedApp（Rust 侧）

```rust
pub struct ScannedApp {
    pub id: String,           // 唯一标识
    pub name: String,         // oneclaw, easyclaw, hermes 等
    pub family: AppFamily,    // Claw / Hermes / Other
    pub version: String,
    pub size_bytes: u64,
    pub install_path: String,
    pub residue_paths: Vec<String>,  // 配置文件、缓存等
    pub is_running: bool,
    pub pid: Option<u32>,
    pub requires_privilege: bool,    // 是否在受保护目录
    pub auto_start: bool,            // 是否开机自启
}

pub enum AppFamily {
    Claw,       // oneclaw, easyclaw, openclaw, 所有 *claw
    Hermes,     // hermes 系列
    Other,      // 其他 AI 代理
}

pub enum UninstallStatus {
    Stopping,        // 正在停止进程
    Elevating,       // 正在提权
    Uninstalling,    // 正在卸载
    CleaningResidue, // 正在清理残留
    Done,            // 完成
    Failed(String),  // 失败 + 原因
}
```

### 5.2 UpdateInfo

```rust
pub struct UpdateInfo {
    pub has_update: bool,
    pub latest_version: String,
    pub download_url: String,
    pub release_notes: String,
    pub is_critical: bool,  // 是否必须更新
}
```

## 6. FFI 接口

所有接口使用 C ABI 导出，Dart 通过 `dart:ffi` 调用。数据传输采用 JSON 序列化。

```rust
// 扫描全系统已安装的 AI 代理，返回 JSON 字符串指针
pub extern "C" fn scan_all_apps() -> *mut c_char

// 卸载指定应用列表，通过回调返回实时进度
pub extern "C" fn uninstall_apps(
    app_ids_json: *const c_char,
    progress_cb: extern "C" fn(*const c_char)  // 实时状态回调
) -> *mut c_char

// 检查 GitHub Releases 是否有新版本
pub extern "C" fn check_for_updates(current_version: *const c_char) -> *mut c_char

// 释放 Rust 分配的字符串内存
pub extern "C" fn free_string(ptr: *mut c_char)
```

## 7. Flutter 层设计

### 7.1 BLoC

| BLoC | 输入事件 | 输出状态 |
|------|----------|----------|
| ScannerBLoC | `ScanRequested` | `ScanResult(scannedApps: List<ScannedApp>)` |
| UninstallBLoC | `UninstallRequested(appIds)` | `Stream<UninstallProgress>` / `PrivilegeElevationRequested` |
| UpdateBLoC | `CheckUpdateRequested` | `UpdateInfo(hasUpdate, latestVersion, downloadUrl)` |

### 7.2 多语言

- 使用 `flutter_localizations` + `intl`
- JSON 语言文件：`assets/i18n/zh.json`、`assets/i18n/en.json`
- 默认跟随系统语言，未知回退到英文
- 设置页可手动切换
- Rust 层返回英文标识，Flutter 层翻译展示

### 7.3 静默升级

- GitHub Releases 检测，每 6 小时轮询一次（应用启动时立即检查）
- 非必须更新：设置页/托盘显示小角标，不打断用户
- 必须更新（安全修复）：弹窗提示"立即更新"
- 下载后提示"重启以应用更新"

## 8. 项目结构

```
claw-sweeper/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── l10n/
│   │   ├── app_localizations.dart
│   │   └── l10n.yaml
│   ├── models/
│   │   ├── scanned_app.dart
│   │   └── update_info.dart
│   ├── bloc/
│   │   ├── scanner_bloc.dart
│   │   ├── uninstall_bloc.dart
│   │   └── update_bloc.dart
│   ├── pages/
│   │   ├── scan_page.dart
│   │   ├── uninstall_page.dart
│   │   ├── settings_page.dart
│   │   └── about_page.dart
│   ├── widgets/
│   │   ├── app_card.dart
│   │   ├── privilege_banner.dart
│   │   └── progress_indicator.dart
│   └── core/
│       ├── ffi/
│       │   ├── bindings.dart
│       │   └── types.dart
│       └── update/
│           └── updater.dart
├── native/claw-sweeper-core/
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs
│   │   ├── scanner/
│   │   │   ├── mod.rs
│   │   │   ├── windows.rs
│   │   │   ├── macos.rs
│   │   │   └── linux.rs
│   │   ├── uninstaller/
│   │   │   ├── mod.rs
│   │   │   ├── windows.rs
│   │   │   ├── macos.rs
│   │   │   └── linux.rs
│   │   ├── privilege/
│   │   │   ├── mod.rs
│   │   │   ├── windows.rs
│   │   │   ├── macos.rs
│   │   │   └── linux.rs
│   │   └── utils/
│   │       ├── file_walker.rs
│   │       └── process.rs
│   └── build.rs
├── assets/i18n/
│   ├── zh.json
│   └── en.json
├── windows/
├── macos/
├── linux/
└── scripts/
    ├── build-windows.sh
    ├── build-macos.sh
    ├── build-linux.sh
    └── release.sh
```
