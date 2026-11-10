# Builds the iOS app icon from a source image.
# Usage (PowerShell, from the repo root):  ./scripts/make-app-icon.ps1 -Source icon-source.png
#
# - Crops -CropPercent from every edge (default 7%) to remove a drawn border / dark corners,
#   because iOS applies its own rounded mask.
# - Scales to 1024x1024 and saves as an opaque PNG (iOS app icons must not have transparency).
# - Writes Resources/Assets.xcassets/AppIcon.appiconset (single-size icon, Xcode 14+).
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [double]$CropPercent = 7
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$catalog = Join-Path $root 'Resources/Assets.xcassets'
$iconSet = Join-Path $catalog 'AppIcon.appiconset'
New-Item -ItemType Directory -Force -Path $iconSet | Out-Null

$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
try {
    $side = [Math]::Min($src.Width, $src.Height)
    $crop = [int]($side * $CropPercent / 100)
    $x = [int](($src.Width - $side) / 2) + $crop
    $y = [int](($src.Height - $side) / 2) + $crop
    $size = $side - 2 * $crop

    $bmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Black)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, 1024, 1024), $x, $y, $size, $size, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $out = Join-Path $iconSet 'AppIcon-1024.png'
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
} finally {
    $src.Dispose()
}

Set-Content -Path (Join-Path $catalog 'Contents.json') -Encoding utf8 -Value @'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
'@
Set-Content -Path (Join-Path $iconSet 'Contents.json') -Encoding utf8 -Value @'
{
  "images" : [
    { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
'@
Write-Host "App icon written to $iconSet"
