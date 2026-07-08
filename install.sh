#!/bin/bash
PLIST_NAME="com.user.hapticmouse.plist"
PLIST_SRC="/Users/raja/.gemini/antigravity-ide/scratch/haptic-mouse/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "=== HapticMouse Installer ==="

# 1. Unload old plist if it exists
if [ -f "$PLIST_DEST" ]; then
    echo "[*] Unloading old launch agent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null
    rm "$PLIST_DEST"
fi

# 2. Copy the plist
echo "[*] Copying plist to LaunchAgents..."
cp "$PLIST_SRC" "$PLIST_DEST"

# 3. Load the launch agent
echo "[*] Loading launch agent..."
launchctl load "$PLIST_DEST"

echo "[+] Installation complete! HapticMouse is now set to start automatically at login."
echo "[!] IMPORTANT: Ensure your Terminal application (or whichever terminal runs this installer) has Accessibility permissions in System Settings -> Privacy & Security -> Accessibility."
