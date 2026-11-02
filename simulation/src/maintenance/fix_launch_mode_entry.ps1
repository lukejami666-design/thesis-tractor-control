$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$simRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$archiveRoot = Join-Path $simRoot 'archive'
New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

$source = (Join-Path $simRoot 'models/tractor_mu.slx')
$work = (Join-Path $archiveRoot '_launch_mode_entry_work_v2')
$target = (Join-Path $archiveRoot 'tractor_mu_mode_entry_fixed_v2.slx')
if (Test-Path -LiteralPath $work) { throw "Working folder already exists: $work" }
if (Test-Path -LiteralPath $target) { throw "Target already exists: $target" }

[System.IO.Compression.ZipFile]::ExtractToDirectory($source, $work)
$chartPath = Get-ChildItem -LiteralPath (Join-Path $work 'simulink\stateflow') -Filter 'chart_*.xml' |
    Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains('launch_state') } |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $chartPath) { throw 'launch_state chart was not found' }

$xml = [System.Xml.XmlDocument]::new()
$xml.PreserveWhitespace = $true
$xml.Load($chartPath)
$root = $xml.DocumentElement
$top = $root.SelectSingleNode('./Children')
$mode = $top.SelectSingleNode('./state[@SSID="89"]')
$disabled = $mode.SelectSingleNode('./Children/state[@SSID="90"]')
$entry = $top.SelectSingleNode('./transition[not(src/P[@Name="SSID"])]')
if (-not $mode -or -not $disabled -or -not $entry) { throw 'Expected MODE, DISABLED, or default transition is missing' }
if ($mode.SelectSingleNode('./Children/transition[not(src/P[@Name="SSID"])]')) { throw 'MODE already has a default transition' }

$mode.SelectSingleNode('./P[@Name="type"]').InnerText = 'AND_STATE'
$entry.SelectSingleNode('./dst/P[@Name="SSID"]').InnerText = '90'
$entry.SelectSingleNode('./P[@Name="labelPosition"]').InnerText = '[1096 246 0 0]'
$entry.SelectSingleNode('./src/P[@Name="intersection"]').InnerText = '[0 0 1 0 1096 230 0 0]'
$entry.SelectSingleNode('./dst/P[@Name="intersection"]').InnerText = '[1 0 -1 0 1096 269 0 0]'
$entry.SelectSingleNode('./P[@Name="midPoint"]').InnerText = '[1096 249.5]'
$entry.SelectSingleNode('./P[@Name="dataLimits"]').InnerText = '[1096 1096 230 269]'
[void]$top.RemoveChild($entry)
[void]$mode.SelectSingleNode('./Children').AppendChild($entry)

$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Indent = $true
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$writer = [System.Xml.XmlWriter]::Create($chartPath, $settings)
$xml.Save($writer)
$writer.Close()

[System.IO.Compression.ZipFile]::CreateFromDirectory($work, $target)
Write-Output $target
