# Virtual EFB (Electronic Flight Bag)

An Airbus-inspired, open-source Electronic Flight Bag designed for flight simulator enthusiasts (Microsoft Flight Simulator, X-Plane, Prepar3D).

Virtual EFB runs as a **standalone, full-screen Android tablet application** paired with a lightweight **PC companion server** that automatically syncs your aircraft `.pdf` checklists over your local home Wi-Fi.

![Airbus Cockpit EFB](icons/icon-512.png)

---

## Highlights & Features

### ✈️ Cockpit Design & Avionics Aesthetic
* **Airbus Theme**: Sleek, high-contrast dark cockpit aesthetic utilizing **B612**—the official open-source font designed by Airbus for aircraft cockpit displays.
* **Status Bar**: Real-time **UTC (Zulu) clock**, live date, battery monitor, night-dimming slider, and screen wake-lock toggle.
* **SimBrief Integration**: Enter your SimBrief Pilot ID to automatically fetch your active flight plan callsign, origin, and destination directly into the top bar.

### 📱 Dedicated Android Tablet Application
* **Standalone Android APK**: Runs completely full-screen with immersive mode enabled. Includes an AssistiveTouch / iPad-style floating home button that can be freely dragged anywhere on the screen.
* **Native In-App Browsing**: Embedded web views allow external flight tools to load cleanly without browser chrome or toolbars.
* **Zero PC Requirement in Cockpit**: All flight tools, cached checklists, calculators, and scratchpads run directly on the tablet.

### 📋 Interactive Checklists & Local Wi-Fi Sync
* **Built-in PDF Viewer**: Render multi-page aircraft procedures and checklists with night-mode inverted reading and auto-fit scaling.
* **Two-Way Local Wi-Fi Sync**: Drop `.pdf` checklists into the PC's `checklists/` folder and they automatically sync to the tablet over Wi-Fi.
* **Offline Caching**: All opened checklists are cached permanently on the tablet—fly even when your PC is turned off.
* **Direct Import**: Add PDFs directly from your tablet storage via the `+ ADD CHECKLIST` file picker.

### 🧭 Wind Components, METAR & Live D-ATIS
* **Runway Wind Vectors**: Enter an ICAO airport code to load runways, calculate headwind, tailwind, and crosswind components, and highlight the optimal runway.
* **Live VATSIM & Real-World D-ATIS**: Automatically pulls digital ATIS from active VATSIM controllers. When no controller is online, it falls back to real-world Digital ATIS (both Arrival and Departure ATIS) using a native Android bridge that bypasses CORS restrictions.
* **Conversion Tools**: Instant conversions for Fuel (KG, LBS, US Gal, Litres), Weight, Pressure (hPa ↔ inHg), and Distance/Speed.

### ✏️ Pilot Scratchpad
* Touch and stylus drawing pad with aircraft clearance templates (**C-R-A-F-T**: Clearance, Route, Altitude, Frequency, Transponder), runway notes, and quick clear/undo controls.

---

## Quick Start Guide

### Step 1: Set Up the PC Sync Server (For Checklists)
1. Download this project onto your simulator PC:
   * Click the green **Code** button at the top of the repository and select **[Download ZIP](../../archive/refs/heads/main.zip)** (or download the **Source code (zip)** from the [Releases](../../releases) tab).
2. Extract the `.zip` archive anywhere on your PC (e.g., `C:\Virtual-EFB` or in your Documents folder).
3. Drop your aircraft `.pdf` checklist files into the extracted `checklists/` folder (you can also organize them in subfolders like `checklists/A320/normal.pdf`).
4. Double-click **`Start-EFB.bat`**:
   * A clean PC status dashboard will open in your browser displaying your PC's local Wi-Fi IP address (e.g., `192.168.1.50`).

### Step 2: Install the App on your Android Tablet
1. Download **`EFB.apk`** from the [Releases](../../releases) tab (or click the download button directly on your PC's status screen from your tablet at `http://<YOUR-PC-IP>/EFB.apk`).
2. On your tablet, open the downloaded file using Android's **Package Installer**.
3. If prompted by Android, enable **Allow from this source** and tap **Install** (or tap *More details → Install anyway* if prompted by Play Protect).
4. Launch **EFB** from your home screen.

### Step 3: Connect Tablet to PC (One-Time Setup)
1. In the **EFB** app on your tablet, tap ⚙ **Settings** on the top bar.
2. Under **Simulator PC Connection**, enter the IP address shown on your PC screen (e.g., `192.168.1.50`) and tap **CONNECT**.
3. All checklists from your PC's `checklists/` folder will immediately sync to your tablet over your home Wi-Fi!

*(Optional: To run the PC sync server silently in the background on Windows startup, place a shortcut to `tools/start-background-server.vbs` in your Windows Startup folder: press `Win + R`, type `shell:startup`, and paste the shortcut).*

---

## Adding & Customizing Apps

Tap **+ ADD APP** on the top bar of your tablet:
* **Web Address**: Enter any flight simulation URL (e.g., Navigraph Charts, VATSIM Radar, vEZY ICC, FSLabs, Windy, SimBrief, SkyVector).
* **HTML File**: Select any single-file HTML web utility saved on your device.
* **Custom Icons**: Choose from 10 Airbus-inspired highlight colors and custom letter/emoji icons or upload an image.
* **Reorder & Edit**: Long-press any tile (or tap **EDIT**) to move, reconfigure, or delete tiles.

---

## Building the APK from Source

The repository includes an automated build script that compiles `EFB.apk` using the Android Command-Line Tools without requiring Android Studio:

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
├── EFB.apk                 # Pre-built standalone Android app installer
├── Start-EFB.bat           # One-click launcher for the PC sync companion server
├── index.html              # EFB launcher UI (bundled inside the Android app)
├── css/                    # Airbus cockpit theme styling
├── js/                     # EFB app state and local sync engine
├── apps/                   # Bundled offline utilities (Checklists, Wind Calc, Scratchpad)
├── checklists/             # Drop your aircraft PDF checklists here
├── android/                # Native Android application source & build scripts
└── tools/                  # Companion server and background sync utilities
```

---

## License

This project is open-source under the [MIT License](LICENSE).
Airbus font **B612** is licensed under the SIL Open Font License (OFL).
