#!/bin/bash

# Script to copy web assets to the iOS app bundle
# This will be executed during the build phase in Xcode

WEB_DIR="$SRCROOT/../../web"
TARGET_DIR="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/web"

echo "Copying web assets to app bundle..."
echo "Source: $WEB_DIR"
echo "Destination: $TARGET_DIR"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Build the web project first
cd "$WEB_DIR" && npm run build

# Check if build directory exists
if [ -d "$WEB_DIR/build" ]; then
  # Copy the built web assets to the app bundle
  cp -R "$WEB_DIR/build/"* "$TARGET_DIR/"
  echo "Web assets copied successfully!"
else
  # Copy the public directory if build doesn't exist
  cp -R "$WEB_DIR/public/"* "$TARGET_DIR/"
  cp -R "$WEB_DIR/src" "$TARGET_DIR/"
  echo "Warning: Web build directory not found, copied source files instead."
fi

exit 0