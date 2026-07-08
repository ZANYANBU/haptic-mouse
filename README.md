# HapticMouse 📳

A lightweight, native macOS background utility that acts as a physical keypress and mouse scroll feedback engine. It intercepts keypresses, mouse scroll wheel ticks, and mouse clicks globally, and actuates your MacBook's or Magic Trackpad's Taptic Engine to provide pleasant, physical tactile responses.

Ideal for users who prefer mechanical haptic feedback when typing on the internal keyboard, scrolling with external mice, or using tap-to-click.

---

## ✨ Features

- **Menu Bar Controls:** A lightweight macOS Status Bar interface (`📳`) in your menu bar to toggle haptic feedback ON/OFF or Quit.
- **Adjustable Vibration Strength:** Select between three real-time strength profiles directly from the menu bar:
  - **Low (Battery Saver):** Soft micro-pulse ticks using minimal motor movement.
  - **Medium (Balanced):** Default crisp, comfortable mechanical feedback clicks.
  - **High (Powerful):** Solid, noticeable force clicks.
- **Battery-Saving Throttlers:** Native rate-limiting prevents actuator overloading:
  - Keyboard keypresses debounced to **120ms** (max 8 clicks/sec).
  - Scroll wheel ticks debounced to **100ms** (max 10 clicks/sec).
- **🔒 100% Privacy Protection:**
  - Zero keylogging or event logging.
  - Processes keycodes and events purely in-memory and discards them instantly.
  - Zero files are written or cached on disk.
- **Stand-Alone Agent:** Runs silently in the background without needing a Terminal window or displaying a Dock icon.

---

## 🚀 Installation & Running

### Step 1: Clone and Build
If you are compiling from source:
```bash
# Compile the Swift code
swiftc -O HapticMouse.swift -o haptic-mouse

# Package it into HapticMouse.app
mkdir -p HapticMouse.app/Contents/MacOS
cp haptic-mouse HapticMouse.app/Contents/MacOS/HapticMouse
```

### Step 2: Install to Applications
Copy the app bundle to your system Applications folder so it can be managed cleanly:
```bash
cp -R HapticMouse.app /Applications/
codesign --force --deep --sign - /Applications/HapticMouse.app
```

### Step 3: Authorize Accessibility (Required)
macOS requires explicit authorization to capture global clicks and keystrokes:
1. Open **System Settings > Privacy & Security > Accessibility**.
2. Click the **`+` (Plus)** button.
3. Select **`HapticMouse.app`** from your `/Applications` directory.
4. Toggle the switch to **ON**.
   *(Note: Whenever you recompile the app, macOS requires you to toggle this switch OFF and ON again to refresh the binary signature cache).*

### Step 4: Run at Login (Optional)
To make HapticMouse start automatically whenever you turn on your Mac:
1. Open **System Settings > General > Login Items**.
2. Click the **`+` (Plus)** button under the "Open at Login" list.
3. Select **`HapticMouse.app`** from `/Applications`.

---

## 🛠️ Developers

### Generating Custom Icon (.icns)
A Python script (`generate_icon.py`) is provided that programmatically draws a high-resolution 1024x1024 metallic/neon mouse logo and compiles it to macOS `.icns` format using native `iconutil`:
```bash
python3 generate_icon.py
```

### Hardware Verification
To verify your Mac's trackpad haptic motor is functional directly without Accessibility event taps:
```bash
swiftc -O TestHaptic.swift -o test-haptic
./test-haptic
```

---

## 📄 License
This project is open-source and free to use.
