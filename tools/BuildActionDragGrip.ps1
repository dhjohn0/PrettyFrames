param(
    [string] $SourcePath = (Join-Path $PSScriptRoot '..\Themes\Shared\Sources\ActionDragGrip-Generation.png')
)

Add-Type -AssemblyName System.Drawing

$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $addonRoot 'Themes\Shared\Sources'
$assetRoot = Join-Path $addonRoot 'Themes\Shared\Assets'
$outputPng = Join-Path $sourceRoot 'ActionDragGrip.png'
$outputTga = Join-Path $assetRoot 'ActionDragGrip.tga'
$size = 64
$padding = 4

function Get-AlphaBounds([System.Drawing.Bitmap] $Bitmap, [int] $Threshold = 8) {
    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt $Threshold) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) { throw 'Source contains no visible pixels.' }
    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
}

function Write-Tga([System.Drawing.Bitmap] $Bitmap, [string] $Path) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
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
        try {
            $row = New-Object byte[] ($Bitmap.Width * 4)
            for ($y = 0; $y -lt $Bitmap.Height; $y++) {
                [System.Runtime.InteropServices.Marshal]::Copy(
                    [IntPtr]::Add($data.Scan0, $y * $data.Stride), $row, 0, $row.Length
                )
                $writer.Write($row)
            }
        } finally {
            $Bitmap.UnlockBits($data)
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Generated source does not exist: $SourcePath"
}
New-Item -ItemType Directory -Force -Path $sourceRoot, $assetRoot | Out-Null

$source = [System.Drawing.Bitmap]::FromFile([System.IO.Path]::GetFullPath($SourcePath))
$canvas = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
    $bounds = Get-AlphaBounds $source
    $available = $size - 2 * $padding
    $scale = [Math]::Min($available / $bounds.Width, $available / $bounds.Height)
    $width = [Math]::Max(1, [Math]::Round($bounds.Width * $scale))
    $height = [Math]::Max(1, [Math]::Round($bounds.Height * $scale))
    $destination = [System.Drawing.Rectangle]::new(
        [Math]::Floor(($size - $width) / 2),
        [Math]::Floor(($size - $height) / 2),
        $width,
        $height
    )

    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($source, $destination, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
        $graphics.Dispose()
    }

    $canvas.Save($outputPng, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Tga $canvas $outputTga
} finally {
    $canvas.Dispose()
    $source.Dispose()
}

Write-Output "Built $outputTga"
