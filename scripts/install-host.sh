#!/usr/bin/env bash
# Pasang host native Floatix untuk Brave (dan Chrome bila ada).
set -euo pipefail

ID="${1:-}"
if ! [[ "$ID" =~ ^[a-p]{32}$ ]]; then
  echo "Pemakaian: bash scripts/install-host.sh <EXTENSION_ID> [--skip-build]" >&2
  echo "ID = 32 huruf a-p, salin dari brave://extensions." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Library/Application Support/Floatix"
BIN="$APP_DIR/Floatix"
BRAVE="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
CHROME="$HOME/Library/Application Support/Google/Chrome"

[ "${2:-}" = "--skip-build" ] || (cd "$ROOT/native" && swift build -c release)

mkdir -p "$APP_DIR"
cp "$ROOT/native/.build/release/Floatix" "$BIN"
chmod +x "$BIN"
echo "Binary: $BIN"

write_manifest() {
  local dir="$1/NativeMessagingHosts"
  mkdir -p "$dir"
  cat > "$dir/com.dakode.floatix.json" <<JSON
{
  "name": "com.dakode.floatix",
  "description": "Floatix: PiP melayang untuk video",
  "path": "$BIN",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$ID/"]
}
JSON
  python3 -I -m json.tool "$dir/com.dakode.floatix.json" > /dev/null
  echo "Manifest: $dir/com.dakode.floatix.json"
}

write_manifest "$BRAVE"
[ ! -d "$CHROME" ] || write_manifest "$CHROME"
echo "Selesai. Restart Brave."
