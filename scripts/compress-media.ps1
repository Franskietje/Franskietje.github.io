param(
    [string]$VideoInputDir = "video",
    [string]$VideoOutputDir = "video/web",
    [string]$AudioInputDir = "audio",
    [string]$AudioOutputDir = "audio/web",
    [int]$MaxWidth = 1280,
    [int]$VideoCrf = 28,
    [string]$VideoPreset = "slow",
    [string]$AudioBitrate = "160k"
)

$ErrorActionPreference = "Stop"

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Error "ffmpeg is not installed or not in PATH. Install ffmpeg first, then rerun this script."
    exit 1
}

if (-not (Test-Path $VideoOutputDir)) {
    New-Item -ItemType Directory -Path $VideoOutputDir | Out-Null
}

if (-not (Test-Path $AudioOutputDir)) {
    New-Item -ItemType Directory -Path $AudioOutputDir | Out-Null
}

$videoExtensions = @("*.mov", "*.mp4", "*.m4v", "*.avi")
$audioExtensions = @("*.aif", "*.aiff", "*.wav")

$videoFiles = foreach ($ext in $videoExtensions) {
    Get-ChildItem -Path $VideoInputDir -Filter $ext -File -ErrorAction SilentlyContinue
}

$audioFiles = foreach ($ext in $audioExtensions) {
    Get-ChildItem -Path $AudioInputDir -Filter $ext -File -ErrorAction SilentlyContinue
}

if (-not $videoFiles -and -not $audioFiles) {
    Write-Host "No matching media files found to compress."
    exit 0
}

Write-Host "Starting compression..."

foreach ($file in $videoFiles) {
    $outName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + ".mp4"
    $outPath = Join-Path $VideoOutputDir $outName

    Write-Host "Video: $($file.FullName) -> $outPath"

    # Scale down only if wider than MaxWidth, keep aspect ratio, encode for web playback.
    & ffmpeg -y -i $file.FullName `
        -vf "scale='min($MaxWidth,iw)':-2" `
        -c:v libx264 -preset $VideoPreset -crf $VideoCrf `
        -pix_fmt yuv420p -movflags +faststart `
        -c:a aac -b:a $AudioBitrate `
        $outPath

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to compress video: $($file.Name)"
    }
}

foreach ($file in $audioFiles) {
    $outName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + ".mp3"
    $outPath = Join-Path $AudioOutputDir $outName

    Write-Host "Audio: $($file.FullName) -> $outPath"

    & ffmpeg -y -i $file.FullName -codec:a libmp3lame -b:a $AudioBitrate $outPath

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to compress audio: $($file.Name)"
    }
}

Write-Host "Compression complete."
Write-Host "Review outputs in $VideoOutputDir and $AudioOutputDir before committing."
