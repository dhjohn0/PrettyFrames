param(
    [string] $ThemeRoot = (Join-Path $PSScriptRoot '..\Themes\Moonlight')
)

Add-Type -AssemblyName System.Drawing

$sourceRoot = Join-Path $ThemeRoot 'Sources'
$assetRoot = Join-Path $ThemeRoot 'Assets'
$verdantSources = Join-Path $PSScriptRoot '..\Themes\Verdant\Sources'
New-Item -ItemType Directory -Force $assetRoot | Out-Null

function New-Canvas([int] $Width, [int] $Height) {
    $canvas = [System.Drawing.Bitmap]::new(
        $Width,
        $Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
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
    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt $Threshold) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) {
        throw 'Source image has no visible pixels.'
    }
    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
}

function Draw-Image(
    [System.Drawing.Bitmap] $Canvas,
    [string] $Path,
    [System.Drawing.Rectangle] $Destination,
    [object] $SourceRectangle
) {
    $source = [System.Drawing.Bitmap]::FromFile($Path)
    if ($null -eq $SourceRectangle) {
        $SourceRectangle = [System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height)
    }
    $graphics = New-Graphics $Canvas
    $graphics.DrawImage($source, $Destination, $SourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    $source.Dispose()
}

function Draw-VisibleFit(
    [System.Drawing.Bitmap] $Canvas,
    [string] $Path,
    [System.Drawing.Rectangle] $Area,
    [int] $Padding = 0
) {
    $source = [System.Drawing.Bitmap]::FromFile($Path)
    $bounds = Get-AlphaBounds $source
    $availableWidth = [Math]::Max(1, $Area.Width - 2 * $Padding)
    $availableHeight = [Math]::Max(1, $Area.Height - 2 * $Padding)
    $scale = [Math]::Min($availableWidth / $bounds.Width, $availableHeight / $bounds.Height)
    $width = [Math]::Max(1, [Math]::Round($bounds.Width * $scale))
    $height = [Math]::Max(1, [Math]::Round($bounds.Height * $scale))
    $destination = [System.Drawing.Rectangle]::new(
        $Area.X + [Math]::Floor(($Area.Width - $width) / 2),
        $Area.Y + [Math]::Floor(($Area.Height - $height) / 2),
        $width,
        $height
    )
    $graphics = New-Graphics $Canvas
    $graphics.DrawImage($source, $destination, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    $source.Dispose()
}

function Apply-AlphaMask([System.Drawing.Bitmap] $Target, [System.Drawing.Bitmap] $Mask) {
    if ($Target.Width -ne $Mask.Width -or $Target.Height -ne $Mask.Height) {
        throw 'Alpha mask dimensions do not match the target.'
    }
    for ($y = 0; $y -lt $Target.Height; $y++) {
        for ($x = 0; $x -lt $Target.Width; $x++) {
            $color = $Target.GetPixel($x, $y)
            $alpha = $Mask.GetPixel($x, $y).A
            $Target.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $color.R, $color.G, $color.B))
        }
    }
}

function New-ReferenceMask(
    [string] $Path,
    [int] $Width,
    [int] $Height,
    [System.Drawing.Rectangle] $Destination
) {
    $mask = New-Canvas $Width $Height
    Draw-Image $mask $Path $Destination $null
    return $mask
}

function Write-Tga([System.Drawing.Bitmap] $Bitmap, [string] $Path) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $Bitmap.Width -band 0xff
    $header[13] = ($Bitmap.Width -shr 8) -band 0xff
    $header[14] = $Bitmap.Height -band 0xff
    $header[15] = ($Bitmap.Height -shr 8) -band 0xff
    $header[16] = 32
    $header[17] = 0x28
    $writer.Write($header)

    $rectangle = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $row = New-Object byte[] ($Bitmap.Width * 4)
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        $rowPointer = [IntPtr]::Add($data.Scan0, $y * $data.Stride)
        [System.Runtime.InteropServices.Marshal]::Copy($rowPointer, $row, 0, $row.Length)
        $writer.Write($row)
    }
    $Bitmap.UnlockBits($data)
    $writer.Dispose()
    $stream.Dispose()
}

function Export-Asset(
    [string] $Name,
    [int] $Width,
    [int] $Height,
    [scriptblock] $Draw,
    [scriptblock] $Mask
) {
    $canvas = New-Canvas $Width $Height
    & $Draw $canvas
    if ($null -ne $Mask) {
        $alphaMask = & $Mask
        Apply-AlphaMask $canvas $alphaMask
        $alphaMask.Dispose()
    }
    Write-Tga $canvas (Join-Path $assetRoot ($Name + '.tga'))
    $canvas.Dispose()
}

$unitArea = [System.Drawing.Rectangle]::new(0, 85, 1024, 341)
$playerArea = [System.Drawing.Rectangle]::new(0, 18, 1024, 475)

Export-Asset 'UnitFrame' 1024 512 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'UnitFrame.png') $unitArea $null
} {
    New-ReferenceMask (Join-Path $verdantSources 'UnitFrame.png') 1024 512 $unitArea
}
Export-Asset 'UnitFrame-OneBar' 1024 512 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'UnitFrame-OneBar.png') $unitArea $null
} $null
Export-Asset 'TargetOfTargetFrame' 1024 512 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'TargetOfTargetFrame.png') $unitArea $null
} {
    New-ReferenceMask (Join-Path $verdantSources 'TargetOfTargetFrame.png') 1024 512 $unitArea
}
Export-Asset 'TargetOfTargetFrame-OneBar' 1024 512 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'TargetOfTargetFrame-OneBar.png') $unitArea $null
} $null
Export-Asset 'PartyFrame' 1024 512 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'PartyFrame.png') $unitArea $null
} {
    New-ReferenceMask (Join-Path $verdantSources 'PartyFrame.png') 1024 512 $unitArea
}
Export-Asset 'PlayerFrame-WithPet' 1024 512 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'PlayerFrame-WithPet.png') $playerArea $null
} {
    New-ReferenceMask (Join-Path $verdantSources 'PlayerFrame-WithPet.png') 1024 512 $playerArea
}

Export-Asset 'PortraitFrame' 256 256 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'PortraitFrame.png') ([System.Drawing.Rectangle]::new(0, 0, 256, 256)) $null
} {
    New-ReferenceMask (Join-Path $verdantSources 'PortraitFrame.png') 256 256 ([System.Drawing.Rectangle]::new(0, 0, 256, 256))
}
Export-Asset 'IndicatorFrame' 128 128 {
    param($canvas) Draw-Image $canvas (Join-Path $sourceRoot 'IndicatorFrame.png') ([System.Drawing.Rectangle]::new(0, 0, 128, 128)) $null
} {
    New-ReferenceMask (Join-Path $verdantSources 'IndicatorFrame.png') 128 128 ([System.Drawing.Rectangle]::new(0, 0, 128, 128))
}

Export-Asset 'NameplateFrame' 1024 256 {
    param($canvas)
    Draw-VisibleFit $canvas (Join-Path $sourceRoot 'NameplateFrame.png') ([System.Drawing.Rectangle]::new(0, 0, 1024, 256)) 3
    # The native health fill reveals this area as the unit takes damage. Use
    # neutral black rather than the generated navy material so empty health is
    # visually stable and runtime colors remain unambiguous.
    for ($y = 158; $y -le 207; $y++) {
        for ($x = 190; $x -le 914; $x++) {
            $color = $canvas.GetPixel($x, $y)
            $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($color.A, 0, 0, 0))
        }
    }
} {
    $mask = [System.Drawing.Bitmap]::FromFile((Join-Path $verdantSources 'NameplateFrame.png'))
    # Keep the reference theme's nearly opaque dark health-slot backing. Native
    # nameplate health shrinks when damaged, so a transparent slot would expose
    # the 3D world instead of a stable black bar background.
    return $mask
}
Export-Asset 'RaidFrame' 1024 256 {
    param($canvas) Draw-VisibleFit $canvas (Join-Path $sourceRoot 'RaidFrame.png') ([System.Drawing.Rectangle]::new(0, 32, 1024, 192)) 0
} {
    $mask = [System.Drawing.Bitmap]::FromFile((Join-Path $verdantSources 'RaidFrame.png'))
    return $mask
}
Export-Asset 'PartyConnector' 128 256 {
    param($canvas) Draw-VisibleFit $canvas (Join-Path $sourceRoot 'PartyConnector.png') ([System.Drawing.Rectangle]::new(0, 0, 128, 256)) 0
} {
    $mask = [System.Drawing.Bitmap]::FromFile((Join-Path $verdantSources 'PartyConnector.png'))
    return $mask
}

Export-Asset 'StatusBar' 512 64 {
    param($canvas)
    $source = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot 'StatusBar.png'))
    $crop = [System.Drawing.Rectangle]::new(0, [Math]::Floor($source.Height * 0.29), $source.Width, [Math]::Floor($source.Height * 0.42))
    $graphics = New-Graphics $canvas
    $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, 512, 64), $crop, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    $source.Dispose()
    # StatusBars multiply this texture by live health/power colors. Enforce a
    # truly neutral source so red does not become purple and other runtime
    # colors are not biased by residual blue from generated artwork.
    for ($y = 0; $y -lt $canvas.Height; $y++) {
        for ($x = 0; $x -lt $canvas.Width; $x++) {
            $color = $canvas.GetPixel($x, $y)
            $gray = [Math]::Round(0.2126 * $color.R + 0.7152 * $color.G + 0.0722 * $color.B)
            $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($color.A, $gray, $gray, $gray))
        }
    }
} $null

Export-Asset 'CastBarEndCap' 128 128 {
    param($canvas)
    $destination = [System.Drawing.Rectangle]::new(0, 0, 128, 128)
    Draw-Image $canvas (Join-Path $sourceRoot 'CastBarEndCap.png') $destination $null
} $null
Export-Asset 'CastBarInterruptGlow' 1024 128 {
    param($canvas)
    $path = Join-Path $sourceRoot 'CastBarInterruptGlow.png'
    $source = [System.Drawing.Bitmap]::FromFile($path)
    $bounds = Get-AlphaBounds $source
    $source.Dispose()
    # This signal is an outer halo, not an internal rail. Stretch its useful
    # alpha across the complete 8:1 runtime canvas so the top/bottom aura and
    # cap blooms surround the entire ornament at every cast-bar size.
    Draw-Image $canvas $path ([System.Drawing.Rectangle]::new(0, 0, 1024, 128)) $bounds
} $null

Export-Asset 'RaidGroupHeader' 512 128 {
    param($canvas) Draw-VisibleFit $canvas (Join-Path $sourceRoot 'RaidGroupHeader.png') ([System.Drawing.Rectangle]::new(0, 0, 512, 128)) 3
} $null
Export-Asset 'RaidThreatGlow' 256 128 {
    param($canvas) Draw-VisibleFit $canvas (Join-Path $sourceRoot 'RaidThreatGlow.png') ([System.Drawing.Rectangle]::new(0, 0, 256, 128)) 0
} $null
Export-Asset 'RaidTargetClasp' 32 128 {
    param($canvas) Draw-VisibleFit $canvas (Join-Path $sourceRoot 'RaidTargetClasp.png') ([System.Drawing.Rectangle]::new(0, 0, 32, 128)) 1
} $null

foreach ($leaf in @('Maple', 'Golden', 'Oak', 'Aspen')) {
    $leafName = $leaf
    Export-Asset ('RaidLeaves-' + $leafName) 256 256 {
        param($canvas)
        Draw-VisibleFit $canvas (Join-Path $sourceRoot ('RaidLeaves-' + $leafName + '.png')) ([System.Drawing.Rectangle]::new(0, 0, 256, 256)) 16
    } $null
}

Export-Asset 'PlayerRestingIndicator' 512 256 {
    param($canvas) Draw-VisibleFit $canvas (Join-Path $sourceRoot 'PlayerRestingIndicator.png') ([System.Drawing.Rectangle]::new(0, 0, 512, 256)) 20
} $null

& (Join-Path $PSScriptRoot 'BuildClassResourceAssets.ps1') -ThemeName 'Moonlight'

Get-ChildItem $assetRoot -Filter '*.tga' | Sort-Object Name | Select-Object Name, Length
