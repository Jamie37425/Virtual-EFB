# Tiny local web server for running the EFB on this PC (http://localhost) and on any tablet (https://192.168.x.x).
# Listens on Port 80 (HTTP) and Port 443 (HTTPS) simultaneously so NO port number is ever needed in the URL,
# and tablets get a full Secure Context (https://) required by Navigraph Charts (WebCrypto) and VATSIM Radar.
param([int]$Port = 80, [int]$HttpsPort = 443)
$root = Split-Path -Parent $PSScriptRoot
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.js' = 'application/javascript; charset=utf-8'; '.json' = 'application/json'; '.webmanifest' = 'application/manifest+json'
  '.png' = 'image/png'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.jpg' = 'image/jpeg'; '.pdf' = 'application/pdf'; '.apk' = 'application/vnd.android.package-archive'
}

function Send-HttpResponse($stream, [int]$statusCode, [string]$statusText, [string]$contentType, [byte[]]$bodyBytes, [hashtable]$extraHeaders = @{}) {
  if ($null -eq $bodyBytes) { $bodyBytes = [byte[]]::new(0) }
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.Append("HTTP/1.1 $statusCode $statusText`r`n")
  [void]$sb.Append("Content-Type: $contentType`r`n")
  [void]$sb.Append("Content-Length: $($bodyBytes.Length)`r`n")
  [void]$sb.Append("Cache-Control: no-cache`r`n")
  [void]$sb.Append("Access-Control-Allow-Origin: *`r`n")
  [void]$sb.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n")
  [void]$sb.Append("Access-Control-Allow-Headers: Content-Type`r`n")
  [void]$sb.Append("Connection: close`r`n")
  foreach ($k in $extraHeaders.Keys) {
    [void]$sb.Append("${k}: $($extraHeaders[$k])`r`n")
  }
  [void]$sb.Append("`r`n")
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($sb.ToString())
  $stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($bodyBytes.Length -gt 0) {
    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
  }
  $stream.Flush()
}

$script:lastFirefoxPid = 0
function Install-FirefoxUnblocker {
  try {
    $ffConn = Get-NetTCPConnection -LocalPort 2828 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ffConn -or $ffConn.OwningProcess -eq $script:lastFirefoxPid) { return }
    $extPath = (Join-Path $root 'tools\efb-firefox-extension') -replace '\\', '\\'
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect('127.0.0.1', 2828, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne(200, $false)) { $tcp.Close(); return }
    $tcp.EndConnect($iar)
    $s = $tcp.GetStream()
    $s.ReadTimeout = 500
    $buf = New-Object byte[] 4096
    $null = $s.Read($buf, 0, $buf.Length)
    foreach ($cmd in @(
      '[0,1,"WebDriver:NewSession",{}]',
      "[0,2,`"Addon:Install`",{`"path`":`"$extPath`",`"temporary`":true}]"
    )) {
      $p = [System.Text.Encoding]::UTF8.GetBytes("$($cmd.Length):$cmd")
      $s.Write($p, 0, $p.Length)
      $s.Flush()
      Start-Sleep -Milliseconds 60
      if ($s.DataAvailable) { $null = $s.Read($buf, 0, $buf.Length) }
    }
    $tcp.Close()
    $script:lastFirefoxPid = $ffConn.OwningProcess
  } catch {}
}

$lanIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
  Select-Object -ExpandProperty IPAddress -First 1)

# Ensure Firefox profiles have cookie/storage unblocking & Marionette enabled (ASCII without BOM)
$ffProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffProfiles) {
  $userJs = @"
user_pref("toolkit.startup.max_resumed_crashes", -1);
user_pref("dom.securecontext.allowlist", "$lanIp,home");
user_pref("network.cookie.cookieBehavior", 0);
user_pref("network.cookie.sameSite.laxByDefault", false);
user_pref("network.cookie.sameSite.noneRequiresSecure", false);
user_pref("privacy.trackingprotection.enabled", false);
user_pref("privacy.trackingprotection.socialtracking.enabled", false);
user_pref("privacy.partition.network_state", false);
user_pref("privacy.partition.serviceWorkers", false);
user_pref("privacy.partition.always_partition_third_party_non_cookie_storage", false);
user_pref("dom.storage_access.enabled", false);
user_pref("dom.security.https_first", false);
user_pref("dom.security.https_first_pbm", false);
user_pref("marionette.enabled", true);
user_pref("marionette.port", 2828);
"@
  Get-ChildItem $ffProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    [System.IO.File]::WriteAllText((Join-Path $_.FullName 'user.js'), $userJs, [System.Text.Encoding]::ASCII)
  }
}
Install-FirefoxUnblocker

# Ensure self-signed HTTPS certificate exists for LAN IP & localhost
$cert = Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
  Where-Object { $_.FriendlyName -eq 'EFB Local HTTPS CSP' } |
  Select-Object -First 1
if (-not $cert) {
  $dnsNames = @('localhost', 'home')
  if ($lanIp) { $dnsNames = @($lanIp) + $dnsNames }
  try {
    $cert = New-SelfSignedCertificate -DnsName $dnsNames -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddYears(5) -FriendlyName 'EFB Local HTTPS CSP' -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' -KeyExportPolicy Exportable
  } catch {}
}

$listener80 = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
$listener80.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$listener80.Start(64)

$listener443 = $null
if ($cert) {
  try {
    $listener443 = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $HttpsPort)
    $listener443.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    $listener443.Start(64)
  } catch { $listener443 = $null }
}

Write-Host "EFB running!"
Write-Host "  On this PC : http://localhost/"
if ($lanIp) {
  Write-Host "  On tablet  : https://$lanIp/  (or http://$lanIp/)"
}

function Handle-Client($client, [bool]$isHttps) {
  try {
    $client.NoDelay = $true
    $client.ReceiveTimeout = 10000
    $client.SendTimeout = 10000
    $netStream = $client.GetStream()
    $stream = $netStream

    if ($isHttps) {
      $ssl = New-Object System.Net.Security.SslStream($netStream, $false)
      $ssl.AuthenticateAsServer($cert, $false, [System.Security.Authentication.SslProtocols]::Tls12, $false)
      $stream = $ssl
    }

    # Read until end of HTTP headers (\r\n\r\n)
    $ms = New-Object System.IO.MemoryStream
    $buf = New-Object byte[] 8192
    $headerEnd = -1
    while ($headerEnd -lt 0) {
      $read = $stream.Read($buf, 0, $buf.Length)
      if ($read -le 0) { break }
      $ms.Write($buf, 0, $read)
      $arr = $ms.ToArray()
      for ($i = [Math]::Max(0, $arr.Length - $read - 4); $i -le $arr.Length - 4; $i++) {
        if ($arr[$i] -eq 13 -and $arr[$i+1] -eq 10 -and $arr[$i+2] -eq 13 -and $arr[$i+3] -eq 10) {
          $headerEnd = $i + 4
          break
        }
      }
      if ($ms.Length -gt 65536) { break }
    }
    if ($headerEnd -lt 0) { $client.Close(); return }

    $allBytes = $ms.ToArray()
    $headerStr = [System.Text.Encoding]::ASCII.GetString($allBytes, 0, $headerEnd)
    $lines = $headerStr -split "`r`n"
    $reqLine = $lines[0] -split ' '
    if ($reqLine.Length -lt 2) { $client.Close(); return }
    $method = $reqLine[0].ToUpper()
    $rawTarget = $reqLine[1]

    # Parse Content-Length and Host
    $contentLength = 0
    $hostHeader = ''
    foreach ($line in $lines) {
      if ($line -match '^Content-Length:\s*(\d+)') {
        $contentLength = [int]$Matches[1]
      } elseif ($line -match '^Host:\s*(.+)$') {
        $hostHeader = $Matches[1].Trim()
      }
    }

    $bodyBytes = New-Object byte[] $contentLength
    $alreadyRead = $allBytes.Length - $headerEnd
    if ($alreadyRead -gt 0) {
      $toCopy = [Math]::Min($alreadyRead, $contentLength)
      [Array]::Copy($allBytes, $headerEnd, $bodyBytes, 0, $toCopy)
    }
    $offset = $alreadyRead
    while ($offset -lt $contentLength) {
      $r = $stream.Read($bodyBytes, $offset, $contentLength - $offset)
      if ($r -le 0) { break }
      $offset += $r
    }

    # Split path and query string
    $qIndex = $rawTarget.IndexOf('?')
    if ($qIndex -ge 0) {
      $rawPath = $rawTarget.Substring(0, $qIndex)
      $queryStr = $rawTarget.Substring($qIndex + 1)
    } else {
      $rawPath = $rawTarget
      $queryStr = ''
    }
    $path = [Uri]::UnescapeDataString($rawPath.TrimStart('/'))

    # CORS preflight (the EFB Android app fetches checklists / saves PDFs from this PC over the home network)
    if ($method -eq 'OPTIONS') {
      Send-HttpResponse $stream 204 'No Content' 'text/plain' ([byte[]]::new(0))
      $client.Close()
      return
    }

    # Checklist, state sync, ATIS, and APK download endpoints stay reachable over plain HTTP for the EFB Android app (no HTTPS redirect)
    $appApiPath = ($path -like 'checklists/*') -or ($path -eq 'EFB.apk') -or ($path -in @('api/save-checklist', 'api/delete-checklist', 'api/atis', 'api/state', 'api/sync-defaults', 'api/info'))

    # Redirect non-localhost HTTP requests (e.g. tablet on LAN IP) to HTTPS
    # so the tablet gets a full Secure Context (window.crypto.subtle + Secure cookies) without needing a port number.
    if (-not $isHttps -and -not $appApiPath -and $listener443 -and $hostHeader -and $hostHeader -notmatch '^(localhost|127\.0\.0\.1)(:\d+)?$') {
      $cleanHost = $hostHeader -replace ':\d+$', ''
      $httpsUrl = "https://$cleanHost$rawTarget"
      Send-HttpResponse $stream 302 'Found' 'text/plain' ([byte[]]::new(0)) @{ 'Location' = $httpsUrl }
      $client.Close()
      return
    }

    # API: Server network info (LAN IP for tablet)
    if ($method -eq 'GET' -and $path -eq 'api/info') {
      Install-FirefoxUnblocker
      $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress -First 1)
      $infoJson = (@{ ip = $ip; host = $env:COMPUTERNAME; port = $Port; https = [bool]$listener443 } | ConvertTo-Json -Compress)
      $b = [System.Text.Encoding]::UTF8.GetBytes($infoJson)
      Send-HttpResponse $stream 200 'OK' 'application/json' $b
      $client.Close()
      return
    }

    # API: Get current shared apps & settings state (for two-way sync between Tablet App & PC Web Version)
    if ($method -eq 'GET' -and $path -eq 'api/state') {
      try {
        $appJsPath = Join-Path $root 'js\app.js'
        $js = [System.IO.File]::ReadAllText($appJsPath)
        $stamp = 0
        if ($js -match 'const DEFAULT_STAMP = (\d+);') { $stamp = [int64]$Matches[1] }
        $appsRaw = '[]'
        if ($js -match '(?s)const DEFAULT_APPS = (\[.*?\]);') { $appsRaw = $Matches[1] }
        $setRaw = '{}'
        if ($js -match 'const DEFAULT_SETTINGS = (\{.*?\});') { $setRaw = $Matches[1] }
        $stateJson = "{`"stamp`":$stamp,`"apps`":$appsRaw,`"settings`":$setRaw}"
        $b = [System.Text.Encoding]::UTF8.GetBytes($stateJson)
        Send-HttpResponse $stream 200 'OK' 'application/json' $b
      } catch {
        Send-HttpResponse $stream 500 'Internal Server Error' 'text/plain' ([byte[]]::new(0))
      }
      $client.Close()
      return
    }

    # API: Sync current browser/tablet apps & settings directly into js/app.js defaults
    if ($method -eq 'POST' -and $path -eq 'api/sync-defaults') {
      try {
        $bodyText = [System.Text.Encoding]::UTF8.GetString($bodyBytes)
        $body = ConvertFrom-Json $bodyText
        $appJsPath = Join-Path $root 'js\app.js'
        if ((Test-Path $appJsPath) -and $body.apps) {
          $js = [System.IO.File]::ReadAllText($appJsPath)
          $curStamp = 0
          if ($js -match 'const DEFAULT_STAMP = (\d+);') { $curStamp = [int64]$Matches[1] }
          $stamp = [int64]$body.stamp
          if ($stamp -ge $curStamp) {
            $appsList = @()
            if ($body.apps -is [array]) { $appsList = $body.apps } else { $appsList = @($body.apps) }
            $appsItems = foreach ($a in $appsList) { $a | ConvertTo-Json -Depth 5 -Compress }
            $appsJson = '[' + ($appsItems -join ',') + ']'
            $setJson  = ($body.settings | ConvertTo-Json -Depth 5 -Compress)
            $js = [regex]::Replace($js, 'const DEFAULT_STAMP = \d+;', "const DEFAULT_STAMP = $stamp;")
            $js = [regex]::Replace($js, '(?s)const DEFAULT_APPS = \[.*?\];', "const DEFAULT_APPS = $appsJson;")
            if ($body.settings) {
              $js = [regex]::Replace($js, 'const DEFAULT_SETTINGS = \{.*?\};', "const DEFAULT_SETTINGS = $setJson;")
            }
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($appJsPath, $js, $utf8NoBom)
          }
        }
        $b = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
        Send-HttpResponse $stream 200 'OK' 'application/json' $b
      } catch {
        Send-HttpResponse $stream 500 'Internal Server Error' 'text/plain' ([byte[]]::new(0))
      }
      $client.Close()
      return
    }

    # API: Proxy ATIS from https://atis.guru/atis/<ICAO>
    if ($method -eq 'GET' -and $path -eq 'api/atis') {
      try {
        $icao = ''
        if ($queryStr -match '(?:^|&)icao=([^&]+)') {
          $icao = ([Uri]::UnescapeDataString($Matches[1]) -replace '[^A-Za-z0-9]', '').ToUpper()
        }
        $html = (Invoke-WebRequest -Uri "https://atis.guru/atis/$icao" -UseBasicParsing -TimeoutSec 10).Content
        $b = [System.Text.Encoding]::UTF8.GetBytes($html)
        Send-HttpResponse $stream 200 'OK' 'text/html; charset=utf-8' $b @{ 'Access-Control-Allow-Origin' = '*' }
      } catch {
        Send-HttpResponse $stream 502 'Bad Gateway' 'text/plain' ([byte[]]::new(0))
      }
      $client.Close()
      return
    }

function Read-JsonArray([string]$path) {
  if (-not (Test-Path $path)) { return @() }
  try {
    $raw = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return @() }
    $parsed = ConvertFrom-Json $raw
    if ($null -eq $parsed) { return @() }
    $flat = @()
    $items = if ($parsed -is [array]) { $parsed } else { @($parsed) }
    foreach ($x in $items) {
      if ($null -eq $x) { continue }
      if ($x -is [array]) { $flat += $x }
      elseif ($x.PSObject.Properties['value'] -and $x.value -is [array]) { $flat += $x.value }
      elseif ($x.PSObject.Properties['file']) { $flat += $x }
    }
    return $flat
  } catch { return @() }
}

function Write-JsonArray([string]$path, [array]$items) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $flat = @()
  foreach ($x in $items) {
    if ($null -eq $x) { continue }
    if ($x -is [array]) { $flat += $x }
    elseif ($x.PSObject.Properties['value'] -and $x.value -is [array]) { $flat += $x.value }
    elseif ($x.PSObject.Properties['file']) { $flat += $x }
  }
  if ($flat.Count -eq 0) {
    [System.IO.File]::WriteAllText($path, '[]', $utf8NoBom)
  } else {
    $jsonItems = foreach ($it in $flat) { $it | ConvertTo-Json -Depth 4 -Compress }
    $json = "[`r`n  " + ($jsonItems -join ",`r`n  ") + "`r`n]"
    [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
  }
}

function Sync-ChecklistFolder {
  $chkDir = Join-Path $root 'checklists'
  New-Item -ItemType Directory -Force $chkDir | Out-Null
  $idxPath = Join-Path $chkDir 'index.json'
  $list = Read-JsonArray $idxPath
  # Keep only entries whose PDF file actually exists on disk
  $valid = @()
  foreach ($item in $list) {
    if (-not $item -or -not $item.file) { continue }
    $rel = ($item.file -replace '^\.\./checklists/', '') -replace '/', '\'
    if (Test-Path (Join-Path $chkDir $rel) -PathType Leaf) {
      $valid += $item
    }
  }
  # Auto-discover any PDF files dropped into checklists/ (or subfolders like checklists/A320/*.pdf)
  $pdfFiles = Get-ChildItem $chkDir -Filter '*.pdf' -Recurse -File -ErrorAction SilentlyContinue
  foreach ($pdf in $pdfFiles) {
    $relPath = $pdf.FullName.Substring($chkDir.Length).TrimStart('\') -replace '\\', '/'
    $fileRef = "../checklists/$relPath"
    $exists = $valid | Where-Object { $_.file -eq $fileRef }
    if (-not $exists) {
      $base = [System.IO.Path]::GetFileNameWithoutExtension($pdf.Name)
      $parentDir = $pdf.Directory.Name
      if ($pdf.Directory.FullName -ne $chkDir) {
        $ac = $parentDir.ToUpper()
        $title = ($base -replace '[-_]+', ' ').Trim()
      } elseif ($base -match '\b([AB]\d{3}(?:-\d{3})?|B7\d{2}|CRJ\d*|E1\d{2}|ATR\d*|MD\d+|DC\d+)\b') {
        $ac = $Matches[1].ToUpper()
        $title = ($base -replace '[-_]+', ' ').Trim()
      } elseif ($base -match '^([A-Za-z0-9]{3,6})[-_\s]+(.+)$') {
        $ac = $Matches[1].ToUpper()
        $title = ($Matches[2] -replace '[-_]+', ' ').Trim()
      } else {
        $ac = 'CHECKLIST'
        $title = ($base -replace '[-_]+', ' ').Trim()
      }
      $id = 'pdf_' + ($relPath -replace '[^A-Za-z0-9]', '_').ToLower()
      $valid += [pscustomobject]@{
        id = $id
        aircraft = $ac
        title = $title
        file = $fileRef
      }
    }
  }
  Write-JsonArray $idxPath $valid
}

    # API: Save a checklist PDF directly into checklists/ folder & checklists/index.json
    if ($method -eq 'POST' -and $path -eq 'api/save-checklist') {
      try {
        $bodyText = [System.Text.Encoding]::UTF8.GetString($bodyBytes)
        $body = ConvertFrom-Json $bodyText
        $chkDir = Join-Path $root 'checklists'
        New-Item -ItemType Directory -Force $chkDir | Out-Null
        $safeName = (($body.aircraft + '-' + $body.title) -replace '[^A-Za-z0-9._-]+', '-').Trim('-') + '.pdf'
        $pdfBytes = [Convert]::FromBase64String($body.base64)
        [System.IO.File]::WriteAllBytes((Join-Path $chkDir $safeName), $pdfBytes)

        $idxPath = Join-Path $chkDir 'index.json'
        $list = Read-JsonArray $idxPath
        $existing = $list | Where-Object { $_.id -eq $body.id -or $_.file -eq "../checklists/$safeName" }
        if (-not $existing) {
          $list += [pscustomobject]@{
            id = $body.id
            aircraft = $body.aircraft
            title = $body.title
            file = "../checklists/$safeName"
          }
          Write-JsonArray $idxPath $list
        }
        Sync-ChecklistFolder
        $resBytes = [System.Text.Encoding]::UTF8.GetBytes((@{ ok = $true; file = "../checklists/$safeName" } | ConvertTo-Json -Compress))
        Send-HttpResponse $stream 200 'OK' 'application/json' $resBytes
      } catch {
        Send-HttpResponse $stream 500 'Internal Server Error' 'text/plain' ([byte[]]::new(0))
      }
      $client.Close()
      return
    }

    # API: Delete a checklist PDF from checklists/ folder & checklists/index.json
    if ($method -eq 'POST' -and $path -eq 'api/delete-checklist') {
      try {
        $bodyText = [System.Text.Encoding]::UTF8.GetString($bodyBytes)
        $body = ConvertFrom-Json $bodyText
        $chkDir = Join-Path $root 'checklists'
        $idxPath = Join-Path $chkDir 'index.json'
        if (Test-Path $idxPath) {
          $list = Read-JsonArray $idxPath
          $target = $list | Where-Object { $_.id -eq $body.id }
          if ($target) {
            foreach ($t in $target) {
              $fname = Split-Path -Leaf $t.file
              $fpath = Join-Path $chkDir $fname
              if (Test-Path $fpath) { Remove-Item $fpath -Force -ErrorAction SilentlyContinue }
            }
            $list = @($list | Where-Object { $_.id -ne $body.id })
            Write-JsonArray $idxPath $list
          }
        }
        Sync-ChecklistFolder
        $b = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
        Send-HttpResponse $stream 200 'OK' 'application/json' $b
      } catch {
        Send-HttpResponse $stream 500 'Internal Server Error' 'text/plain' ([byte[]]::new(0))
      }
      $client.Close()
      return
    }

    # Static file serving
    if ($path -eq 'checklists/index.json') {
      Sync-ChecklistFolder
    }
    if ($path -eq '') {
      $path = 'index.html'
      Install-FirefoxUnblocker
    }
    $file = [System.IO.Path]::GetFullPath((Join-Path $root $path))
    if ($file.StartsWith($root) -and (Test-Path $file -PathType Leaf)) {
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      $ct = if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' }
      $extra = @{}
      if ($ext -eq '.apk') {
        $extra['Content-Disposition'] = 'attachment; filename="EFB.apk"'
      }
      Send-HttpResponse $stream 200 'OK' $ct $bytes $extra
    } else {
      Send-HttpResponse $stream 404 'Not Found' 'text/plain' ([System.Text.Encoding]::UTF8.GetBytes('Not Found'))
    }
    $client.Close()
  } catch {
    try { $client.Close() } catch {}
  }
}

try {
  while ($true) {
    $handled = $false
    if ($listener80.Pending()) {
      $c = $listener80.AcceptTcpClient()
      Handle-Client $c $false
      $handled = $true
    }
    if ($listener443 -and $listener443.Pending()) {
      $c = $listener443.AcceptTcpClient()
      Handle-Client $c $true
      $handled = $true
    }
    if (-not $handled) {
      Start-Sleep -Milliseconds 15
    }
  }
} finally {
  $listener80.Stop()
  if ($listener443) { $listener443.Stop() }
}
