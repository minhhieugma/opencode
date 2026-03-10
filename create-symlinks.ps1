# Creates symlinks for the .claude folder from a shared source (ai-core-suites)
# into sibling project folders.
#
# Usage: .\create-symlinks.ps1
#   -SourceRepo  : Name of the repo containing the shared .claude folder (default: ai-core-suites)
#   -FolderName  : Name of the folder to symlink (default: .claude)
#   -Targets     : List of target repo folders. If omitted, all sibling folders are used.
#   -UseJunction : Use Junction instead of SymbolicLink (no admin required)

param(
    [string]$SourceRepo = "ai-core-suites",
    [string]$FolderName = ".claude",
    [string[]]$Targets,
    [switch]$UseJunction
)

$parentDir = Split-Path -Parent (Get-Location)
$sourcePath = Join-Path $parentDir $SourceRepo $FolderName

if (-not (Test-Path $sourcePath)) {
    Write-Error "Source folder not found: $sourcePath"
    exit 1
}

Write-Host "Source: $sourcePath" -ForegroundColor Cyan

# If no targets specified, use all sibling directories except the source repo
if (-not $Targets) {
    $Targets = Get-ChildItem -Path $parentDir -Directory |
        Where-Object { $_.Name -ne $SourceRepo } |
        Select-Object -ExpandProperty Name
}

$linkType = if ($UseJunction) { "Junction" } else { "SymbolicLink" }

foreach ($target in $Targets) {
    $targetDir = Join-Path $parentDir $target
    $linkPath = Join-Path $targetDir $FolderName

    if (-not (Test-Path $targetDir)) {
        Write-Warning "Skipping, folder not found: $targetDir"
        continue
    }

    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force
        if ($item.LinkType) {
            Write-Host "Already linked: $linkPath" -ForegroundColor Yellow
        } else {
            Write-Warning "Skipping, real folder exists: $linkPath"
        }
        continue
    }

    try {
        New-Item -ItemType $linkType -Path $linkPath -Target $sourcePath -Force | Out-Null
        Write-Host "Created $linkType`: $linkPath -> $sourcePath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create link in ${target}: $_"
    }
}
