#!/usr/bin/env bash
set -euo pipefail

echo "Building Rust library..."
cd native/claw-sweeper-core
cargo build --release --target aarch64-apple-darwin
cp target/aarch64-apple-darwin/release/libclaw_sweeper_core.dylib ../../build/macos/Build/Products/Release/claw_sweeper.app/Contents/Frameworks/ 2>/dev/null || true
cd ../..

echo "Building Flutter macOS app..."
flutter build macos --release

echo "macOS build complete!"
