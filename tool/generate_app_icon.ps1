# Generates windows/runner/resources/app_icon.ico from the title-bar logo
# (Material Icons.settings_input_antenna, AppColors.blue500).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$fontPath = 'D:\Program Files\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf'
if (-not (Test-Path $fontPath)) {
    throw "MaterialIcons-Regular.otf not found at $fontPath"
}

$iconChar = [char]0xe587
$logoColor = [System.Drawing.Color]::FromArgb(255, 59, 130, 246)
$pngPath = Join-Path $PSScriptRoot 'app_logo.png'
$icoPath = Join-Path $repoRoot 'windows\runner\resources\app_icon.ico'

function New-LogoBitmap {
    param([int]$Size)

    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    [void]$pfc.AddFontFile($fontPath)
    $family = $pfc.Families[0]
    $fontSize = [single]($Size * 0.78)

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $font = New-Object System.Drawing.Font($family, $fontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush($logoColor)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
    $graphics.DrawString($iconChar, $font, $brush, $rect, $format)

    $font.Dispose()
    $brush.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function Save-IconFile {
    param(
        [System.Drawing.Bitmap[]]$Images,
        [string]$Path
    )

    $ms = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($ms)
    $writer.Write([int16]0)
    $writer.Write([int16]1)
    $writer.Write([int16]$Images.Count)

    $offset = 6 + (16 * $Images.Count)
    $pngChunks = New-Object System.Collections.Generic.List[byte[]]

    foreach ($image in $Images) {
        $pngMs = New-Object System.IO.MemoryStream
        $image.Save($pngMs, [System.Drawing.Imaging.ImageFormat]::Png)
        $bytes = $pngMs.ToArray()
        $pngMs.Dispose()

        $widthByte = if ($image.Width -ge 256) { [byte]0 } else { [byte]$image.Width }
        $heightByte = if ($image.Height -ge 256) { [byte]0 } else { [byte]$image.Height }

        $writer.Write($widthByte)
        $writer.Write($heightByte)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([int16]0)
        $writer.Write([int16]32)
        $writer.Write([int32]$bytes.Length)
        $writer.Write([int32]$offset)
        $pngChunks.Add($bytes)
        $offset += $bytes.Length
    }

    foreach ($bytes in $pngChunks) {
        $writer.Write($bytes)
    }

    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $writer.Dispose()
    $ms.Dispose()
}

$master = New-LogoBitmap -Size 256

$icons = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
foreach ($size in @(16, 32, 48, 256)) {
    if ($size -eq 256) {
        [void]$icons.Add($master)
        continue
    }
    $scaled = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($scaled)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($master, 0, 0, $size, $size)
    $g.Dispose()
    [void]$icons.Add($scaled)
}

Save-IconFile -Images $icons.ToArray() -Path $icoPath

try {
    $master.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
} catch {
    Write-Warning "Could not update $pngPath (file may be in use)."
}

foreach ($image in $icons) {
    if ($image -ne $master) {
        $image.Dispose()
    }
}
$master.Dispose()

Write-Host "Wrote $pngPath"
Write-Host "Wrote $icoPath"
