param(
    [Parameter(Mandatory = $true)]
    [string] $SourcePng,

    [Parameter(Mandatory = $true)]
    [string] $OutputPng,

    [Parameter(Mandatory = $true)]
    [string] $OutputTga
)

Add-Type -AssemblyName System.Drawing

$canvasWidth = 1024
$canvasHeight = 256
$artTop = 32
$artHeight = 192
$alphaThreshold = 8

$source = [System.Drawing.Bitmap]::FromFile($SourcePng)
$minX = $source.Width
$minY = $source.Height
$maxX = -1
$maxY = -1

for ($y = 0; $y -lt $source.Height; $y++) {
    for ($x = 0; $x -lt $source.Width; $x++) {
        if ($source.GetPixel($x, $y).A -gt $alphaThreshold) {
            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -lt $minX -or $maxY -lt $minY) {
    $source.Dispose()
    throw "The source image has no visible pixels."
}

$sourceBounds = [System.Drawing.Rectangle]::new(
    $minX,
    $minY,
    $maxX - $minX + 1,
    $maxY - $minY + 1
)
$scale = [Math]::Min(
    $canvasWidth / $sourceBounds.Width,
    $artHeight / $sourceBounds.Height
)
$destinationWidth = [Math]::Max(1, [Math]::Round($sourceBounds.Width * $scale))
$destinationHeight = [Math]::Max(1, [Math]::Round($sourceBounds.Height * $scale))
$destinationX = [Math]::Floor(($canvasWidth - $destinationWidth) / 2)
$destinationY = $artTop + [Math]::Floor(($artHeight - $destinationHeight) / 2)
$destinationBounds = [System.Drawing.Rectangle]::new(
    $destinationX,
    $destinationY,
    $destinationWidth,
    $destinationHeight
)
$canvas = [System.Drawing.Bitmap]::new(
    $canvasWidth,
    $canvasHeight,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.Clear([System.Drawing.Color]::Transparent)
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.DrawImage($source, $destinationBounds, $sourceBounds, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.Dispose()
$source.Dispose()

$canvas.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)

$stream = [System.IO.File]::Open($OutputTga, [System.IO.FileMode]::Create)
$writer = New-Object System.IO.BinaryWriter($stream)
$header = New-Object byte[] 18
$header[2] = 2
$header[12] = $canvasWidth -band 0xff
$header[13] = ($canvasWidth -shr 8) -band 0xff
$header[14] = $canvasHeight -band 0xff
$header[15] = ($canvasHeight -shr 8) -band 0xff
$header[16] = 32
$header[17] = 0x28
$writer.Write($header)

$rectangle = New-Object System.Drawing.Rectangle(0, 0, $canvasWidth, $canvasHeight)
$data = $canvas.LockBits(
    $rectangle,
    [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$row = New-Object byte[] ($canvasWidth * 4)
for ($y = 0; $y -lt $canvasHeight; $y++) {
    $rowPointer = [IntPtr]::Add($data.Scan0, $y * $data.Stride)
    [System.Runtime.InteropServices.Marshal]::Copy($rowPointer, $row, 0, $row.Length)
    $writer.Write($row)
}
$canvas.UnlockBits($data)
$canvas.Dispose()
$writer.Dispose()
$stream.Dispose()
