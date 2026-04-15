#!/usr/bin/env bash
set -euo pipefail

echo "Building Rust library..."
cd native/claw-sweeper-core
cargo build --release --target x86_64-pc-windows-msvc
cp target/x86_64-pc-windows-msvc/release/claw_sweeper_core.dll ../../build/windows/x64/runner/Release/ 2>/dev/null || true
cd ../..

echo "Building Flutter Windows app..."
flutter build windows --release

echo "Windows build complete!"
