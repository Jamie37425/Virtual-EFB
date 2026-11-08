@echo off
REM Ensures Windows Firewall allows your tablet to connect on Port 80 and 443 (asks for Admin once if not yet added)
netsh advfirewall firewall show rule name="EFB Web Server HTTPS" >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process netsh -Verb RunAs -Wait -ArgumentList 'advfirewall firewall add rule name=\"EFB Web Server HTTPS\" dir=in action=allow protocol=TCP localport=80,443 profile=any'"
)

REM Starts the local EFB sync server on Port 80 & 443 and opens the PC Companion Status Page at http://localhost/
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$running = try { (Invoke-WebRequest -Uri 'http://localhost/api/info' -UseBasicParsing -TimeoutSec 1).StatusCode -eq 200 } catch { $false }; " ^
  "if (-not $running) { Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0tools\serve.ps1' ; Start-Sleep -Milliseconds 1200 }; " ^
  "Start-Process 'http://localhost/'"
