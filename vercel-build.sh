#!/bin/bash
set -e

echo "=========================================="
echo " Starting ProGold Vercel Build Process    "
echo "=========================================="

# 1. Download Flutter SDK if not present
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter SDK stable..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
fi

export PATH="$PATH:$(pwd)/flutter/bin"

# 2. Check Flutter version
echo "Flutter version:"
flutter --version

# 3. Build Flutter Web Application
echo "Building Flutter Web application..."
cd frontend
flutter pub get
flutter build web --release --no-tree-shake-icons
cd ..

# 4. Prepare root dist/ directory
echo "Copying web build output to dist/..."
mkdir -p dist
cp -r frontend/build/web/* dist/

echo "=========================================="
echo " ProGold Build Completed Successfully!   "
echo "=========================================="
