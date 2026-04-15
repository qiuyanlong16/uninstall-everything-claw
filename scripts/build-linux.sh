#!/usr/bin/env bash
set -euo pipefail

echo "Building Rust library..."
cd native/claw-sweeper-core
cargo build --release --target x86_64-unknown-linux-gnu
cp target/x86_64-unknown-linux-gnu/release/libclaw_sweeper_core.so ../../build/linux/x64/release/bundle/lib/ 2>/dev/null || true
cd ../..

echo "Building Flutter Linux app..."
flutter build linux --release

echo "Linux build complete!"
