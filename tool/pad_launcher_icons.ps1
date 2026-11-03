<#
Pads and rescales launcher icon foreground + monochrome assets to recommended adaptive icon safe zone.
- Creates a 1024x1024 transparent canvas
- Scales source art so its longest dimension = $TargetArtSize (default 720)
- Centers artwork and overwrites originals
Run from repo root:  powershell -ExecutionPolicy Bypass -File tool/pad_launcher_icons.ps1
#>

param(
  [int]$Canvas = 1024,
  [int]$TargetArtSize = 720,
  [string]$ForegroundPath = 'assets/branding/icon_foreground.png',
  [string]$MonochromePath = 'assets/branding/icon_monochrome.png'
)

function Pad-Icon {
  param([string]$Path)
  if (!(Test-Path $Path)) { Write-Host "Missing $Path" -ForegroundColor Red; return }
  Add-Type -AssemblyName System.Drawing
  $img = [System.Drawing.Image]::FromFile($Path)
  $scale = $TargetArtSize / [double]$img.Width
  $newW = [int]([double]$img.Width * $scale)
  $newH = [int]([double]$img.Height * $scale)
  $bmp = New-Object System.Drawing.Bitmap $Canvas, $Canvas, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::FromArgb(0,0,0,0))
  $g.CompositingQuality = 'HighQuality'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.SmoothingMode = 'HighQuality'
  $x = [int](($Canvas - $newW)/2)
  $y = [int](($Canvas - $newH)/2)
  $g.DrawImage($img, $x, $y, $newW, $newH)
  $g.Dispose(); $img.Dispose()
  # Overwrite original
  $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "Padded -> $Path (scale=$([Math]::Round($scale,3)))" -ForegroundColor Green
}

Pad-Icon -Path $ForegroundPath
Pad-Icon -Path $MonochromePath
Write-Host "Done. Now run: flutter pub run flutter_launcher_icons:main" -ForegroundColor Cyan
