param(
    [string] $ThemeRoot = (Join-Path $PSScriptRoot '..\Themes\Orgrimmar')
)

Add-Type -AssemblyName System.Drawing

$sourceRoot = Join-Path $ThemeRoot 'Sources'
$assetRoot = Join-Path $ThemeRoot 'Assets'
New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null

function New-Canvas([int] $Width, [int] $Height) {
    $canvas = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.Dispose()
    return $canvas
}

function New-Graphics([System.Drawing.Bitmap] $Canvas) {
    $graphics = [System.Drawing.Graphics]::FromImage($Canvas)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    return $graphics
}

function Get-AlphaBounds([System.Drawing.Bitmap] $Bitmap, [int] $Threshold = 8) {
    $minX = $Bitmap.Width; $minY = $Bitmap.Height; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt $Threshold) {
                if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) { throw 'Source contains no visible pixels.' }
    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
}

function Draw-Source(
    [System.Drawing.Bitmap] $Canvas,
    [string] $Name,
    [ValidateSet('Stretch', 'Fit')][string] $Mode = 'Stretch',
    [int] $Padding = 0,
    [object] $SourceRectangle = $null
) {
    $source = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot ($Name + '.png')))
    if ($null -eq $SourceRectangle) {
        $SourceRectangle = if ($Mode -eq 'Fit') { Get-AlphaBounds $source }
            else { [System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height) }
    }
    $destination = [System.Drawing.Rectangle]::new(0, 0, $Canvas.Width, $Canvas.Height)
    if ($Mode -eq 'Fit') {
        $availableWidth = [Math]::Max(1, $Canvas.Width - 2 * $Padding)
        $availableHeight = [Math]::Max(1, $Canvas.Height - 2 * $Padding)
        $scale = [Math]::Min($availableWidth / $SourceRectangle.Width, $availableHeight / $SourceRectangle.Height)
        $width = [Math]::Max(1, [Math]::Round($SourceRectangle.Width * $scale))
        $height = [Math]::Max(1, [Math]::Round($SourceRectangle.Height * $scale))
        $destination = [System.Drawing.Rectangle]::new(
            [Math]::Floor(($Canvas.Width - $width) / 2),
            [Math]::Floor(($Canvas.Height - $height) / 2), $width, $height
        )
    }
    $graphics = New-Graphics $Canvas
    $graphics.DrawImage($source, $destination, $SourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose(); $source.Dispose()
}

function Clear-Rectangle([System.Drawing.Bitmap] $Bitmap, [int] $X, [int] $Y, [int] $Width, [int] $Height) {
    $graphics = New-Graphics $Bitmap
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
    $graphics.FillRectangle($brush, $X, $Y, $Width, $Height)
    $brush.Dispose(); $graphics.Dispose()
}

function Clear-Ellipse([System.Drawing.Bitmap] $Bitmap, [int] $X, [int] $Y, [int] $Width, [int] $Height) {
    $graphics = New-Graphics $Bitmap
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
    $graphics.FillEllipse($brush, $X, $Y, $Width, $Height)
    $brush.Dispose(); $graphics.Dispose()
}

function Clear-UnitPortrait([System.Drawing.Bitmap] $Bitmap) {
    $graphics = New-Graphics $Bitmap
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddPolygon([System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(104, 136), [System.Drawing.Point]::new(150, 92),
        [System.Drawing.Point]::new(224, 98), [System.Drawing.Point]::new(268, 150),
        [System.Drawing.Point]::new(254, 340), [System.Drawing.Point]::new(208, 392),
        [System.Drawing.Point]::new(136, 386), [System.Drawing.Point]::new(92, 332)
    ))
    $graphics.FillPath($brush, $path)
    $path.Dispose(); $brush.Dispose(); $graphics.Dispose()
}

function Write-Tga([System.Drawing.Bitmap] $Bitmap, [string] $Path) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $Bitmap.Width -band 0xff; $header[13] = ($Bitmap.Width -shr 8) -band 0xff
    $header[14] = $Bitmap.Height -band 0xff; $header[15] = ($Bitmap.Height -shr 8) -band 0xff
    $header[16] = 32; $header[17] = 0x28
    $writer.Write($header)
    $rect = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $row = New-Object byte[] ($Bitmap.Width * 4)
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        [System.Runtime.InteropServices.Marshal]::Copy([IntPtr]::Add($data.Scan0, $y * $data.Stride), $row, 0, $row.Length)
        $writer.Write($row)
    }
    $Bitmap.UnlockBits($data); $writer.Dispose(); $stream.Dispose()
}

function Export-Canvas([string] $Name, [System.Drawing.Bitmap] $Canvas) {
    Write-Tga $Canvas (Join-Path $assetRoot ($Name + '.tga'))
    $Canvas.Dispose()
}

function Export-Source([string] $Name, [int] $Width, [int] $Height, [string] $Mode = 'Stretch', [int] $Padding = 0) {
    $canvas = New-Canvas $Width $Height
    Draw-Source $canvas $Name $Mode $Padding
    Export-Canvas $Name $canvas
}

# Standalone Player and ornate unit frames use the +Pet-derived generated
# asset. Keep its original horizontal scale and crop only the now-empty Pet
# canvas below the completed Player edge. The 2.5:1 crop maps uniformly to the
# final 500x200 frame, preserving the +Pet Player geometry without stretching.
$generatedUnitSource = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot 'UnitFrame-BottomGeneration.png'))
$generatedUnitCropHeight = [Math]::Min(
    $generatedUnitSource.Height,
    [Math]::Round($generatedUnitSource.Width / 2.5)
)
$generatedUnitBounds = [System.Drawing.Rectangle]::new(
    0, 0, $generatedUnitSource.Width, $generatedUnitCropHeight
)
$generatedUnitSource.Dispose()
foreach ($name in @('UnitFrame', 'UnitFrame-OneBar')) {
    $canvas = New-Canvas 1024 512
    $sourceName = if ($name -eq 'UnitFrame') {
        'UnitFrame-BottomGeneration'
    } else {
        'UnitFrame-OneBar-Generation'
    }
    Draw-Source $canvas $sourceName 'Stretch' 0 $generatedUnitBounds
    # These authoring-space dimensions compensate for the 1024x512 texture
    # being displayed at 500x200, so the portrait resolves as a circle.
    Clear-Ellipse $canvas 74 128 184 230
    Clear-Rectangle $canvas 320 224 594 50
    if ($name -eq 'UnitFrame') {
        Clear-Rectangle $canvas 346 320 545 40
    }
    $canvas.Save((Join-Path $sourceRoot ($name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    Export-Canvas $name $canvas
}

# Target-of-Target has a dedicated, quieter frame pair derived from the Party
# frame. Keep the same 3:1 sampled band so the proven Party portrait ring stays
# circular rather than being stretched by the older 2.5:1 full-canvas mapping.
$targetOfTargetVariants = @(
    @{ Name = 'TargetOfTargetFrame'; Source = 'TargetOfTargetFrame-Generation'; HasPower = $true },
    @{ Name = 'TargetOfTargetFrame-OneBar'; Source = 'TargetOfTargetFrame-OneBar-Generation'; HasPower = $false }
)
foreach ($variant in $targetOfTargetVariants) {
    $canvas = New-Canvas 1024 512
    $source = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot ($variant.Source + '.png')))
    $graphics = New-Graphics $canvas
    $graphics.DrawImage(
        $source,
        [System.Drawing.Rectangle]::new(0, 85, 1024, 342),
        [System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height),
        [System.Drawing.GraphicsUnit]::Pixel
    )
    $graphics.Dispose(); $source.Dispose()
    Clear-Ellipse $canvas 70 160 156 155
    Clear-Rectangle $canvas 280 237 590 59
    if ($variant.HasPower) {
        Clear-Rectangle $canvas 302 309 528 37
    }
    $canvas.Save((Join-Path $sourceRoot ($variant.Name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    Export-Canvas $variant.Name $canvas
}

$player = New-Canvas 1024 512; Draw-Source $player 'PlayerFrame-WithPet'
Clear-Ellipse $player 72 99 199 187
Clear-Rectangle $player 320 179 594 40
Clear-Rectangle $player 348 257 534 27
Clear-Ellipse $player 294 380 81 74
Clear-Rectangle $player 442 445 426 21
Export-Canvas 'PlayerFrame-WithPet' $player

$party = New-Canvas 1024 512
$partySource = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot 'PartyFrame.png'))
$partyGraphics = New-Graphics $party
$partyGraphics.DrawImage(
    $partySource,
    [System.Drawing.Rectangle]::new(0, 85, 1024, 342),
    [System.Drawing.Rectangle]::new(0, 0, $partySource.Width, $partySource.Height),
    [System.Drawing.GraphicsUnit]::Pixel
)
$partyGraphics.Dispose(); $partySource.Dispose()
Clear-Ellipse $party 70 160 156 155
Clear-Rectangle $party 280 237 590 59
Clear-Rectangle $party 302 309 528 37
Clear-Ellipse $party 892 229 65 65
Export-Canvas 'PartyFrame' $party

# Portraits use a plain, dark, subtly mottled backing. Its alpha silhouette is
# taller than the circular live model so the 3D world never leaks through the
# shield opening around the model.
$portraitBackground = New-Canvas 256 256
$backgroundGraphics = New-Graphics $portraitBackground
$backgroundBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 24, 20, 19))
$backgroundGraphics.FillPolygon($backgroundBrush, [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(62, 6), [System.Drawing.Point]::new(194, 6),
    [System.Drawing.Point]::new(242, 52), [System.Drawing.Point]::new(228, 214),
    [System.Drawing.Point]::new(190, 250), [System.Drawing.Point]::new(66, 250),
    [System.Drawing.Point]::new(28, 214), [System.Drawing.Point]::new(14, 52)
))
$backgroundBrush.Dispose(); $backgroundGraphics.Dispose()
for ($y = 0; $y -lt 256; $y++) {
    for ($x = 0; $x -lt 256; $x++) {
        $color = $portraitBackground.GetPixel($x, $y)
        if ($color.A -gt 0) {
            [long] $hash = ([long] $x * 374761393) + ([long] $y * 668265263)
            $hash = ($hash -bxor ($hash -shr 13)) -band 0x7fffffff
            $grain = ($hash % 7) - 3
            $dx = ($x - 128) / 128.0; $dy = ($y - 128) / 128.0
            $vignette = [Math]::Min(5, [Math]::Floor(4 * [Math]::Sqrt($dx * $dx + $dy * $dy)))
            $shade = [Math]::Max(11, [Math]::Min(29, 23 + $grain - $vignette))
            $portraitBackground.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $shade, [Math]::Max(8, $shade - 4), [Math]::Max(7, $shade - 5)))
        }
    }
}
$portraitBackground.Save((Join-Path $sourceRoot 'PortraitBackground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
Export-Canvas 'PortraitBackground' $portraitBackground

# The unified Player/Pet composition has round portrait wells, so it receives
# the same unornamented material in a true circular alpha silhouette.
$roundBackground = New-Canvas 256 256
$roundGraphics = New-Graphics $roundBackground
$roundBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 24, 20, 19))
$roundGraphics.FillEllipse($roundBrush, 8, 8, 240, 240)
$roundBrush.Dispose(); $roundGraphics.Dispose()
for ($y = 0; $y -lt 256; $y++) {
    for ($x = 0; $x -lt 256; $x++) {
        $color = $roundBackground.GetPixel($x, $y)
        if ($color.A -gt 0) {
            [long] $hash = ([long] $x * 374761393) + ([long] $y * 668265263)
            $hash = ($hash -bxor ($hash -shr 13)) -band 0x7fffffff
            $grain = ($hash % 7) - 3
            $dx = ($x - 128) / 128.0; $dy = ($y - 128) / 128.0
            $vignette = [Math]::Min(5, [Math]::Floor(4 * [Math]::Sqrt($dx * $dx + $dy * $dy)))
            $shade = [Math]::Max(11, [Math]::Min(29, 23 + $grain - $vignette))
            $roundBackground.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $shade, [Math]::Max(8, $shade - 4), [Math]::Max(7, $shade - 5)))
        }
    }
}
$roundBackground.Save((Join-Path $sourceRoot 'PortraitBackgroundRound.png'), [System.Drawing.Imaging.ImageFormat]::Png)
Export-Canvas 'PortraitBackgroundRound' $roundBackground

$portrait = New-Canvas 256 256; Draw-Source $portrait 'PortraitFrame'
Clear-Ellipse $portrait 54 48 148 160
Export-Canvas 'PortraitFrame' $portrait

$indicator = New-Canvas 128 128; Draw-Source $indicator 'IndicatorFrame'
Clear-Ellipse $indicator 36 34 56 60
Export-Canvas 'IndicatorFrame' $indicator

Export-Source 'CastBarFrame' 1024 128 'Fit' 0
$castGlow = New-Canvas 1024 128; Draw-Source $castGlow 'CastBarInterruptGlow' 'Fit' 0
Clear-Rectangle $castGlow 90 45 844 38
Export-Canvas 'CastBarInterruptGlow' $castGlow
Export-Source 'PartyConnector' 128 256 'Fit' 1
Export-Source 'RaidGroupHeader' 512 128 'Fit' 2
Export-Source 'RaidThreatGlow' 256 128 'Fit' 0
Export-Source 'RaidTargetClasp' 32 128 'Fit' 1
Export-Source 'PlayerRestingIndicator' 512 256 'Fit' 8

$raid = New-Canvas 1024 256; Draw-Source $raid 'RaidFrame-FullGeneration' 'Fit' 0
# The complete frame is sampled from x=197..827 and displayed at 112x46.
# Re-clear the live health region at its exact runtime coordinates.
Clear-Rectangle $raid 208 122 603 107
$raid.Save((Join-Path $sourceRoot 'RaidFrame.png'), [System.Drawing.Imaging.ImageFormat]::Png)
Export-Canvas 'RaidFrame' $raid

$nameplate = New-Canvas 1024 256; Draw-Source $nameplate 'NameplateFrame' 'Fit' 2
$graphics = New-Graphics $nameplate
$black = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(250, 0, 0, 0))
$graphics.FillRectangle($black, 150, 150, 730, 48)
$black.Dispose(); $graphics.Dispose()
Export-Canvas 'NameplateFrame' $nameplate

foreach ($accent in @('RaidAccent-Tusk', 'RaidAccent-Axe', 'RaidAccent-Bones', 'RaidAccent-Plate')) {
    Export-Source $accent 256 256 'Fit' 10
}

$status = New-Canvas 512 64
$statusSource = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot 'StatusBar.png'))
$bandTop = [Math]::Floor($statusSource.Height * 0.23)
$bandHeight = [Math]::Max(1, [Math]::Floor($statusSource.Height * 0.34))
$statusGraphics = New-Graphics $status
$statusGraphics.DrawImage($statusSource, [System.Drawing.Rectangle]::new(0, 0, 512, 64), [System.Drawing.Rectangle]::new(0, $bandTop, $statusSource.Width, $bandHeight), [System.Drawing.GraphicsUnit]::Pixel)
$statusGraphics.Dispose(); $statusSource.Dispose()
for ($y = 0; $y -lt 64; $y++) {
    for ($x = 0; $x -lt 512; $x++) {
        $color = $status.GetPixel($x, $y)
        $gray = [Math]::Round(0.2126 * $color.R + 0.7152 * $color.G + 0.0722 * $color.B)
        $status.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $gray, $gray, $gray))
    }
}
Export-Canvas 'StatusBar' $status

& (Join-Path $PSScriptRoot 'BuildClassResourceAssets.ps1') -ThemeName 'Orgrimmar'

Get-ChildItem -LiteralPath $assetRoot -Filter '*.tga' | Sort-Object Name | Select-Object Name, Length
