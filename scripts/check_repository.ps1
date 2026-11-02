param([long]$MaxFileBytes = 100MB)
$ErrorActionPreference = 'Stop'
$previousConsoleEncoding = [Console]::OutputEncoding
$previousOutputEncoding = $OutputEncoding
$OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $OutputEncoding
$root = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $root
try {
    $output = git -c core.quotepath=false ls-files --cached --others --exclude-standard -z
    if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate Git candidate files.' }
    $paths = @(($output -join "`n").TrimEnd([char[]]"`r`n").Split([char]0, [StringSplitOptions]::RemoveEmptyEntries) | Sort-Object -Unique)
    $issues = [Collections.Generic.List[string]]::new()
    [long]$bytes = 0
    foreach ($relative in $paths) {
        $path = Join-Path $root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $file = Get-Item -LiteralPath $path
        $bytes += $file.Length
        if ($file.Length -ge $MaxFileBytes) { $issues.Add("File reaches size limit: $relative ($($file.Length) bytes)") }
        if ($relative -match '(^|/)(slprj|node_modules|archive|raw|generated)/|(^|/)local_paths\.m$|\.(autosave|slxc|asv)$') {
            $issues.Add("Local/generated file included: $relative")
        }
        if ($file.Extension -in @('.m','.py','.ps1') -and $file.Name -ne 'local_paths.example.m') {
            $content = [IO.File]::ReadAllText($path)
            if ($content -match '(?i)[a-z]:[\\/]') { $issues.Add("Hard-coded drive path: $relative") }
        }
    }
    foreach ($required in @('simulation/models/tractor_mu.slx','simulation/models/tractor_mu2018.slx','simulation/models/noslip_softsoil.slx','simulation/src/launch_tcs_params.m','simulation/data/sample/stage6_workspace.mat','docs/model-signal-dictionary.md','scripts/setup_project.m','.gitignore','.gitattributes')) {
        if ($required -notin $paths) { $issues.Add("Required file missing or ignored: $required") }
    }
    foreach ($ignored in @('.local/probe','文献/probe.pdf','开题/文献综述/probe.pdf','simulation/archive/probe.slx','simulation/data/raw/probe.mat','simulation/config/local_paths.m','simulation/slprj/probe.mat','results/generated/probe.txt')) {
        git check-ignore --quiet -- $ignored
        if ($LASTEXITCODE -ne 0) { $issues.Add("Ignore rule missing: $ignored") }
    }
    if ($issues.Count) { $issues | ForEach-Object { Write-Host "FAIL: $_" }; throw "Repository check failed: $($issues.Count) issue(s)." }
    Write-Output ("PASS: {0} candidate/tracked files, {1:N2} MiB; size, paths, required files and ignores checked." -f $paths.Count, ($bytes / 1MB))
} finally {
    Pop-Location
    [Console]::OutputEncoding = $previousConsoleEncoding
    $OutputEncoding = $previousOutputEncoding
}
