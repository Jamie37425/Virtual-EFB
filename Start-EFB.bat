@echo off
REM Ensures Windows Firewall allows your tablet to connect on Port 80 and 443 (asks for Admin once if not yet added)
netsh advfirewall firewall show rule name="EFB Web Server HTTPS" >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process netsh -Verb RunAs -Wait -ArgumentList 'advfirewall firewall add rule name=\"EFB Web Server HTTPS\" dir=in action=allow protocol=TCP localport=80,443 profile=any'"
)

REM Starts the local EFB web server on Port 80 & 443 (no port needed in URL) and opens http://localhost in Firefox with the unblocker active.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$running = try { (Invoke-WebRequest -Uri 'http://localhost/api/info' -UseBasicParsing -TimeoutSec 1).StatusCode -eq 200 } catch { $false }; " ^
  "if (-not $running) { Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0tools\serve.ps1' ; Start-Sleep -Milliseconds 1200 }; " ^
  "if (Test-Path 'C:\Program Files\Mozilla Firefox\firefox.exe') { Start-Process 'C:\Program Files\Mozilla Firefox\firefox.exe' -ArgumentList '-marionette','http://localhost/' ; Start-Sleep -Seconds 2 ; try { Invoke-WebRequest -Uri 'http://localhost/api/info' -UseBasicParsing -TimeoutSec 2 | Out-Null } catch {} } else { Start-Process 'http://localhost/' }"
