# Virtual EFB (Electronic Flight Bag)

An Airbus-inspired, open-source Electronic Flight Bag designed for flight simulator enthusiasts (Microsoft Flight Simulator, X-Plane, Prepar3D). 

It runs seamlessly on **any Android tablet** as a standalone, full-screen app (no browser toolbars, floating draggable home button, full offline caching) and on **PC** via any modern browser (`http://localhost`).

![Airbus Cockpit EFB](icons/icon-512.png)

---

## Highlights & Features

### ✈️ Cockpit Design & Avionics Aesthetic
* **Airbus Theme**: Sleek, high-contrast dark cockpit aesthetic utilizing **B612**—the official open-source font designed by Airbus for aircraft cockpit displays.
* **Status Bar**: Real-time **UTC (Zulu) clock**, live date, battery monitor, night-dimming slider, and screen wake-lock toggle.
* **SimBrief Integration**: Enter your SimBrief Pilot ID to automatically fetch your active flight plan callsign, origin, and destination directly into the top bar.

### 📱 Android Tablet App & Web App Dual Mode
* **Standalone Android APK**: Runs completely full-screen with immersive mode enabled. Includes an AssistiveTouch / iPad-style floating home button that can be freely dragged anywhere on the screen.
* **Native In-App Browsing**: Embedded web views allow external flight tools to load cleanly without cross-origin iframe restrictions.
* **Zero PC Requirement in Cockpit**: All flight tools, cached checklists, calculators, and scratchpads run directly on the tablet using the tablet's Wi-Fi.

### 📋 Interactive Checklists & PDF Sync
* **Built-in PDF Viewer**: Render multi-page aircraft procedures and checklists with night-mode inverted reading and auto-fit scaling.
* **Two-Way Local Sync**: Drop `.pdf` checklists into the PC's `checklists/` folder and they automatically sync to the tablet over local Wi-Fi.
* **Offline Caching**: All opened and bundled checklists are cached permanently on the tablet—fly even when your PC is turned off.
* **Direct Import**: Add PDFs directly from your tablet storage via the `+ ADD CHECKLIST` file picker.

### 🧭 Wind Components, METAR & Live D-ATIS
* **Runway Wind Vectors**: Enter an ICAO airport code to load runways, calculate headwind, tailwind, and crosswind components, and highlight the optimal runway.
* **Live VATSIM & Real-World D-ATIS**: Automatically pulls digital ATIS from active VATSIM controllers. When no controller is online, it falls back to real-world Digital ATIS (both Arrival and Departure ATIS) using a native Android bridge that bypasses CORS restrictions.
* **Conversion Tools**: Instant conversions for Fuel (KG, LBS, US Gal, Litres), Weight, Pressure (hPa ↔ inHg), and Distance/Speed.

### ✏️ Pilot Scratchpad
* Touch and stylus drawing pad with aircraft clearance templates (**C-R-A-F-T**: Clearance, Route, Altitude, Frequency, Transponder), runway notes, and quick clear/undo controls.

---

## Quick Start: Installing on Android Tablet

1. Download **`EFB.apk`** from the [Releases](../../releases) tab (or from your PC server at `http://<YOUR-PC-IP>/EFB.apk`).
2. On your tablet, open the downloaded file using **Package Installer**.
3. If prompted by Android, enable **Allow from this source** and tap **Install** (or tap *More details → Install anyway* if prompted by Play Protect).
4. Launch **EFB** from your home screen.

---

## Running on PC (Web Version)

1. Open PowerShell and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\serve.ps1
   ```
2. Open your browser and navigate to:
   ```text
   http://localhost/
   ```
3. To enable silent startup on Windows (so the local sync server runs quietly in the background without needing to launch a script manually), a shortcut to `tools/start-background-server.vbs` can be placed in your Windows Startup folder (`shell:startup`).

---

## Adding & Customizing Apps

Tap **+ ADD APP** on the top bar:
* **Web Address**: Enter any flight simulation URL (e.g., Navigraph Charts, VATSIM Radar, vEZY ICC, FSLabs, Windy, SimBrief, SkyVector).
* **HTML File**: Select any single-file HTML web utility saved on your device.
* **Custom Icons**: Choose from 10 Airbus-inspired highlight colors and custom letter/emoji icons or upload an image.
* **Reorder & Edit**: Long-press any tile (or tap **EDIT**) to move, reconfigure, or delete tiles.

---

## Building from Source

The project includes an automated, dependency-free PowerShell build script that compiles `EFB.apk` directly without requiring heavy IDEs like Android Studio:

### Prerequisites
* Windows 10/11
* Java JDK 17+ (`winget install EclipseAdoptium.Temurin.17.JDK`)
* Android Command-Line Tools & SDK Platform 34 (`platforms;android-34`, `build-tools;34.0.0`)

### Build Command
Run from the repository root:
```powershell
powershell -ExecutionPolicy Bypass -File android\build.ps1
```
The compiled, aligned, and signed `EFB.apk` will be output directly to the root directory.

---

## Directory Structure

```text
├── index.html              # EFB Home launcher and status bar
├── manifest.webmanifest    # PWA configuration
├── css/                    # Airbus cockpit theme styling
├── js/                     # EFB app state and two-way sync engine
├── apps/                   # Bundled offline utilities
│   ├── checklist.html      # PDF checklist manager
│   ├── calc.html           # Wind components, METAR & D-ATIS calculator
│   └── scratchpad.html     # Pilot stylus drawing canvas (CRAFT template)
├── checklists/             # Local PDF checklists directory
├── icons/                  # High-resolution EFB vector and bitmap icons
├── android/                # Native Android application source and build tools
│   ├── AndroidManifest.xml # Android app manifest & permissions
│   ├── src/                # Native Java WebView & file-picker bridge
│   └── build.ps1           # 1-click APK build script
└── tools/                  # Background sync server and launchers
```

---

## License

This project is open-source and distributed under the [MIT License](LICENSE).
*All airport data, METARs, and flight simulation services belong to their respective providers. For flight simulation use only.*
