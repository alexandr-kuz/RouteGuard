param(
    [string]$Token = "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",
    [string]$Repo = "alexandr-kuz/RouteGuard",
    [string]$Tag = "v0.2.1"
)

$ErrorActionPreference = "Stop"

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

$headers = @{
    "Authorization" = "token $Token"
    "Accept" = "application/vnd.github.v3+json"
    "Content-Type" = "application/octet-stream"
}

# Get release info
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" -Headers $headers
$uploadUrl = $release.upload_url -replace '\{.*\}', ''

Write-Host "Upload URL: $uploadUrl"
Write-Host ""

foreach ($file in $files) {
    $path = "dist\$file"
    if (-not (Test-Path $path)) {
        Write-Host "SKIP: $file (not found)"
        continue
    }

    $fileUrl = "$uploadUrl?name=$file"
    Write-Host "Uploading: $file..."

    try {
        $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $path))
        Invoke-RestMethod -Uri $fileUrl -Headers $headers -Method Post -Body $fileBytes | Out-Null
        Write-Host "  OK: $file" -ForegroundColor Green
    }
    catch {
        Write-Host "  FAILED: $file - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done! Release: $($release.html_url)" -ForegroundColor Green
