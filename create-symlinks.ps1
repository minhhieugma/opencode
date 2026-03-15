# Creates symlinks for .claude/skills and .claude/commands from a shared source
# (ai-core-suites) into sibling project folders. Each target repo keeps its own
# .claude root (settings.json, etc.) while sharing skills and commands.
#
# Usage: .\create-symlinks.ps1
#   -SourceRepo  : Name of the repo containing the shared .claude folder (default: ai-core-suites)
#   -Subfolders  : Subfolders inside .claude to symlink (default: skills, commands)
#   -Targets     : List of target repo folders. If omitted, all sibling folders are used.
#   -UseJunction : Use Junction instead of SymbolicLink (no admin required)

param(
    [string]$SourceRepo = "ai-core-suites",
    [string[]]$Subfolders = @("skills", "commands"),
    [string[]]$Targets,
    [switch]$UseJunction
)

$parentDir = Split-Path -Parent (Get-Location)
$sourceClaudeDir = Join-Path $parentDir $SourceRepo ".claude"

if (-not (Test-Path $sourceClaudeDir)) {
    Write-Error "Source .claude folder not found: $sourceClaudeDir"
    exit 1
}

Write-Host "Source: $sourceClaudeDir" -ForegroundColor Cyan
Write-Host "Subfolders: $($Subfolders -join ', ')" -ForegroundColor Cyan

# If no targets specified, use all sibling directories except the source repo
if (-not $Targets) {
    $Targets = Get-ChildItem -Path $parentDir -Directory |
        Where-Object { $_.Name -ne $SourceRepo } |
        Select-Object -ExpandProperty Name
}

$linkType = if ($UseJunction) { "Junction" } else { "SymbolicLink" }

foreach ($target in $Targets) {
    $targetDir = Join-Path $parentDir $target

    if (-not (Test-Path $targetDir)) {
        Write-Warning "Skipping, folder not found: $targetDir"
        continue
    }

    # Ensure .claude directory exists in the target repo
    $targetClaudeDir = Join-Path $targetDir ".claude"
    if (-not (Test-Path $targetClaudeDir)) {
        New-Item -ItemType Directory -Path $targetClaudeDir | Out-Null
        Write-Host "Created .claude directory in $target" -ForegroundColor Gray
    }

    foreach ($subfolder in $Subfolders) {
        $sourcePath = Join-Path $sourceClaudeDir $subfolder
        $linkPath = Join-Path $targetClaudeDir $subfolder

        if (-not (Test-Path $sourcePath)) {
            Write-Warning "Source subfolder not found, skipping: $sourcePath"
            continue
        }

        if (Test-Path $linkPath) {
            $item = Get-Item $linkPath -Force
            if ($item.LinkType) {
                Write-Host "[$target] Already linked: $subfolder" -ForegroundColor Yellow
            } else {
                Write-Warning "[$target] Skipping, real folder exists: $subfolder"
            }
            continue
        }

        try {
            New-Item -ItemType $linkType -Path $linkPath -Target $sourcePath -Force | Out-Null
            Write-Host "[$target] Created $linkType`: $subfolder -> $sourcePath" -ForegroundColor Green
        } catch {
            Write-Error "[$target] Failed to create link for ${subfolder}: $_"
        }
    }
}
