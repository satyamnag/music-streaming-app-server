#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)/sangeet-supabase-audio"
OUTPUT_FILE="$PLUGIN_DIR/../sangeet-supabase-audio.smplug"

echo "=== Building Sangeet Supabase Audio Plugin ==="

# Step 1: Check if hetu CLI is available
if ! command -v hetu &>/dev/null; then
  echo "Installing hetu_script_dev_tools CLI..."
  dart pub global activate hetu_script_dev_tools
  export PATH="$PATH:$HOME/.pub-cache/bin"
fi

# Step 2: Compile Hetu source to bytecode
echo "Compiling source.ht -> plugin.out..."
hetu compile "$PLUGIN_DIR/source.ht" "$PLUGIN_DIR/plugin.out"

# Step 3: Verify the output exists
if [ ! -f "$PLUGIN_DIR/plugin.out" ]; then
  echo "ERROR: Compilation failed - plugin.out not found"
  exit 1
fi

# Step 4: Package into .smplug (zip archive) using Python
echo "Packaging plugin.smplug..."
python3 -c "
import zipfile, os
with zipfile.ZipFile('$OUTPUT_FILE', 'w', zipfile.ZIP_DEFLATED) as z:
    z.write('$PLUGIN_DIR/plugin.json', 'plugin.json')
    z.write('$PLUGIN_DIR/plugin.out', 'plugin.out')
"
echo "=== Done: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}') $OUTPUT_FILE ==="
echo ""
echo "Install via:"
echo "  Settings -> Metadata Plugins -> Install from URL"
echo "  Or copy the file to your device and install from File"
