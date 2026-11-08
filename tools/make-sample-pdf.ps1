# Generates a clean sample A320 Normal Procedures PDF in checklists/A320-Normal-Checklist.pdf
$outDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'checklists'
New-Item -ItemType Directory -Force $outDir | Out-Null
$pdfPath = Join-Path $outDir 'A320-Normal-Checklist.pdf'

# Build a valid single-page PDF with crisp vector text
$lines = @(
  'BT /F1 18 Tf 50 780 Td (A320 - NORMAL CHECKLIST) Tj ET',
  'BT /F2 10 Tf 50 762 Td (FOR FLIGHT SIMULATION USE ONLY) Tj ET',
  '0.12 0.24 0.39 RG 1.5 w 50 752 m 545 752 l S',
  'BT /F1 13 Tf 50 730 Td (COCKPIT PREPARATION) Tj ET',
  'BT /F2 11 Tf 60 712 Td (Gear Pins & Covers ................................................ REMOVED) Tj ET',
  'BT /F2 11 Tf 60 696 Td (Fuel Quantity ........................................................ CHECKED) Tj ET',
  'BT /F2 11 Tf 60 680 Td (Seat Belts ................................................................... ON) Tj ET',
  'BT /F2 11 Tf 60 664 Td (ADIRS ....................................................................... NAV) Tj ET',
  'BT /F2 11 Tf 60 648 Td (Baro Ref ......................................................... SET (BOTH)) Tj ET',
  'BT /F1 13 Tf 50 618 Td (BEFORE START) Tj ET',
  'BT /F2 11 Tf 60 600 Td (Cockpit Prep ............................................ COMPLETED (BOTH)) Tj ET',
  'BT /F2 11 Tf 60 584 Td (Windows / Doors ............................................ CLOSED (BOTH)) Tj ET',
  'BT /F2 11 Tf 60 568 Td (Beacon ....................................................................... ON) Tj ET',
  'BT /F2 11 Tf 60 552 Td (Thrust Levers ............................................................. IDLE) Tj ET',
  'BT /F2 11 Tf 60 536 Td (Parking Brake ....................................................... AS RQRD) Tj ET',
  'BT /F1 13 Tf 50 506 Td (AFTER START) Tj ET',
  'BT /F2 11 Tf 60 488 Td (Anti Ice ............................................................... AS RQRD) Tj ET',
  'BT /F2 11 Tf 60 472 Td (ECAM Status ........................................................ CHECKED) Tj ET',
  'BT /F2 11 Tf 60 456 Td (Pitch Trim ................................................................. SET) Tj ET',
  'BT /F2 11 Tf 60 440 Td (Rudder Trim ............................................................. ZERO) Tj ET',
  'BT /F1 13 Tf 50 410 Td (BEFORE TAKEOFF) Tj ET',
  'BT /F2 11 Tf 60 392 Td (Flight Controls ............................................ CHECKED (BOTH)) Tj ET',
  'BT /F2 11 Tf 60 376 Td (Flap Setting .................................................... CONF _____ ) Tj ET',
  'BT /F2 11 Tf 60 360 Td (V1 / VR / V2 / FLX Temp ..................................... SET (BOTH)) Tj ET',
  'BT /F2 11 Tf 60 344 Td (ECAM Memo ..................................................... TO NO BLUE) Tj ET',
  'BT /F1 13 Tf 50 314 Td (APPROACH & LANDING) Tj ET',
  'BT /F2 11 Tf 60 296 Td (Briefing ........................................................... CONFIRMED) Tj ET',
  'BT /F2 11 Tf 60 280 Td (Baro Ref ......................................................... SET (BOTH)) Tj ET',
  'BT /F2 11 Tf 60 264 Td (Minimums (MDA / DH) ....................................... SET (BOTH)) Tj ET',
  'BT /F2 11 Tf 60 248 Td (ECAM Memo ................................................... LDG NO BLUE) Tj ET'
) -join "`n"

$objs = @(
  "1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n",
  "2 0 obj`n<< /Type /Pages /Kids [3 0 R] /Count 1 >>`nendobj`n",
  "3 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>`nendobj`n",
  "4 0 obj`n<< /Length $($lines.Length) >>`nstream`n$lines`nendstream`nendobj`n",
  "5 0 obj`n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>`nendobj`n",
  "6 0 obj`n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>`nendobj`n"
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("%PDF-1.4`n")
$offsets = @()
foreach ($o in $objs) {
  $offsets += $sb.Length
  [void]$sb.Append($o)
}
$xrefPos = $sb.Length
[void]$sb.Append("xref`n0 $($objs.Count + 1)`n0000000000 65535 f `n")
foreach ($off in $offsets) {
  [void]$sb.Append(($off.ToString('0000000000')) + " 00000 n `n")
}
[void]$sb.Append("trailer`n<< /Size $($objs.Count + 1) /Root 1 0 R >>`nstartxref`n$xrefPos`n%%EOF")
[System.IO.File]::WriteAllBytes($pdfPath, [System.Text.Encoding]::ASCII.GetBytes($sb.ToString()))
Write-Host "Created $pdfPath"
