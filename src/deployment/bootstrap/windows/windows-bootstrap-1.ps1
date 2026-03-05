# windows-bootstrap-1.ps1
#Requires -RunAsAdministrator

Set-ExecutionPolicy Bypass -Scope Process -Force

# --- Install Chocolatey ---
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "Chocolatey already installed" -ForegroundColor Yellow
}

# --- Install Git ---
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..." -ForegroundColor Cyan
    choco install git -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "Git already installed" -ForegroundColor Yellow
}

# --- Enable Developer Mode (required for Git symlinks) ---
$devModePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
$devModeValue = (Get-ItemProperty -Path $devModePath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devModeValue -ne 1) {
    Write-Host "Enabling Windows Developer Mode (required for Git symlinks)..." -ForegroundColor Cyan
    Set-ItemProperty -Path $devModePath -Name "AllowDevelopmentWithoutDevLicense" -Value 1
    Write-Host "Developer Mode enabled" -ForegroundColor Green
} else {
    Write-Host "Developer Mode already enabled" -ForegroundColor Yellow
}

# --- Configure Git for symlinks and LF line endings ---
Write-Host "Configuring Git settings..." -ForegroundColor Cyan
git config --global core.symlinks true
git config --global core.autocrlf input
Write-Host "Git configured: core.symlinks=true, core.autocrlf=input" -ForegroundColor Green

# --- Install 7-Zip (needed for extracting MSYS2 packages) ---
$7z = "C:\Program Files\7-Zip\7z.exe"
if (!(Test-Path $7z)) {
    Write-Host "Installing 7-Zip..." -ForegroundColor Cyan
    choco install 7zip -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "7-Zip already installed" -ForegroundColor Yellow
}

# --- Common paths for MSYS2 package installations ---
$gitDir = "C:\Program Files\Git"

# --- Install Make (MSYS2 build into Git Bash) ---
# NOTE: Chocolatey's make is a native Windows32 build that breaks multi-line
# Makefile recipes (quoting issues with sh.exe). MSYS2's make works correctly.
$makeBin = "$gitDir\usr\bin\make.exe"
if (!(Test-Path $makeBin)) {
    # Uninstall Chocolatey make if present (it conflicts)
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco uninstall make -y 2>$null
    }

    Write-Host "Fetching latest Make package URL..." -ForegroundColor Cyan
    $repoPage = Invoke-WebRequest -Uri "https://packages.msys2.org/package/make?repo=msys&variant=x86_64" -UseBasicParsing
    $makeFile = ($repoPage.Links | Where-Object { $_.href -match "make-.*x86_64\.pkg\.tar\.zst$" } | Select-Object -First 1).href
    if (-not $makeFile) {
        Write-Host "Could not resolve latest Make URL. Falling back to known version." -ForegroundColor Yellow
        $makeFile = "https://mirror.msys2.org/msys/x86_64/make-4.4.1-2-x86_64.pkg.tar.zst"
    }
    if ($makeFile -notmatch "^https?://") {
        $makeFile = "https://mirror.msys2.org/msys/x86_64/$makeFile"
    }

    $makeArchive = "$env:TEMP\make.pkg.tar.zst"
    $makeTar = "$env:TEMP\make.pkg.tar"
    $makeExtract = "$env:TEMP\make-extract"

    Write-Host "Downloading Make from $makeFile..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $makeFile -OutFile $makeArchive

    Write-Host "Extracting Make into Git Bash..." -ForegroundColor Cyan
    & $7z x $makeArchive -o"$env:TEMP" -y | Out-Null
    & $7z x $makeTar -o"$makeExtract" -y | Out-Null

    if (Test-Path "$makeExtract\usr") { Copy-Item -Path "$makeExtract\usr\*" -Destination "$gitDir\usr" -Recurse -Force }

    Remove-Item $makeArchive, $makeTar, $makeExtract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Make installed into Git Bash" -ForegroundColor Green
} else {
    Write-Host "Make already installed in Git Bash" -ForegroundColor Yellow
}

# --- Install Zsh into Git Bash ---
$zshBin = "$gitDir\usr\bin\zsh.exe"

if (!(Test-Path $zshBin)) {
    Write-Host "Fetching latest Zsh package URL..." -ForegroundColor Cyan
    $repoPage = Invoke-WebRequest -Uri "https://packages.msys2.org/package/zsh?repo=msys&variant=x86_64" -UseBasicParsing
    $zshFile = ($repoPage.Links | Where-Object { $_.href -match "zsh-.*x86_64\.pkg\.tar\.zst$" } | Select-Object -First 1).href
    if (-not $zshFile) {
        Write-Host "Could not resolve latest Zsh URL. Falling back to known version." -ForegroundColor Yellow
        $zshFile = "https://mirror.msys2.org/msys/x86_64/zsh-5.9-5-x86_64.pkg.tar.zst"
    }
    if ($zshFile -notmatch "^https?://") {
        $zshFile = "https://mirror.msys2.org/msys/x86_64/$zshFile"
    }

    $zshArchive = "$env:TEMP\zsh.pkg.tar.zst"
    $zshTar = "$env:TEMP\zsh.pkg.tar"
    $zshExtract = "$env:TEMP\zsh-extract"

    Write-Host "Downloading Zsh from $zshFile..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $zshFile -OutFile $zshArchive

    Write-Host "Extracting Zsh into Git Bash..." -ForegroundColor Cyan
    & $7z x $zshArchive -o"$env:TEMP" -y | Out-Null
    & $7z x $zshTar -o"$zshExtract" -y | Out-Null

    if (Test-Path "$zshExtract\etc") { Copy-Item -Path "$zshExtract\etc\*" -Destination "$gitDir\etc" -Recurse -Force }
    if (Test-Path "$zshExtract\usr") { Copy-Item -Path "$zshExtract\usr\*" -Destination "$gitDir\usr" -Recurse -Force }

    Remove-Item $zshArchive, $zshTar, $zshExtract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Zsh installed into Git Bash" -ForegroundColor Green
} else {
    Write-Host "Zsh already installed in Git Bash" -ForegroundColor Yellow
}

# --- Install nvm-windows ---
if (!(Get-Command nvm -ErrorAction SilentlyContinue)) {
    Write-Host "Installing nvm-windows..." -ForegroundColor Cyan
    choco install nvm -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "nvm-windows already installed" -ForegroundColor Yellow
}

# --- Install Node.js LTS via nvm ---
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    Write-Host "Installing Node.js LTS via nvm..." -ForegroundColor Cyan
    nvm install lts
    nvm use lts
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # --- Install pnpm globally ---
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Installing pnpm globally..." -ForegroundColor Cyan
        npm install -g pnpm
        Write-Host "pnpm installed" -ForegroundColor Green
    } else {
        Write-Host "npm not found after nvm setup — skipping pnpm install" -ForegroundColor Yellow
    }
} else {
    Write-Host "nvm not found — skipping Node.js and pnpm install" -ForegroundColor Yellow
}

# --- Install Claude Code ---
$claudeBin = "$env:USERPROFILE\.local\bin\claude.exe"
if (!(Test-Path $claudeBin)) {
    Write-Host "Installing Claude Code..." -ForegroundColor Cyan
    irm https://claude.ai/install.ps1 | iex
} else {
    Write-Host "Claude Code already installed" -ForegroundColor Yellow
}

# --- Add Claude to User PATH ---
$claudePath = "$env:USERPROFILE\.local\bin"
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$claudePath*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$claudePath", "User")
    Write-Host "Added $claudePath to PATH" -ForegroundColor Green
} else {
    Write-Host "Claude already in PATH" -ForegroundColor Yellow
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# --- Hand off to bash script for shell setup ---
Write-Host "`nRunning bash setup..." -ForegroundColor Cyan
$gitBash = "$gitDir\bin\bash.exe"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& $gitBash "$scriptDir/windows-bootstrap-2.sh"

Write-Host "`n✅ Setup complete! Restart your terminal." -ForegroundColor Cyan