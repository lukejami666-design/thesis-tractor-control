$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$simRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$archiveRoot = Join-Path $simRoot 'archive'
New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
$source = (Join-Path $simRoot 'models/tractor_mu.slx')
$candidate = (Join-Path $archiveRoot 'tractor_mu_repair_20261030.slx')
if (Test-Path -LiteralPath $candidate) { throw 'Candidate already exists' }
Copy-Item -LiteralPath $source -Destination $candidate
$zip = [System.IO.Compression.ZipFile]::Open($candidate,[System.IO.Compression.ZipArchiveMode]::Update)
try {
    $target = $null
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch '^simulink/stateflow/chart_.*\.xml$') { continue }
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $doc = [System.Xml.XmlDocument]::new()
        $doc.PreserveWhitespace = $true
        $doc.LoadXml($content)
        if ($doc.SelectSingleNode('/chart/P[@Name="name"]').InnerText -eq '驱动防滑模块/MATLAB Function5') {
            $target = $entry
            $script = $doc.SelectSingleNode('/chart/Children/state/eml/P[@Name="script"]')
            $script.InnerText = [System.IO.File]::ReadAllText((Join-Path $simRoot 'src/LaunchTCS_Torque_code.m'))
            break
        }
    }
    if (-not $target) { throw 'Torque Function not found' }
    $stream = $target.Open()
    $stream.SetLength(0)
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $writer = [System.Xml.XmlWriter]::Create($stream,$settings)
    try { $doc.Save($writer) } finally { $writer.Dispose(); $stream.Dispose() }
} finally { $zip.Dispose() }
Write-Output $candidate
