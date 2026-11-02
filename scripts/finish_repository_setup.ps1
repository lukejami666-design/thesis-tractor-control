param([switch]$Publish, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Git command failed: git $($args -join ' ')" }
}
Push-Location -LiteralPath $root
try {
    & (Join-Path $PSScriptRoot 'check_repository.ps1')
    # --quiet avoids a terminating native stderr error on Windows PowerShell 5.1.
    git rev-parse --verify --quiet HEAD | Out-Null
    $hasHead = $LASTEXITCODE -eq 0
    if ($CheckOnly) {
        Write-Output "Preflight passed (PowerShell $($PSVersionTable.PSVersion)); existing commit: $hasHead. No Git state changed."
        return
    }
    if (-not $hasHead) {
        $staged = @(git diff --cached --name-only)
        if ($staged.Count) { throw 'Existing staged changes found; review them before creating the initial commit.' }
        if ((git branch --show-current) -ne 'main') { Invoke-Git branch -m main }
        Invoke-Git add -- .gitattributes .gitignore README.md docs results scripts simulation
        Invoke-Git diff --cached --stat
        Invoke-Git commit -m 'chore: establish thesis project management baseline'
        Invoke-Git tag -a v0.1-baseline -m 'File-management baseline; see docs/validation.md for simulation status'
        Invoke-Git branch dev
    } else {
        $branch = git branch --show-current
        if ($branch -ne 'main') { throw 'Expected main for publishing; no branch switch performed.' }
        Invoke-Git rev-parse --verify v0.1-baseline
        Invoke-Git show-ref --verify refs/heads/dev
    }
    if (@(git status --porcelain).Count) { throw 'Working tree is not clean; review changes before publishing.' }
    $clone = Join-Path $root ('.local/clone-verification-' + [guid]::NewGuid().ToString('N'))
    Invoke-Git clone --no-hardlinks -- $root $clone
    & (Join-Path $clone 'scripts/check_repository.ps1')
    if ($Publish) {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install official GitHub CLI and run gh auth login first; local baseline and clone verification are complete.' }
        & gh auth status
        if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated.' }
        $remotes = @(git remote)
        if ('origin' -in $remotes) { throw 'origin already exists; verify it and push manually instead of replacing it.' }
        & gh repo create thesis-tractor-control --private --source . --remote origin
        if ($LASTEXITCODE -ne 0) { throw 'Private repository creation failed.' }
        Invoke-Git push -u origin main
        Invoke-Git push -u origin dev
        Invoke-Git push origin v0.1-baseline
    }
    Write-Output 'Local baseline, tag, dev branch and clone verification complete.'
} finally { Pop-Location }
