#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building Sift..."
swift build -c release 2>&1

echo "Assembling Sift.app..."
mkdir -p Sift.app/Contents/MacOS
cp .build/release/Sift Sift.app/Contents/MacOS/Sift
cp Sources/Sift/Info.plist Sift.app/Contents/Info.plist

echo "Done! Run with:"
echo "  open Sift.app --args ~/Pictures/vacation"
echo "  # or double-click Sift.app in Finder"
