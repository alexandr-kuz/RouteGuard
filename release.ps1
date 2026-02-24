# RouteGuard Release Script
# Creates a new GitHub release with all binaries
# Usage: .\release.ps1 -Version "0.1.1" [-PreRelease]

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [switch]$PreRelease,
    
    [string]$Repo = "alexandr-kuz/RouteGuard"
)

$ErrorActionPreference = "Stop"

# Colors
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$YELLOW = "`e[1;33m"
$NC = "`e[0m"

function Log-Info($msg)    { Write-Host "${BLUE}[INFO]${NC} $msg" }
function Log-Success($msg) { Write-Host "${GREEN}[OK]${NC} $msg" }
function Log-Error($msg)   { Write-Host "${RED}[ERROR]${NC} $msg" }
function Log-Step($msg)    { Write-Host "${BLUE}=== $msg ===${NC}" }

function Check-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Log-Error "git not found"
        exit 1
    }
    
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Log-Error "gh (GitHub CLI) not found. Install from: https://cli.github.com/"
        exit 1
    }
    
    # Check if gh is authenticated
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log-Error "GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    }
    
    Log-Success "Git and GitHub CLI ready"
}

function Check-Uncommitted {
    $status = git status --porcelain
    if ($status) {
        Log-Error "Uncommitted changes detected:"
        Write-Host $status
        Write-Host ""
        Log-Info "Commit or stash changes before release"
        exit 1
    }
    Log-Success "Working directory clean"
}

function Build-All {
    Log-Step "Building all binaries"
    
    # Clean
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "dist"
    New-Item -ItemType Directory -Force -Path "dist" | Out-Null
    
    # Build backend for all architectures
    $env:CGO_ENABLED = "0"
    $env:GOFLAGS = "-buildvcs=false"
    
    Push-Location backend
    try {
        # MIPS (big-endian)
        Log-Info "Building for MIPS..."
        $env:GOOS = "linux"; $env:GOARCH = "mips"
        go build -ldflags="-s -w" -trimpath -o "../dist/routeguard-mips" ./
        
        # MIPSLE (little-endian) - Keenetic, Asus, Xiaomi
        Log-Info "Building for MIPSLE..."
        $env:GOOS = "linux"; $env:GOARCH = "mipsle"
        go build -ldflags="-s -w" -trimpath -o "../dist/routeguard-mipsle" ./
        
        # ARM
        Log-Info "Building for ARM..."
        $env:GOOS = "linux"; $env:GOARCH = "arm"; $env:GOARM = "7"
        go build -ldflags="-s -w" -trimpath -o "../dist/routeguard-arm" ./
        
        # ARM64
        Log-Info "Building for ARM64..."
        $env:GOOS = "linux"; $env:GOARCH = "arm64"
        go build -ldflags="-s -w" -trimpath -o "../dist/routeguard-arm64" ./
        
        # AMD64
        Log-Info "Building for AMD64..."
        $env:GOOS = "linux"; $env:GOARCH = "amd64"
        go build -ldflags="-s -w" -trimpath -o "../dist/routeguard-amd64" ./
        
        # Windows (for testing)
        Log-Info "Building for Windows..."
        $env:GOOS = "windows"; $env:GOARCH = "amd64"
        go build -ldflags="-s -w" -trimpath -o "../dist/routeguard-windows.exe" ./
        
        $env:GOOS = ""; $env:GOARCH = ""; $env:GOARM = ""
    }
    finally {
        Pop-Location
    }
    
    # Build frontend
    Log-Info "Building frontend..."
    Push-Location frontend
    try {
        npm install --silent
        npm run build
        if (Test-Path "dist") {
            Compress-Archive -Path "dist/*" -DestinationPath "../dist/frontend.zip" -Force
        }
    }
    finally {
        Pop-Location
    }
    
    # Copy scripts
    Copy-Item "scripts/install.sh" "dist/install.sh" -Force
    Copy-Item "scripts/uninstall.sh" "dist/uninstall.sh" -Force
    
    Log-Success "All binaries built"
}

function Show-BuildInfo {
    Log-Step "Build artifacts"
    
    $files = Get-ChildItem "dist" -File | Sort-Object Name
    foreach ($file in $files) {
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        Write-Host "  $($file.Name): $sizeMB MB"
    }
}

function Create-Release {
    Log-Step "Creating GitHub release"
    
    $tag = "v$Version"
    $releaseDir = "dist"
    
    # Prepare release notes
    $notes = @"
## RouteGuard $tag

### Binaries
- `routeguard-mipsle` - MIPS little-endian (Keenetic, Asus, Xiaomi routers)
- `routeguard-mips` - MIPS big-endian (rare routers)
- `routeguard-arm` - ARMv7 (most ARM routers)
- `routeguard-arm64` - ARM64 (modern ARM routers)
- `routeguard-amd64` - x86_64 Linux (mini-PCs, VMs)
- `routeguard-windows.exe` - Windows (testing)

### Installation
\`\`\`sh
curl -sL https://github.com/$Repo/releases/download/$tag/install.sh | sh
\`\`\`

### Manual Installation
1. Download binary for your architecture
2. Upload to router: \`scp routeguard-mipsle root@router:/opt/bin/routeguard\`
3. Run installer: \`sh install.sh\`

### What's Changed
See [commits](https://github.com/$Repo/compare/v0.1.0...$tag)
"@
    
    # Save release notes
    $notesPath = "dist/release-notes.md"
    $notes | Out-File -FilePath $notesPath -Encoding utf8
    
    # Build gh release command
    $releaseArgs = @(
        "release", "create", $tag,
        "--repo", $Repo,
        "--title", "RouteGuard $tag",
        "--notes-file", $notesPath
    )
    
    if ($PreRelease) {
        $releaseArgs += "--prerelease"
    }
    
    # Add files
    $files = @(
        "$releaseDir/routeguard-mipsle",
        "$releaseDir/routeguard-mips",
        "$releaseDir/routeguard-arm",
        "$releaseDir/routeguard-arm64",
        "$releaseDir/routeguard-amd64",
        "$releaseDir/routeguard-windows.exe",
        "$releaseDir/install.sh",
        "$releaseDir/uninstall.sh",
        "$releaseDir/frontend.zip"
    )
    
    foreach ($file in $files) {
        if (Test-Path $file) {
            $releaseArgs += $file
        }
    }
    
    Log-Info "Running: gh $($releaseArgs -join ' ')"
    
    & gh $releaseArgs
    
    if ($LASTEXITCODE -eq 0) {
        Log-Success "Release created: https://github.com/$Repo/releases/tag/$tag"
    } else {
        Log-Error "Failed to create release"
        exit 1
    }
}

function Update-VersionFiles {
    Log-Step "Updating version in files"
    
    # Update backend version in main.go
    $mainFile = "backend/main.go"
    if (Test-Path $mainFile) {
        $content = Get-Content $mainFile -Raw
        $content = $content -replace 'appVersion\s*=\s*"[^"]*"', "appVersion = `"$Version`""
        Set-Content $mainFile $content -NoNewline
        Log-Success "Updated $mainFile"
    }
    
    # Update build.ps1 version
    $buildFile = "build.ps1"
    if (Test-Path $buildFile) {
        $content = Get-Content $buildFile -Raw
        $content = $content -replace 'Version\s*=\s*"[0-9.]+"', "Version = `"$Version`""
        Set-Content $buildFile $content -NoNewline
        Log-Success "Updated $buildFile"
    }
    
    # Update frontend package.json
    $pkgFile = "frontend/package.json"
    if (Test-Path $pkgFile) {
        $content = Get-Content $pkgFile -Raw | ConvertFrom-Json
        $content.version = $Version
        $content | ConvertTo-Json -Depth 10 | Set-Content $pkgFile
        Log-Success "Updated $pkgFile"
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Host ""
Write-Host "${BLUE}==============================================${NC}"
Write-Host "${BLUE}  RouteGuard Release Script${NC}"
Write-Host "${BLUE}==============================================${NC}"
Write-Host ""

Log-Info "Version: $Version"
Log-Info "Repository: $Repo"
if ($PreRelease) {
    Log-Info "Type: Pre-release"
}
Write-Host ""

# Confirm release
if (-not $PreRelease) {
    $confirm = Read-Host "Create release v$Version? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Log-Info "Aborted"
        exit 0
    }
}

Check-Git
Check-Uncommitted
Update-VersionFiles

# Commit version update
git add .
git commit -m "chore: bump version to $Version" 2>$null

Build-All
Show-BuildInfo
Create-Release

Write-Host ""
Log-Success "Done!"
Write-Host ""
