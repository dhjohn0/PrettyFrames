Add-Type -AssemblyName System.Drawing

$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $addonRoot 'Themes\Verdant\Sources'
$assetRoot = Join-Path $addonRoot 'Themes\Verdant\Assets'

function Get-AlphaBounds([System.Drawing.Bitmap] $Bitmap, [int] $Threshold = 8) {
    $minX = $Bitmap.Width; $minY = $Bitmap.Height; $maxX = -1; $maxY = -1
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
    $Bitmap.UnlockBits($data)
    $writer.Dispose(); $stream.Dispose()
}

function Export-Asset([string] $Name, [int] $Width, [int] $Height, [int] $Padding) {
    $inputPath = Join-Path $sourceRoot ($Name + '-Generation.png')
    $source = [System.Drawing.Bitmap]::FromFile($inputPath)
    $bounds = Get-AlphaBounds $source
    $availableWidth = $Width - 2 * $Padding
    $availableHeight = $Height - 2 * $Padding
    $scale = [Math]::Min($availableWidth / $bounds.Width, $availableHeight / $bounds.Height)
    $drawWidth = [Math]::Max(1, [int][Math]::Round($bounds.Width * $scale))
    $drawHeight = [Math]::Max(1, [int][Math]::Round($bounds.Height * $scale))
    $destination = [System.Drawing.Rectangle]::new(
        [int](($Width - $drawWidth) / 2),
        [int](($Height - $drawHeight) / 2),
        $drawWidth,
        $drawHeight
    )
    $canvas = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source, $destination, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose(); $source.Dispose()
    $canvas.Save((Join-Path $sourceRoot ($Name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Tga $canvas (Join-Path $assetRoot ($Name + '.tga'))
    $canvas.Dispose()
    Write-Output "Built $Name ($Width x $Height)"
}

Export-Asset 'ClassResourcePointFrame' 128 128 4
Export-Asset 'ClassResourceBarFrame' 1024 128 8
Export-Asset 'ClassResourceTotemFrame' 128 128 4
Export-Asset 'ComboPointActive' 128 128 6
Export-Asset 'ComboPointEmpty' 128 128 6
Export-Asset 'AmmoArrowheadActive' 128 128 6
Export-Asset 'AmmoArrowheadEmpty' 128 128 6
