#!/bin/bash
set -eu

PLIST_NAME="com.user.hapticmouse.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_SRC="$SCRIPT_DIR/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
APP_BINARY_SUBPATH="HapticMouse.app/Contents/MacOS/HapticMouse"

DRY_RUN=0
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

echo "=== HapticMouse Installer ==="

if [ ! -f "$PLIST_SRC" ]; then
    echo "[-] $PLIST_NAME not found next to install.sh (looked in $SCRIPT_DIR)." >&2
    exit 1
fi

# 1. Find the installed app
APP_BINARY=""
for APP_DIR in "/Applications" "$HOME/Applications"; do
    if [ -x "$APP_DIR/$APP_BINARY_SUBPATH" ]; then
        APP_BINARY="$APP_DIR/$APP_BINARY_SUBPATH"
        break
    fi
done
if [ -z "$APP_BINARY" ]; then
    echo "[-] HapticMouse.app not found in /Applications or $HOME/Applications." >&2
    echo "    Move HapticMouse.app into /Applications (see the README) and run this installer again." >&2
    exit 1
fi
echo "[*] Found HapticMouse at $APP_BINARY"

# 2. Generate the plist pointing at that binary
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hapticmouse-install.XXXXXX")"
PLIST_TMP="$WORK_DIR/$PLIST_NAME"
cp "$PLIST_SRC" "$PLIST_TMP"
# plutil inserts at an array index instead of overwriting it, so empty the array first
plutil -replace ProgramArguments -json '[]' "$PLIST_TMP"
plutil -insert ProgramArguments.0 -string "$APP_BINARY" "$PLIST_TMP"
plutil -lint "$PLIST_TMP" >/dev/null

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[*] Dry run: nothing was installed. Generated plist: $PLIST_TMP"
    cat "$PLIST_TMP"
    echo "[*] A real run would:"
    if [ -f "$PLIST_DEST" ]; then
        echo "    launchctl unload $PLIST_DEST"
    fi
    echo "    copy the plist to $PLIST_DEST"
    echo "    launchctl load $PLIST_DEST"
    exit 0
fi
trap 'rm -rf "$WORK_DIR"' EXIT

# 3. Unload old plist if it exists
if [ -f "$PLIST_DEST" ]; then
    echo "[*] Unloading old launch agent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# 4. Copy the plist
echo "[*] Copying plist to LaunchAgents..."
mkdir -p "$(dirname "$PLIST_DEST")"
cp "$PLIST_TMP" "$PLIST_DEST"

# 5. Load the launch agent
echo "[*] Loading launch agent..."
launchctl load "$PLIST_DEST"

echo "[+] Installation complete! HapticMouse is now set to start automatically at login."
echo "[!] IMPORTANT: Ensure HapticMouse has Accessibility permissions in System Settings -> Privacy & Security -> Accessibility."
