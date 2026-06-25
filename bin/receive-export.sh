#!/bin/bash
set -e

# ============================================================
# receive-export.sh — Unpack, import, and clean up
# Called by little-spider housekeeping after SCP
# ============================================================

IMPORT_DIR="/opt/paianjen/data"
IMPORT_FILE="${IMPORT_DIR}/paianjen_export_full.jsonl.gz"
JSON_FILE="${IMPORT_DIR}/paianjen_export_full.jsonl"

cd /opt/paianjen

set -a
source .env
set +a

# Source asdf/elixir version manager if present
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
fi

# 1. Unpack the gz file
echo "📦 Unpacking ${IMPORT_FILE}..."
gunzip -f "$IMPORT_FILE" || true

# 2. Run the import (use a different port to avoid conflict with running service)
echo "📥 Importing data..."
PORT=4001 MIX_ENV=prod mix run priv/repo/import_from_export.exs "$JSON_FILE"

# 3. Clean up both files
echo "🧹 Cleaning up..."
rm -f "$IMPORT_FILE" "$JSON_FILE"

echo "✅ Import complete."
