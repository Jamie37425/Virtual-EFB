========================================================================
                     VIRTUAL EFB (Electronic Flight Bag)
                               Version 2.0
========================================================================

An open-source Electronic Flight Bag designed for flight simulator enthusiasts
(Microsoft Flight Simulator, Prepar3D, X-Plane).

Virtual EFB runs as a standalone, full-screen Android tablet application
paired with a lightweight PC companion server that automatically syncs your
aircraft PDF checklists over your local home Wi-Fi.

========================================================================
                          QUICK START GUIDE
========================================================================

STEP 1: SET UP THE PC COMPANION SERVER (For Checklists & Desktop EFB)
------------------------------------------------------------------------
1. Extract this zip archive on your flight simulator PC (e.g. C:\Virtual-EFB
   or in your Documents folder).
2. Drop your aircraft .pdf checklist files into the "checklists" folder
   (you can also organize them in subfolders like checklists\A320\normal.pdf).
3. Double-click "Virtual-EFB.exe" (or "Start-EFB.bat"):
   - A clean console window will open showing your PC's local Wi-Fi IP address.
   - Your desktop web browser will open automatically to http://localhost:8088/
   - Note: The server is only required during initial setup, when syncing new
     checklists from your PC, or when managing apps from localhost. Once cached,
     you do NOT need to keep the server running while flying.


STEP 2: INSTALL ON YOUR ANDROID TABLET (Over Local Wi-Fi)
------------------------------------------------------------------------
1. On your Android tablet, open any web browser (Chrome, Samsung Internet, Firefox).
2. Type your PC's download address directly into your tablet's browser:
      http://<YOUR-PC-IP>:8088/EFB.apk
   (For example, if your PC shows 192.168.1.50, type http://192.168.1.50:8088/EFB.apk)
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
         WINDOWS 11 SMARTSCREEN / SMART APP CONTROL NOTICE
========================================================================
Because this is an independent free community tool, Windows SmartScreen may
show "Windows protected your PC - unrecognized app" on first launch.
To run smoothly:
1. When downloading the zip, right-click the .zip file -> select "Properties"
   -> check "Unblock" at the bottom -> click OK before extracting.
2. Or when opening Virtual-EFB.exe, click "More info" -> "Run anyway".
3. Always start the EFB using Virtual-EFB.exe (or Start-EFB.bat).
   Do not open index.html directly with double-click, as web browsers
   block local server sync, APIs, and cookies on raw file:// URLs.

========================================================================
     WHEN IS THE PC COMPANION SERVER (Virtual-EFB.exe / .bat) NEEDED?
========================================================================

The PC companion server does NOT need to run continuously while flying:
- First Setup: Needed once to download EFB.apk to your tablet over Wi-Fi
  and establish the initial connection.
- Checklist Sync: Needed only when you drop new .pdf checklists into the
  PC's "checklists" folder and want to sync them to your tablet. Once
  opened, checklists are cached permanently on the tablet.
- Adding Apps via Localhost: Useful if you prefer adding apps or URLs via
  your PC keyboard at http://localhost:8088/ to sync them to your tablet.
- While Flying: You can close Virtual-EFB.exe. The Android tablet runs
  completely standalone in the cockpit.

========================================================================
       WEB BROWSER LIMITATIONS (DESKTOP BROWSER vs. ANDROID APP)
========================================================================

While you can open the EFB on your PC browser (http://localhost:8088/),
please note that NOT ALL FEATURES will work in a standard web browser:
1. Blocked Embeds: Many flight simulation tools (such as Navigraph
   Charts, VATSIM radar, and live web tools) block embedding inside
   desktop browser iframes (X-Frame-Options / CSP). The dedicated Android
   tablet app bypasses these frame restrictions to load tools natively.
2. CORS Restrictions: Real-world Digital ATIS (D-ATIS) and certain flight
   APIs are blocked by standard web browser cross-origin (CORS) rules.
   The Android app includes a native bridge that bypasses CORS.
3. For full functionality, using the dedicated Android app (EFB.apk)
   is strongly recommended.

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
