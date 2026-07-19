# Download assets from exercises-dataset
# Run this script to fetch the 1324 exercise images and GIFs
# Prerequisites: PowerShell 5+, curl or wget
#
# Usage: .\download_assets.ps1

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/hasaneyldrm/exercises-dataset/archive/refs/heads/main.zip"
$ZipFile = "$PSScriptRoot\exercises-dataset.zip"
$ExtractDir = "$PSScriptRoot\exercises-dataset-temp"
$TargetImages = "$PSScriptRoot\assets\images"
$TargetVideos = "$PSScriptRoot\assets\videos"
$TargetData = "$PSScriptRoot\assets\data"

Write-Host "=== 开练 (KaiLian) 数据下载 ===" -ForegroundColor Cyan
Write-Host ""

# Create target directories
New-Item -ItemType Directory -Force -Path $TargetImages | Out-Null
New-Item -ItemType Directory -Force -Path $TargetVideos | Out-Null
New-Item -ItemType Directory -Force -Path $TargetData | Out-Null

Write-Host "[1/3] Downloading exercises-dataset (~500MB)..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipFile
Write-Host "  Done." -ForegroundColor Green

Write-Host "[2/3] Extracting..." -ForegroundColor Yellow
Expand-Archive -Path $ZipFile -DestinationPath $ExtractDir -Force
Write-Host "  Done." -ForegroundColor Green

Write-Host "[3/3] Copying assets..." -ForegroundColor Yellow

$SourceRoot = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
$SourceRootPath = $SourceRoot.FullName

# Copy images (180x180 thumbnails)
if (Test-Path "$SourceRootPath\images") {
    Copy-Item "$SourceRootPath\images\*" -Destination $TargetImages -Force
    $imgCount = (Get-ChildItem $TargetImages).Count
    Write-Host "  Images: $imgCount files" -ForegroundColor Green
}

# Copy videos (GIF animations)
if (Test-Path "$SourceRootPath\videos") {
    Copy-Item "$SourceRootPath\videos\*" -Destination $TargetVideos -Force
    $vidCount = (Get-ChildItem $TargetVideos).Count
    Write-Host "  Videos (GIF): $vidCount files" -ForegroundColor Green
}

# Copy exercises.json
$jsonSource = Get-ChildItem -Path $SourceRootPath -Recurse -Filter "exercises.json" | Select-Object -First 1
if ($jsonSource) {
    Copy-Item $jsonSource.FullName -Destination "$TargetData\exercises.json" -Force
    Write-Host "  exercises.json: copied" -ForegroundColor Green
}

# Cleanup
Remove-Item $ZipFile -Force
Remove-Item $ExtractDir -Recurse -Force
Write-Host "  Cleanup done." -ForegroundColor Green

Write-Host ""
Write-Host "=== 完成! 现在可以运行 flutter run 了 ===" -ForegroundColor Cyan
