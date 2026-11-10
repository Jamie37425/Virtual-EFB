========================================================================
                     VIRTUAL EFB (Electronic Flight Bag)
                               Version 1.8
========================================================================

An open-source Electronic Flight Bag designed for flight simulator enthusiasts
(Microsoft Flight Simulator, Prepar3D, X-Plane).

Virtual EFB runs as a standalone, full-screen Android tablet application
paired with a lightweight PC companion server that automatically syncs your
aircraft PDF checklists over your local home Wi-Fi.

========================================================================
                          QUICK START GUIDE
========================================================================

STEP 1: SET UP THE PC COMPANION SERVER (For Checklists)
------------------------------------------------------------------------
1. Extract this zip archive on your flight simulator PC (e.g. C:\Virtual-EFB
   or in your Documents folder).
2. Drop your aircraft .pdf checklist files into the "checklists" folder
   (you can also organize them in subfolders like checklists\A320\normal.pdf).
3. Double-click "Start-EFB.bat":
   - A console window will open showing your PC's local Wi-Fi IP address.
   - Your desktop web browser will open to http://localhost/


STEP 2: INSTALL ON YOUR ANDROID TABLET (Over Local Wi-Fi)
------------------------------------------------------------------------
1. On your Android tablet, open any web browser (Chrome, Samsung Internet, Firefox).
2. Type your PC's download address directly into your tablet's browser:
      http://<YOUR-PC-IP>/EFB.apk
   (For example, if your PC shows 192.168.1.50, type http://192.168.1.50/EFB.apk)
3. Your tablet will immediately download EFB.apk directly from your PC!
4. Tap the downloaded file to install it.
   (If prompted by Android, tap "Allow from this source" or "Install anyway").
5. Launch "EFB" from your tablet home screen.


STEP 3: CONNECT TABLET TO PC (One-Time Setup)
------------------------------------------------------------------------
1. In the EFB app on your tablet, tap the Settings (gear) icon on the top bar.
2. Under "SIMULATOR PC CONNECTION", enter your PC's IP address (e.g. 192.168.1.50)
   and tap CONNECT.
3. All checklists from your PC will sync immediately over Wi-Fi!


STEP 4: LINK SIMBRIEF & NAVIGRAPH (Optional)
------------------------------------------------------------------------
1. In the EFB Settings (gear) menu, enter your numeric SimBrief Pilot ID
   (or username) and tap FETCH.
2. Your active OFP callsign will immediately appear in the top-left of the
   EFB header.
3. In the "Wind & Conv" app, tap the refresh button (↻) to pull through
   your active flight plan, departure/arrival airports, and Navigraph
   magnetic runway headings with one-tap DEP and ARR setup.

========================================================================
                         FEATURES & CAPABILITIES
========================================================================

- Standalone Android App (EFB.apk):
  Full-screen immersive tablet app with movable floating Home button.

- Interactive PDF Checklist Viewer:
  Multi-page checklists with dark/night mode reading, auto-scaling, and
  offline caching so you can fly even when the PC is off.

- Wind Components, METAR & Live D-ATIS (apps\calc.html):
  Enter an ICAO airport code to calculate headwind, crosswind, and gust
  components with magnetic runway headings. Automatically pulls live VATSIM
  ATIS with real-world D-ATIS fallback.

- Unit & Fuel Conversions:
  Fuel volume to mass (KG, LBS, US Gallons, Litres), Weight, Pressure,
  and Distance/Speed.

- Customizable App Grid:
  Tap "+ ADD APP" to add shortcuts to your favorite flight tools (Navigraph
  Charts, VATSIM Radar, Windy, SimBrief, etc.) with custom icons and colors.

========================================================================
Source code & updates on GitHub:
https://github.com/Jamie37425/Virtual-EFB
========================================================================
