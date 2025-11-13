#!/bin/bash
# Copy generated LDExported.json to Godot project directory

# Find the most recent build output
GENERATED_JSON=$(find .build/plugins/outputs -name "LDExported.json" -type f | head -1)

if [ -z "$GENERATED_JSON" ]; then
  echo "Error: LDExported.json not found. Run 'swift build' first."
  exit 1
fi

TARGET_DIR="GodotProject"
TARGET_FILE="$TARGET_DIR/LDExported.json"

cp "$GENERATED_JSON" "$TARGET_FILE"
