@echo off
title Virtual EFB Companion & Wi-Fi Sync Server
REM =========================================================================
REM Virtual EFB - PC Web Browser Launcher & Wi-Fi Sync Server
REM
REM REMARKS:
REM - Starts the local EFB server on Port 80 & 443 and opens the EFB web
REM   version in your browser at http://localhost/
REM - Displays your local PC IP address so you can connect your tablet.
REM - NOTE: The desktop browser version is mainly intended to configure
REM   your apps, upload custom icons/logos from PC files, and view checklists.
REM - For full in-flight functionality with complete embedded browsing and
REM   zero restrictions, use the dedicated Android tablet app (EFB.apk).
REM =========================================================================

REM Ensures Windows Firewall allows your tablet to connect on Port 80 and 443 (asks for Admin once if not yet added)
netsh advfirewall firewall show rule name="EFB Web Server HTTPS" >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process netsh -Verb RunAs -Wait -ArgumentList 'advfirewall firewall add rule name=\"EFB Web Server HTTPS\" dir=in action=allow protocol=TCP localport=80,443 profile=any'"
)

REM Starts the local EFB server, displays the IP address, and opens the browser
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$running = try { (Invoke-WebRequest -Uri 'http://localhost/api/info' -UseBasicParsing -TimeoutSec 1).StatusCode -eq 200 } catch { $false }; " ^
  "if (-not $running) { Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0tools\serve.ps1' ; Start-Sleep -Milliseconds 1200 }; " ^
  "$ip = ((Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress -First 1)); " ^
  "Write-Host ''; " ^
  "Write-Host '=================================================================' -ForegroundColor Cyan; " ^
  "Write-Host '          VIRTUAL EFB - PC COMPANION & WI-FI SYNC SERVER        ' -ForegroundColor Cyan; " ^
  "Write-Host '=================================================================' -ForegroundColor Cyan; " ^
  "Write-Host ''; " ^
  "Write-Host '  PC Server Status     : ACTIVE (Running)' -ForegroundColor Green; " ^
  "Write-Host ('  YOUR PC IP FOR TABLET: ' + $ip) -ForegroundColor Yellow; " ^
  "Write-Host ('  TABLET DOWNLOAD URL  : http://' + $ip + '/EFB.apk') -ForegroundColor White; " ^
  "Write-Host '  DESKTOP BROWSER      : http://localhost/' -ForegroundColor White; " ^
  "Write-Host ''; " ^
  "Write-Host '=================================================================' -ForegroundColor Cyan; " ^
  "Write-Host '  Opening http://localhost/ in your browser...'; " ^
  "Write-Host '  (You can minimize this window while flying to sync checklists)'; " ^
  "Write-Host ''; " ^
  "Start-Process 'http://localhost/'"

pause
