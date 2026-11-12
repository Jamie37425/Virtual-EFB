# Builds EFB.apk (no Android Studio / Gradle needed).  Usage:  powershell -ExecutionPolicy Bypass -File android\build.ps1
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$proj = Split-Path -Parent $here
$sdk  = "$env:LOCALAPPDATA\Android\Sdk"
$bt   = "$sdk\build-tools\34.0.0"
$jar  = "$sdk\platforms\android-34\android.jar"
$jdk  = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
$env:JAVA_HOME = $jdk
$javac = "$jdk\bin\javac.exe"; $keytool = "$jdk\bin\keytool.exe"; $jarTool = "$jdk\bin\jar.exe"

$out = Join-Path $here 'build'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force "$out\assets", "$out\classes", "$out\res\mipmap-xxhdpi" | Out-Null

# 1. Bundle the EFB web files into the app
foreach ($item in 'index.html', 'manifest.webmanifest', 'css', 'js', 'icons', 'apps', 'vendor', 'checklists') {
  $src = Join-Path $proj $item
  if (Test-Path $src) { Copy-Item $src "$out\assets\$item" -Recurse -Force }
}
Copy-Item (Join-Path $proj 'icons\icon-192.png') "$out\res\mipmap-xxhdpi\ic_launcher.png"

# 2. Resources + manifest -> base.apk (assets included)
& "$bt\aapt2.exe" compile --dir "$out\res" -o "$out\res.zip"
& "$bt\aapt2.exe" link -o "$out\base.apk" -I $jar --manifest "$here\AndroidManifest.xml" `
  --min-sdk-version 24 --target-sdk-version 34 "$out\res.zip"

# 3. Java -> classes -> classes.dex
$srcs = Get-ChildItem "$here\src" -Filter *.java -Recurse | ForEach-Object { $_.FullName }
& $javac --release 8 -nowarn -classpath $jar -d "$out\classes" $srcs
$cls = Get-ChildItem "$out\classes" -Filter *.class -Recurse | ForEach-Object { $_.FullName }
& "$bt\d8.bat" --lib $jar --min-api 24 --output $out @cls
# Add classes.dex + assets (using forward-slash entry names; aapt2 on Windows writes backslashes)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open("$out\base.apk", 'Update')
function Add-ZipFile($zip, $file, $name) {
  $e = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
  $s = $e.Open(); $b = [IO.File]::ReadAllBytes($file); $s.Write($b, 0, $b.Length); $s.Dispose()
}
Add-ZipFile $zip "$out\classes.dex" 'classes.dex'
$assetRoot = (Resolve-Path "$out\assets").Path
Get-ChildItem $assetRoot -Recurse -File | ForEach-Object {
  Add-ZipFile $zip $_.FullName ('assets/' + $_.FullName.Substring($assetRoot.Length + 1).Replace('\', '/'))
}
$zip.Dispose()

# 4. Align + sign (the signing key is kept so future builds install over the top, keeping logins)
$ks = Join-Path $here 'efb.keystore'
if (-not (Test-Path $ks)) {
  & $keytool -genkeypair -keystore $ks -storepass efbefb123 -keypass efbefb123 -alias efb -keyalg RSA -keysize 2048 -validity 36500 -dname 'CN=EFB' | Out-Null
}
& "$bt\zipalign.exe" -f -p 4 "$out\base.apk" "$out\aligned.apk"
& "$bt\apksigner.bat" sign --v4-signing-enabled false --ks $ks --ks-pass pass:efbefb123 --key-pass pass:efbefb123 --out (Join-Path $proj 'EFB.apk') "$out\aligned.apk"
Write-Host "Built: $(Join-Path $proj 'EFB.apk')  ($([math]::Round((Get-Item (Join-Path $proj 'EFB.apk')).Length/1MB,1)) MB)"
