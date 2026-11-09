@echo off
REM =========================================================================
REM Virtual EFB - PC Web Browser Launcher & Wi-Fi Sync Server
REM
REM REMARKS:
REM - Starts the local EFB server on Port 80 & 443 and opens the EFB web
REM   version in your browser at http://localhost/
REM - NOTE: Not all functions will work in desktop web browsers (external
REM   flight simulation websites and webviews often block embedding in iframes
REM   due to browser CORS/security restrictions).
REM - The desktop browser version is mainly intended to configure your apps,
REM   upload custom icon images/logos to your app tiles from your PC files,
REM   and view your PDF checklists.
REM - For full in-flight functionality with complete embedded browsing and
REM   zero restrictions, use the dedicated Android tablet app (EFB.apk).
REM =========================================================================

REM Ensures Windows Firewall allows your tablet to connect on Port 80 and 443 (asks for Admin once if not yet added)
netsh advfirewall firewall show rule name="EFB Web Server HTTPS" >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process netsh -Verb RunAs -Wait -ArgumentList 'advfirewall firewall add rule name=\"EFB Web Server HTTPS\" dir=in action=allow protocol=TCP localport=80,443 profile=any'"
)

REM Starts the local EFB server and opens the EFB in your browser at http://localhost/
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$running = try { (Invoke-WebRequest -Uri 'http://localhost/api/info' -UseBasicParsing -TimeoutSec 1).StatusCode -eq 200 } catch { $false }; " ^
  "if (-not $running) { Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0tools\serve.ps1' ; Start-Sleep -Milliseconds 1200 }; " ^
  "Start-Process 'http://localhost/'"
