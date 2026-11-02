$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$simRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$archiveRoot = Join-Path $simRoot 'archive'
New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

$source = (Join-Path $simRoot 'models/tractor_mu.slx')
$reference = (Join-Path $simRoot 'models/launch_chart_check_valid.slx')
$work = (Join-Path $archiveRoot '_launch_compile_repair_v2')
$candidate = (Join-Path $archiveRoot 'tractor_mu_compile_repaired_v2.slx')
if (Test-Path -LiteralPath $work) { throw "Existing work directory: $work" }
if (Test-Path -LiteralPath $candidate) { throw "Existing candidate: $candidate" }

function Get-ChartPath($directory, $name) {
    Get-ChildItem -LiteralPath (Join-Path $directory 'simulink\stateflow') -Filter 'chart_*.xml' |
        Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains("<P Name=`"name`">$name</P>") } |
        Select-Object -First 1 -ExpandProperty FullName
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($source, $work)
$chartPath = Get-ChartPath $work '驱动防滑模块/launch_state'
if (-not $chartPath) { throw 'Target chart not found' }
$xml = [System.Xml.XmlDocument]::new()
$xml.PreserveWhitespace = $true
$xml.Load($chartPath)
$chart = $xml.DocumentElement
$children = $chart.SelectSingleNode('./Children')
$mode = $children.SelectSingleNode('./state[@SSID="89"]')
if (-not $mode -or $mode.SelectSingleNode('./P[@Name="decomposition"]').InnerText -ne 'CLUSTER_STATE') {
    throw 'Unexpected MODE hierarchy'
}

foreach ($name in @('no_move_raw','move_ok','speed_on_raw','speed_off_raw',
        'consistency_ok','source_immediate_bad','enable','reset')) {
    $data = $children.SelectSingleNode("./data[@name='$name']")
    if (-not $data) { throw "Missing Chart input: $name" }
    $data.SelectSingleNode('./props/array/P[@Name="size"]').InnerText = '1'
}
foreach ($name in @('enable','reset')) {
    $data = $children.SelectSingleNode("./data[@name='$name']")
    $data.SelectSingleNode('./props/type/P[@Name="primitive"]').InnerText = 'SF_DOUBLE_TYPE'
    $data.SelectSingleNode('./P[@Name="dataType"]').InnerText = 'double'
}

$validZip = [System.IO.Compression.ZipFile]::OpenRead($reference)
try {
    $validEntry = $validZip.Entries | Where-Object { $_.FullName -match '^simulink/stateflow/chart_.*\.xml$' } |
        ForEach-Object {
            $reader = [System.IO.StreamReader]::new($_.Open())
            try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($content.Contains('<P Name="name">launch_state</P>')) { $content }
        } | Select-Object -First 1
    if (-not $validEntry) { throw 'Validated Chart was not found' }
    $validXml = [System.Xml.XmlDocument]::new()
    $validXml.LoadXml($validEntry)
    $iData = $validXml.SelectSingleNode('/chart/Children/data[@name="i"]')
    if (-not $iData) { throw 'Validated local i was not found' }
    $newId = [int]$chart.SelectSingleNode('./P[@Name="ssIdHighWaterMark"]').InnerText + 1
    $imported = $xml.ImportNode($iData, $true)
    $imported.SetAttribute('SSID', [string]$newId)
    [void]$children.AppendChild($imported)
    $chart.SelectSingleNode('./P[@Name="ssIdHighWaterMark"]').InnerText = [string]$newId
} finally { $validZip.Dispose() }

# Top-level parallel states start together; MODE needs its own default entrance.
$default = $children.SelectSingleNode('./transition[not(src/P[@Name="SSID"])]')
if (-not $default) { throw 'Expected top-level default transition was not found' }
if ($mode.SelectSingleNode('./Children/transition[not(src/P[@Name="SSID"])]')) {
    throw 'MODE already has a default transition'
}
$default.SelectSingleNode('./dst/P[@Name="SSID"]').InnerText = '90'
$default.SelectSingleNode('./src/P[@Name="intersection"]').InnerText = '[0 0 1 0 1096 230 0 0]'
$default.SelectSingleNode('./dst/P[@Name="intersection"]').InnerText = '[1 0 -1 0 1096 269 0 0]'
$default.SelectSingleNode('./P[@Name="labelPosition"]').InnerText = '[1096 246 0 0]'
$default.SelectSingleNode('./P[@Name="midPoint"]').InnerText = '[1096 249.5]'
$default.SelectSingleNode('./P[@Name="dataLimits"]').InnerText = '[1096 1096 230 269]'
[void]$children.RemoveChild($default)
[void]$mode.SelectSingleNode('./Children').AppendChild($default)

$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Indent = $true
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$writer = [System.Xml.XmlWriter]::Create($chartPath, $settings)
try { $xml.Save($writer) } finally { $writer.Close() }
[System.IO.Compression.ZipFile]::CreateFromDirectory($work, $candidate)
Write-Output $candidate
