# tools/update-runways.ps1
# Virtual EFB: Generates a high-precision, active-only runways database
# combining Geodetic GPS Threshold Azimuths, NOAA WMM-2025 Magnetic Declination,
# and Authoritative AIP overrides (data/runway-corrections.json).
# Closed runways are automatically filtered out.

param(
    [string]$SourceUrl = "https://davidmegginson.github.io/ourairports-data/runways.csv",
    [string]$CorrectionsPath = "$PSScriptRoot\..\data\runway-corrections.json",
    [string]$OutputPath = "$PSScriptRoot\..\vendor\runways.json",
    [string]$AndroidAssetPath = "$PSScriptRoot\..\android\build\assets\vendor\runways.json"
)

$ErrorActionPreference = "Stop"
Write-Host "=== Virtual EFB: Updating Runway Database (Geodetic Azimuth + WMM-2025) ===" -ForegroundColor Cyan

# 1. Download or load runways.csv using curl.exe for maximum speed
$tempCsv = Join-Path $env:TEMP "ourairports_runways.csv"
if (-not (Test-Path $tempCsv) -or (Get-Item $tempCsv).Length -lt 1000) {
    Write-Host "Fetching latest runways from $SourceUrl..."
    & curl.exe -s -L $SourceUrl -o $tempCsv
}
Write-Host "Using runways CSV: $([math]::Round((Get-Item $tempCsv).Length / 1MB, 2)) MB" -ForegroundColor Green

# 2. Compile Geodetic + WMM-2025 Engine in C# (.NET)
$csharpCode = @"
using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;

public class RunwayBuilder
{
    // NOAA World Magnetic Model (WMM-2025) Coefficients (Epoch 2025.0 - 2030.0)
    private static readonly double[] Q = new double[] {
        0,-29351.8,-1410.8,-2556.6,2951.1,1649.3,1361,-2404.1,1243.8,453.6,895,799.5,55.7,-281.1,12.1,-233.2,368.9,187.2,-138.7,-142,20.9,64.4,63.8,76.9,-115.7,-40.9,14.9,-60.7,79.5,-77,-8.8,59.3,15.8,2.5,-11.1,14.2,23.2,10.8,-17.5,2,-21.7,16.9,15,-16.8,0.9,4.6,7.8,3,-0.2,-2.5,-13.1,2.4,8.6,-8.7,-12.9,-1.3,-6.4,0.2,2,-1,-0.6,-0.9,1.5,0.9,-2.7,-3.9,2.9,-1.5,-2.5,2.4,-0.6,-0.1,-0.6,-0.1,1.1,-1,-0.2,2.6,-2,-0.2,0.3,1.2,-1.3,0.6,0.6,0.5,-0.1,-0.4,-0.2,-1.3,-0.7
    };
    private static readonly double[] X = new double[] {
        0,0,4545.4,0,-3133.6,-815.1,0,-56.6,237.5,-549.5,0,278.6,-133.9,212,-375.6,0,45.4,220.2,-122.9,43,106.1,0,-18.4,16.8,48.8,-59.8,10.9,72.7,0,-48.9,-14.4,-1,23.4,-7.4,-25.1,-2.3,0,7.1,-12.6,11.4,-9.7,12.7,0.7,-5.2,3.9,0,-24.8,12.2,8.3,-3.3,-5.2,7.2,-0.6,0.8,10,0,3.3,0,2.4,5.3,-9.1,0.4,-4.2,-3.8,0.9,-9.1,0,0,2.9,-0.6,0.2,0.5,-0.3,-1.2,-1.7,-2.9,-1.8,-2.3,0,-1.3,0.7,1,-1.4,0,0.6,-0.1,0.8,0.1,-1,0.1,0.2
    };
    private static readonly double[] e0 = new double[] {
        0,12,9.7,-11.6,-5.2,-8,-1.3,-4.2,0.4,-15.6,-1.6,-2.4,-6,5.6,-7,0.6,1.4,0,0.6,2.2,0.9,-0.2,-0.4,0.9,1.2,-0.9,0.3,0.9,0,-0.1,-0.1,0.5,-0.1,-0.8,-0.8,0.8,-0.1,0.2,0,0.5,-0.1,0.3,0.2,0,0.2,0,-0.1,0.1,0.3,-0.3,0,0.3,-0.1,0.1,-0.1,0.1,0,0.1,0.1,0,-0.3,0,-0.1,-0.1,0,0,0,0,0,0,0,-0.1,0,0,-0.1,-0.1,-0.1,-0.1,0,0,0,0,0,0,0.1,0,0,0,-0.1,0,-0.1
    };
    private static readonly double[] t0 = new double[] {
        0,0,-21.5,0,-27.7,-12.1,0,4,-0.3,-4.1,0,-1.1,4.1,1.6,-4.4,0,-0.5,2.2,0.4,1.7,1.9,0,0.3,-1.6,-0.4,0.9,0.7,0.9,0,0.6,0.5,-0.8,0,-1,0.6,-0.2,0,-0.2,0.5,-0.4,0.4,-0.5,-0.6,0.3,0.2,0,-0.3,0.3,-0.3,0.3,0.2,-0.1,-0.2,0.4,0.1,0,0,0,-0.2,0.1,-0.1,0.1,0,-0.1,0.2,0,0,0,0.1,0,0.1,0,0,0.1,0,0,0,0,0,0,0,-0.1,0.1,0,0,0,0,0,0,0,-0.1
    };

    private const int n_max = 12;
    private const double epoch = 2025.0;
    private const double a = 6378.137;
    private const double b = 6356.7523142;
    private const double re = 6371.2;
    private static readonly double epssq = 1.0 - (b * b) / (a * a);
    private static readonly Dictionary<string, double> declCache = new Dictionary<string, double>();

    public static double GetDeclination(double latDeg, double lonDeg, double year = 2026.0)
    {
        string key = Math.Round(latDeg, 1) + "_" + Math.Round(lonDeg, 1);
        double cached;
        if (declCache.TryGetValue(key, out cached)) return cached;

        double dyear = year - epoch;
        double phi = latDeg * Math.PI / 180.0;
        double lambda = lonDeg * Math.PI / 180.0;

        double sinPhi = Math.Sin(phi);
        double cosPhi = Math.Cos(phi);
        double s = a / Math.Sqrt(1.0 - epssq * sinPhi * sinPhi);
        double eCoord = s * cosPhi;
        double nCoord = s * (1.0 - epssq) * sinPhi;
        double r = Math.Sqrt(eCoord * eCoord + nCoord * nCoord);
        double phig = Math.Asin(nCoord / r) * 180.0 / Math.PI;

        double cosLam = Math.Cos(lambda);
        double sinLam = Math.Sin(lambda);
        double[] o = new double[n_max + 1];
        double[] t = new double[n_max + 1];
        double[] f = new double[n_max + 1];
        o[0] = 1.0; o[1] = cosLam;
        t[0] = 0.0; t[1] = sinLam;
        f[0] = (re / r) * (re / r);

        for (int i = 1; i <= n_max; i++) f[i] = f[i - 1] * (re / r);
        for (int i = 2; i <= n_max; i++)
        {
            o[i] = o[i - 1] * cosLam - t[i - 1] * sinLam;
            t[i] = o[i - 1] * sinLam + t[i - 1] * cosLam;
        }

        double sinPhig = Math.Sin(Math.PI / 180.0 * phig);
        int numCoeffs = (n_max + 1) * (n_max + 2) / 2;
        double[] pcup = new double[numCoeffs];
        double[] dpcup = new double[numCoeffs];

        ComputeLegendre(sinPhig, n_max, pcup, dpcup);

        double bx = 0, by = 0, bz = 0;
        for (int n = 1; n <= n_max; n++)
        {
            for (int m = 0; m <= n; m++)
            {
                int idx = n * (n + 1) / 2 + m;
                double g = Q[idx] + dyear * e0[idx];
                double h = X[idx] + dyear * t0[idx];

                bz -= f[n] * (g * o[m] + h * t[m]) * (n + 1) * pcup[idx];
                by += f[n] * (g * t[m] - h * o[m]) * m * pcup[idx];
                bx -= f[n] * (g * o[m] + h * t[m]) * dpcup[idx];
            }
        }

        double cosPhig = Math.Cos(Math.PI / 180.0 * phig);
        if (Math.Abs(cosPhig) > 1e-10) by /= cosPhig;

        double rot = Math.PI / 180.0 * (phig - latDeg);
        double bz_rot = bx * Math.Sin(rot) + bz * Math.Cos(rot);
        double bx_rot = bx * Math.Cos(rot) - bz * Math.Sin(rot);
        double by_rot = by;

        double decl = 180.0 / Math.PI * Math.Atan2(by_rot, bx_rot);
        declCache[key] = decl;
        return decl;
    }

    private static void ComputeLegendre(double sinPhig, int maxN, double[] pcup, double[] dpcup)
    {
        int num = (maxN + 1) * (maxN + 2) / 2;
        double[] c = new double[num];
        double[] d = new double[num];
        double[] v = new double[num];

        c[0] = 1.0; d[0] = 0.0; v[0] = 1.0;
        double s = Math.Sqrt(Math.Max(0.0, (1.0 - sinPhig) * (1.0 + sinPhig)));

        for (int e = 1; e <= maxN; e++)
        {
            for (int n = 0; n <= e; n++)
            {
                int oIdx = e * (e + 1) / 2 + n;
                if (e == n)
                {
                    int tIdx = (e - 1) * e / 2 + n - 1;
                    c[oIdx] = s * c[tIdx];
                    d[oIdx] = s * d[tIdx] + sinPhig * c[tIdx];
                }
                else if (e == 1 && n == 0)
                {
                    int tIdx = (e - 1) * e / 2 + n;
                    c[oIdx] = sinPhig * c[tIdx];
                    d[oIdx] = sinPhig * d[tIdx] - s * c[tIdx];
                }
                else if (e > 1 && e != n)
                {
                    int tIdx = (e - 2) * (e - 1) / 2 + n;
                    int fIdx = (e - 1) * e / 2 + n;
                    if (n > e - 2)
                    {
                        c[oIdx] = sinPhig * c[fIdx];
                        d[oIdx] = sinPhig * d[fIdx] - s * c[fIdx];
                    }
                    else
                    {
                        double k = (double)((e - 1) * (e - 1) - n * n) / ((2 * e - 1) * (2 * e - 3));
                        c[oIdx] = sinPhig * c[fIdx] - k * c[tIdx];
                        d[oIdx] = sinPhig * d[fIdx] - s * c[fIdx] - k * d[tIdx];
                    }
                }
            }
        }

        for (int e = 1; e <= maxN; e++)
        {
            int oIdx = e * (e + 1) / 2;
            int tIdx = (e - 1) * e / 2;
            v[oIdx] = v[tIdx] * (2.0 * e - 1.0) / e;
            for (int n = 1; n <= e; n++)
            {
                int o2 = e * (e + 1) / 2 + n;
                int t2 = e * (e + 1) / 2 + n - 1;
                v[o2] = v[t2] * Math.Sqrt((double)(e - n + 1) * (n == 1 ? 2.0 : 1.0) / (e + n));
            }
        }

        for (int e = 1; e <= maxN; e++)
        {
            for (int n = 0; n <= e; n++)
            {
                int oIdx = e * (e + 1) / 2 + n;
                pcup[oIdx] = c[oIdx] * v[oIdx];
                dpcup[oIdx] = -d[oIdx] * v[oIdx];
            }
        }
    }

    private static double? GetGeodeticBearing(double? lat1, double? lon1, double? lat2, double? lon2)
    {
        if (!lat1.HasValue || !lon1.HasValue || !lat2.HasValue || !lon2.HasValue) return null;
        double dLat = lat2.Value - lat1.Value;
        double dLonDeg = lon2.Value - lon1.Value;
        if (Math.Sqrt(dLat * dLat + dLonDeg * dLonDeg) < 0.002) return null;

        double p1 = lat1.Value * Math.PI / 180.0;
        double p2 = lat2.Value * Math.PI / 180.0;
        double dLon = dLonDeg * Math.PI / 180.0;

        double y = Math.Sin(dLon) * Math.Cos(p2);
        double x = Math.Cos(p1) * Math.Sin(p2) - Math.Sin(p1) * Math.Cos(p2) * Math.Cos(dLon);
        double b = Math.Atan2(y, x) * 180.0 / Math.PI;
        return (b + 360.0) % 360.0;
    }

    private static int? ComputeMagHeading(string airport, string ident, double? trueHdg, double? geoBearing, double? lat, double? lon, Dictionary<string, int> overrides)
    {
        string fullKey = airport + ":" + ident;
        if (overrides != null && overrides.ContainsKey(fullKey))
        {
            return overrides[fullKey];
        }

        double? chosenTrue = geoBearing ?? trueHdg;

        if (chosenTrue.HasValue && chosenTrue.Value >= 0 && chosenTrue.Value <= 360 && lat.HasValue && lon.HasValue)
        {
            double decl = GetDeclination(lat.Value, lon.Value);
            int mag = (int)Math.Round(chosenTrue.Value - decl);
            mag = ((mag % 360) + 360) % 360;
            return mag == 0 ? 360 : mag;
        }

        Match mNum = Regex.Match(ident, @"^[0-9]{1,2}");
        if (mNum.Success)
        {
            int num = int.Parse(mNum.Value);
            int nominal = (num * 10) % 360;
            return nominal == 0 ? 360 : nominal;
        }

        return null;
    }

    public static string BuildDatabase(string csvPath, string correctionsJsonPath = null)
    {
        var overrides = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        if (!string.IsNullOrEmpty(correctionsJsonPath) && File.Exists(correctionsJsonPath))
        {
            string rawCorr = File.ReadAllText(correctionsJsonPath, Encoding.UTF8);
            var matches = Regex.Matches(rawCorr, "\"([A-Za-z0-9]+:[A-Za-z0-9]+)\"\\s*:\\s*([0-9]+)");
            foreach (Match m in matches)
            {
                overrides[m.Groups[1].Value.ToUpper()] = int.Parse(m.Groups[2].Value);
            }
        }

        var db = new SortedDictionary<string, List<string>>();
        Regex identRegex = new Regex(@"^[0-9]{1,2}[LRC]?$", RegexOptions.IgnoreCase);

        using (var reader = new StreamReader(csvPath, Encoding.UTF8))
        {
            string headerLine = reader.ReadLine();
            if (headerLine == null) return "{}";

            var headers = ParseCsvLine(headerLine);
            int colClosed = headers.IndexOf("closed");
            int colAirport = headers.IndexOf("airport_ident");
            int colLeId = headers.IndexOf("le_ident");
            int colLeLat = headers.IndexOf("le_latitude_deg");
            int colLeLon = headers.IndexOf("le_longitude_deg");
            int colLeHdgT = headers.IndexOf("le_heading_degT");
            int colHeId = headers.IndexOf("he_ident");
            int colHeLat = headers.IndexOf("he_latitude_deg");
            int colHeLon = headers.IndexOf("he_longitude_deg");
            int colHeHdgT = headers.IndexOf("he_heading_degT");

            string line;
            while ((line = reader.ReadLine()) != null)
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                var row = ParseCsvLine(line);
                if (row.Count <= colClosed || row[colClosed] != "0") continue;

                string airport = CleanAirportIdent(row[colAirport]);
                if (airport.Length < 3 || airport.Length > 4) continue;

                string leId = CleanIdent(row.Count > colLeId ? row[colLeId] : "");
                string heId = CleanIdent(row.Count > colHeId ? row[colHeId] : "");

                double? leLat = ParseDouble(row, colLeLat);
                double? leLon = ParseDouble(row, colLeLon);
                double? leT = ParseDouble(row, colLeHdgT);

                double? heLat = ParseDouble(row, colHeLat) ?? leLat;
                double? heLon = ParseDouble(row, colHeLon) ?? leLon;
                double? heT = ParseDouble(row, colHeHdgT);

                double? leGeoBrg = GetGeodeticBearing(leLat, leLon, heLat, heLon);
                double? heGeoBrg = GetGeodeticBearing(heLat, heLon, leLat, leLon);

                int? leHdg = identRegex.IsMatch(leId) ? ComputeMagHeading(airport, leId, leT, leGeoBrg, leLat, leLon, overrides) : null;
                int? heHdg = identRegex.IsMatch(heId) ? ComputeMagHeading(airport, heId, heT, heGeoBrg, heLat, heLon, overrides) : null;

                if (leHdg.HasValue && !heHdg.HasValue && identRegex.IsMatch(heId))
                {
                    heHdg = ((leHdg.Value + 180 - 1) % 360) + 1;
                }
                else if (heHdg.HasValue && !leHdg.HasValue && identRegex.IsMatch(leId))
                {
                    leHdg = ((heHdg.Value + 180 - 1) % 360) + 1;
                }

                if (!leHdg.HasValue && !heHdg.HasValue) continue;

                if (!db.ContainsKey(airport)) db[airport] = new List<string>();

                if (leHdg.HasValue && identRegex.IsMatch(leId))
                {
                    string entry = leId + ":" + leHdg.Value;
                    if (!db[airport].Contains(entry)) db[airport].Add(entry);
                }

                if (heHdg.HasValue && identRegex.IsMatch(heId))
                {
                    string entry = heId + ":" + heHdg.Value;
                    if (!db[airport].Contains(entry)) db[airport].Add(entry);
                }
            }
        }

        var sb = new StringBuilder();
        sb.Append("{");
        bool firstAirport = true;
        foreach (var kvp in db)
        {
            kvp.Value.Sort((aStr, bStr) => {
                string idA = aStr.Split(':')[0];
                string idB = bStr.Split(':')[0];
                int na = ExtractNumber(idA);
                int nb = ExtractNumber(idB);
                if (na != nb) return na.CompareTo(nb);
                return idA.CompareTo(idB);
            });

            if (!firstAirport) sb.Append(",");
            firstAirport = false;

            sb.Append("\"").Append(kvp.Key).Append("\":[");
            for (int i = 0; i < kvp.Value.Count; i++)
            {
                if (i > 0) sb.Append(",");
                sb.Append("\"").Append(kvp.Value[i]).Append("\"");
            }
            sb.Append("]");
        }
        sb.Append("}");

        return sb.ToString();
    }

    private static int ExtractNumber(string s)
    {
        Match m = Regex.Match(s, @"\d+");
        return m.Success ? int.Parse(m.Value) : 0;
    }

    private static string CleanAirportIdent(string raw)
    {
        if (string.IsNullOrEmpty(raw)) return "";
        return Regex.Replace(raw, @"[^A-Za-z0-9]", "").ToUpper();
    }

    private static string CleanIdent(string raw)
    {
        if (string.IsNullOrEmpty(raw)) return "";
        return Regex.Replace(raw, @"[^A-Za-z0-9]", "").ToUpper();
    }

    private static double? ParseDouble(List<string> row, int col)
    {
        if (col < 0 || col >= row.Count) return null;
        double val;
        if (double.TryParse(row[col], System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out val))
        {
            return val;
        }
        return null;
    }

    private static List<string> ParseCsvLine(string line)
    {
        var list = new List<string>();
        var cur = new StringBuilder();
        bool inQuote = false;
        for (int i = 0; i < line.Length; i++)
        {
            char c = line[i];
            if (c == '\"') inQuote = !inQuote;
            else if (c == ',' && !inQuote) { list.Add(cur.ToString().Trim()); cur.Clear(); }
            else cur.Append(c);
        }
        list.Add(cur.ToString().Trim());
        return list;
    }
}
"@

Add-Type -TypeDefinition $csharpCode -Language CSharp
Write-Host "Running Geodetic Azimuth + WMM-2025 calculation on active runways..."
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$resolvedCorrections = if (Test-Path $CorrectionsPath) { [System.IO.Path]::GetFullPath($CorrectionsPath) } else { $null }
$json = [RunwayBuilder]::BuildDatabase($tempCsv, $resolvedCorrections)
$sw.Stop()

Write-Host "Database generated in $($sw.ElapsedMilliseconds) ms!" -ForegroundColor Green

# 3. Save compact JSON to vendor/runways.json
$resolvedOut = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.File]::WriteAllText($resolvedOut, $json, [System.Text.Encoding]::UTF8)
Write-Host "Wrote updated database to: $resolvedOut ($([math]::Round((Get-Item $resolvedOut).Length / 1KB)) KB)" -ForegroundColor Green

if (Test-Path $AndroidAssetPath) {
    $resolvedAndroid = [System.IO.Path]::GetFullPath($AndroidAssetPath)
    [System.IO.File]::WriteAllText($resolvedAndroid, $json, [System.Text.Encoding]::UTF8)
    Write-Host "Synced to Android assets: $resolvedAndroid" -ForegroundColor Green
}

# 4. Sanity check key airports
Write-Host "`n--- Verification Checks (Cockpit Magnetic Headings) ---" -ForegroundColor Cyan
$db = $json | ConvertFrom-Json
foreach ($testIcao in @('LMML', 'EFHK', 'EGPH', 'EGLL', 'KJFK', 'KSFO', 'KSEA', 'KMIA', 'LFPG', 'EDDF', 'KORD', 'KLAX')) {
    $rwys = $db.$testIcao -join ', '
    Write-Host "$testIcao : $rwys"
}

Write-Host "`nRunway database update completed successfully!" -ForegroundColor Green
