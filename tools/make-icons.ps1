# Generates the PNG app icons (icons/icon-192.png, icon-512.png, icon-maskable-512.png).
# Run once from the project folder:  powershell -ExecutionPolicy Bypass -File tools\make-icons.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'icons'
New-Item -ItemType Directory -Force -Path $out | Out-Null

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Make-Icon([int]$size, [string]$file, [bool]$maskable) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $s = $size / 512.0
  $navy = [System.Drawing.ColorTranslator]::FromHtml('#0a1626')
  $line = [System.Drawing.ColorTranslator]::FromHtml('#1f3d63')
  $cyan = [System.Drawing.ColorTranslator]::FromHtml('#19d3ff')
  $amber = [System.Drawing.ColorTranslator]::FromHtml('#ffb300')
  $green = [System.Drawing.ColorTranslator]::FromHtml('#2dff6e')

  if ($maskable) {
    $g.Clear($navy)                 # full bleed – Android crops it to a shape
    $k = 0.72                       # keep artwork inside the safe zone
  } else {
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.FillPath((New-Object System.Drawing.SolidBrush $navy), (New-RoundRect 0 0 $size $size (96 * $s)))
    $g.DrawPath((New-Object System.Drawing.Pen $line, (12 * $s)), (New-RoundRect (40 * $s) (40 * $s) (432 * $s) (432 * $s) (64 * $s)))
    $k = 1.0
  }
  $c = $size / 2.0
  $font = New-Object System.Drawing.Font 'Arial', ([float](130 * $s * $k)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
  $g.DrawString('EFB', $font, (New-Object System.Drawing.SolidBrush $cyan), (New-Object System.Drawing.RectangleF 0, ($c - 150 * $s * $k), $size, (260 * $s * $k)), $fmt)
  $g.FillPath((New-Object System.Drawing.SolidBrush $amber), (New-RoundRect ($c - 120 * $s * $k) ($c + 84 * $s * $k) (240 * $s * $k) (14 * $s * $k) (7 * $s * $k)))
  $r = 12 * $s * $k
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $green), ($c - $r), ($c - 106 * $s * $k - $r), (2 * $r), (2 * $r))
  $g.Dispose()
  $bmp.Save((Join-Path $out $file), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "Created $file"
}

Make-Icon 192 'icon-192.png' $false
Make-Icon 512 'icon-512.png' $false
Make-Icon 512 'icon-maskable-512.png' $true
