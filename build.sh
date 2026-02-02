#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building Sift..."
swift build -c release 2>&1

echo "Assembling Sift.app..."
mkdir -p Sift.app/Contents/MacOS
cp .build/release/Sift Sift.app/Contents/MacOS/Sift

echo "Done! Run with:"
echo "  open Sift.app --args ~/work/sift/thailand_2026"
echo "  # or double-click Sift.app in Finder"
