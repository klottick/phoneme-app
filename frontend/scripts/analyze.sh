#!/bin/bash
# Flutter/Linguist Analysis Script
# Run this before committing to catch issues early

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔍 Running Flutter analysis..."

# Run flutter analyze
flutter analyze

# Run tests (optional - skip if you want faster checks)
echo "🧪 Running unit tests..."
flutter test test/unit/ --reporter compact || true

echo "✅ Analysis complete!"