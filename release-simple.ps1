# RouteGuard Release Script (GitHub API version)
# Creates a new GitHub release with all binaries
# Usage: .\release-simple.ps1 -Version "0.1.1" [-Token "ghp_xxx"]

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [string]$Token,
    
    [string]$Repo = "alexandr-kuz/RouteGuard",
    
    [switch]$PreRelease,
    
    [switch]$Force
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

function Get-GitHubToken {
    if ($Token) {
        return $Token
    }
    
    # Try to get from environment
    if ($env:GITHUB_TOKEN) {
        return $env:GITHUB_TOKEN
    }
    
    # Try to get from gh CLI
    $ghToken = gh auth token 2>$null
    if ($ghToken) {
        return $ghToken.Trim()
    }
    
    Log-Error "GitHub token not found."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  1. Set env: `$env:GITHUB_TOKEN = 'ghp_xxx'"
    Write-Host "  2. Pass param: .\release-simple.ps1 -Version '0.1.1' -Token 'ghp_xxx'"
    Write-Host "  3. Install gh CLI: winget install GitHub.cli"
    Write-Host ""
    Write-Host "Create token at: https://github.com/settings/tokens/new?scopes=repo"
    exit 1
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
        
        # MIPSLE (little-endian)
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
        
        # Windows
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
        npm install --silent 2>$null
        npm run build 2>$null
        if (Test-Path "dist") {
            Compress-Archive -Path "dist/*" -DestinationPath "../dist/frontend.zip" -Force
        }
    }
    catch {
        Log-Info "Frontend build skipped"
    }
    finally {
        Pop-Location
    }
    
    # Copy scripts
    Copy-Item "scripts/install.sh" "dist/install.sh" -Force
    Copy-Item "scripts/uninstall.sh" "dist/uninstall.sh" -Force
    
    Log-Success "All binaries built"
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
}

function Show-BuildInfo {
    Log-Step "Build artifacts"
    
    $files = Get-ChildItem "dist" -File | Sort-Object Name
    $totalSize = 0
    foreach ($file in $files) {
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        $totalSize += $file.Length
        Write-Host "  $($file.Name): $sizeMB MB"
    }
    Write-Host ""
    Write-Host "  Total: $([math]::Round($totalSize / 1MB, 2)) MB"
}

function Create-GitHubRelease {
    param($Token, $Version, $Repo, $IsPreRelease)
    
    Log-Step "Creating GitHub release"
    
    $tag = "v$Version"
    $headers = @{
        "Authorization" = "token $Token"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    # Check if release exists
    $releaseUrl = "https://api.github.com/repos/$Repo/releases/tags/$tag"
    try {
        $existing = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -Method Get
        if ($existing) {
            Log-Error "Release $tag already exists!"
            Log-Info "Delete it first: https://github.com/$Repo/releases"
            exit 1
        }
    }
    catch {
        # Release doesn't exist, continue
    }
    
    # Create release
    $createUrl = "https://api.github.com/repos/$Repo/releases"
    $body = @{
        tag_name = $tag
        name = "RouteGuard $tag"
        body = @"
## RouteGuard $tag

### Binaries
- `routeguard-mipsle` - MIPS little-endian (Keenetic, Asus, Xiaomi)
- `routeguard-mips` - MIPS big-endian (rare routers)
- `routeguard-arm` - ARMv7 (most ARM routers)
- `routeguard-arm64` - ARM64 (modern ARM routers)
- `routeguard-amd64` - x86_64 Linux
- `routeguard-windows.exe` - Windows

### Installation
``````
curl -sL https://github.com/$Repo/releases/download/$tag/install.sh | sh
``````
"@
        prerelease = $IsPreRelease
    } | ConvertTo-Json -Depth 10
    
    Log-Info "Creating release $tag..."
    $release = Invoke-RestMethod -Uri $createUrl -Headers $headers -Method Post -Body $body
    $uploadUrl = $release.upload_url -replace '\{.*\}', ''
    
    Log-Success "Release created: $($release.html_url)"
    
    # Upload files
    $files = @(
        "routeguard-mipsle",
        "routeguard-mips",
        "routeguard-arm",
        "routeguard-arm64",
        "routeguard-amd64",
        "routeguard-windows.exe",
        "install.sh",
        "uninstall.sh",
        "frontend.zip"
    )
    
    foreach ($fileName in $files) {
        $filePath = "dist/$fileName"
        if (-not (Test-Path $filePath)) {
            continue
        }
        
        Log-Info "Uploading $fileName..."
        
        $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $filePath))
        $fileBase64 = [System.Convert]::ToBase64String($fileBytes)
        
        # Determine content type
        $contentType = "application/octet-stream"
        if ($fileName -match "\.sh$") {
            $contentType = "text/x-sh"
        } elseif ($fileName -match "\.zip$") {
            $contentType = "application/zip"
        } elseif ($fileName -match "\.exe$") {
            $contentType = "application/vnd.microsoft.portable-executable"
        }
        
        $uploadHeaders = @{
            "Authorization" = "token $Token"
            "Content-Type" = $contentType
        }
        
        $uploadFileUrl = "$uploadUrl?name=$fileName"
        
        try {
            Invoke-RestMethod -Uri $uploadFileUrl -Headers $uploadHeaders -Method Post -Body $fileBytes
            Log-Success "Uploaded $fileName"
        }
        catch {
            $errMsg = $_.Exception.Message
            Log-Error "Failed to upload $fileName : $errMsg"
        }
    }
    
    return $release.html_url
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

# Get token
$githubToken = Get-GitHubToken

# Confirm release
if (-not $PreRelease -and -not $Force) {
    $confirm = Read-Host "Create release v$Version? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Log-Info "Aborted"
        exit 0
    }
}

# Check for uncommitted changes
$status = git status --porcelain 2>$null
if ($status) {
    Log-Info "Committing changes..."
    git add .
    git commit -m "chore: prepare release v$Version"
}

Update-VersionFiles

# Commit version update
git add .
git commit -m "chore: bump version to $Version" 2>$null

Build-All
Show-BuildInfo

$releaseUrl = Create-GitHubRelease -Token $githubToken -Version $Version -Repo $Repo -IsPreRelease $PreRelease

# Push changes
Log-Info "Pushing to GitHub..."
git push origin main

Write-Host ""
Log-Success "Done!"
Write-Host ""
Write-Host "Release URL: $releaseUrl"
Write-Host ""
