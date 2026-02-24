# RouteGuard Build Script for Windows PowerShell
# Usage: .\build.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "build",
    
    [string]$Version = "0.2.1"
)

$ErrorActionPreference = "Stop"

# Colors
$BLUE = "`e[0;34m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$NC = "`e[0m"

function Log-Info($msg)    { Write-Host "${BLUE}[INFO]${NC} $msg" }
function Log-Success($msg) { Write-Host "${GREEN}[OK]${NC} $msg" }
function Log-Step($msg)    { Write-Host "${BLUE}=== $msg ===${NC}" }

function Build-Backend {
    Log-Step "Building backend"
    
    New-Item -ItemType Directory -Force -Path "dist" | Out-Null
    
    Push-Location backend
    try {
        go build `
            -ldflags="-s -w" `
            -trimpath `
            -o "../dist/routeguard.exe" `
            ./main.go
        Log-Success "Backend built: dist/routeguard.exe"
    }
    finally {
        Pop-Location
    }
}

function Build-Frontend {
    Log-Step "Building frontend"
    
    Push-Location frontend
    try {
        npm install --silent
        npm run build
        Log-Success "Frontend built: frontend/dist/"
    }
    finally {
        Pop-Location
    }
}

function Build-All {
    Build-Backend
    Build-Frontend
    Log-Success "Build complete"
}

function Build-BackendAll {
    Log-Step "Cross-compiling backend"
    
    New-Item -ItemType Directory -Force -Path "dist/mips" | Out-Null
    New-Item -ItemType Directory -Force -Path "dist/mipsle" | Out-Null
    New-Item -ItemType Directory -Force -Path "dist/arm" | Out-Null
    New-Item -ItemType Directory -Force -Path "dist/amd64" | Out-Null
    
    $env:CGO_ENABLED = "0"
    $env:GOFLAGS = "-buildvcs=false"
    
    Push-Location backend
    try {
        # MIPS (big-endian) - rare routers
        Log-Info "Building for MIPS (big-endian)..."
        $env:GOOS = "linux"; $env:GOARCH = "mips"
        go build -ldflags="-s -w -extldflags '-static'" -trimpath -o "../dist/mips/routeguard" ./
        
        # MIPSLE (little-endian) - Keenetic, Asus, Xiaomi
        Log-Info "Building for MIPSLE (little-endian)..."
        $env:GOOS = "linux"; $env:GOARCH = "mipsle"
        go build -ldflags="-s -w -extldflags '-static'" -trimpath -o "../dist/mipsle/routeguard" ./
        
        # ARM (ARMv7) - most ARM routers
        Log-Info "Building for ARM..."
        $env:GOOS = "linux"; $env:GOARCH = "arm"; $env:GOARM = "7"
        go build -ldflags="-s -w -extldflags '-static'" -trimpath -o "../dist/arm/routeguard" ./
        
        # AMD64 (x86_64) - mini-PCs, VMs
        Log-Info "Building for AMD64..."
        $env:GOOS = "linux"; $env:GOARCH = "amd64"
        go build -ldflags="-s -w -extldflags '-static'" -trimpath -o "../dist/amd64/routeguard" ./
        
        # Reset
        $env:GOOS = ""; $env:GOARCH = ""; $env:GOARM = ""
    }
    finally {
        Pop-Location
    }
    
    Log-Success "Cross-compilation complete"
}

function Run-Tests {
    Log-Step "Running tests"
    
    Push-Location backend
    try {
        go test -v ./...
        Log-Success "Tests passed"
    }
    finally {
        Pop-Location
    }
}

function Clean {
    Log-Step "Cleaning"
    
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "dist"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "frontend/dist"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "frontend/node_modules"
    
    Log-Success "Clean complete"
}

function Show-Help {
    Write-Host ""
    Write-Host "${BLUE}==============================================${NC}"
    Write-Host "${BLUE}  RouteGuard Build System (Windows)${NC}"
    Write-Host "${BLUE}==============================================${NC}"
    Write-Host ""
    Write-Host "  ${GREEN}build${NC}         - Build all components"
    Write-Host "  ${GREEN}backend${NC}       - Build backend (Go)"
    Write-Host "  ${GREEN}frontend${NC}      - Build frontend (Vue 3)"
    Write-Host "  ${GREEN}cross${NC}         - Cross-compile for MIPS/ARM/AMD64"
    Write-Host "  ${GREEN}test${NC}          - Run tests"
    Write-Host "  ${GREEN}clean${NC}         - Clean artifacts"
    Write-Host ""
}

# Main
Write-Host ""
Write-Host "${BLUE}==============================================${NC}"
Write-Host "${BLUE}  RouteGuard Build Script v$Version${NC}"
Write-Host "${BLUE}==============================================${NC}"
Write-Host ""

switch ($Command) {
    "build"    { Build-All }
    "backend"  { Build-Backend }
    "frontend" { Build-Frontend }
    "cross"    { Build-BackendAll }
    "test"     { Run-Tests }
    "clean"    { Clean }
    "help"     { Show-Help }
    default    { Show-Help; Write-Host "Unknown command: $Command" }
}
