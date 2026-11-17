param(
    [Parameter(Mandatory = $true)][string] $SourcePng,
    [Parameter(Mandatory = $true)][string] $OutputPng,
    [Parameter(Mandatory = $true)][string] $OutputTga,
    [int[]] $Crop,
    [int] $AlphaThreshold = 8
)

Add-Type -AssemblyName System.Drawing

$source = [System.Drawing.Bitmap]::FromFile($SourcePng)
try {
    if ($Crop) {
        if ($Crop.Count -ne 4) { throw "Crop must be x,y,width,height." }
        $sourceRect = [System.Drawing.Rectangle]::new($Crop[0], $Crop[1], $Crop[2], $Crop[3])
    } else {
        $minX = $source.Width
        $minY = $source.Height
        $maxX = -1
        $maxY = -1
        for ($y = 0; $y -lt $source.Height; $y++) {
            for ($x = 0; $x -lt $source.Width; $x++) {
                if ($source.GetPixel($x, $y).A -gt $AlphaThreshold) {
                    $minX = [Math]::Min($minX, $x)
                    $minY = [Math]::Min($minY, $y)
                    $maxX = [Math]::Max($maxX, $x)
                    $maxY = [Math]::Max($maxY, $y)
                }
            }
        }
        if ($maxX -lt $minX -or $maxY -lt $minY) { throw "Source has no visible pixels." }
        $sourceRect = [System.Drawing.Rectangle]::new(
            $minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1
        )
    }

    $canvasSize = 128
    $canvas = [System.Drawing.Bitmap]::new(
        $canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

        if ($Crop) {
            $destination = [System.Drawing.Rectangle]::new(0, 0, $canvasSize, $canvasSize)
        } else {
            $scale = [Math]::Min(120.0 / $sourceRect.Width, 112.0 / $sourceRect.Height)
            $width = [Math]::Max(1, [Math]::Round($sourceRect.Width * $scale))
            $height = [Math]::Max(1, [Math]::Round($sourceRect.Height * $scale))
            $destination = [System.Drawing.Rectangle]::new(
                [Math]::Floor(($canvasSize - $width) / 2),
                [Math]::Floor(($canvasSize - $height) / 2),
                $width,
                $height
            )
        }
        $graphics.DrawImage(
            $source, $destination, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel
        )
    } finally {
        $graphics.Dispose()
    }

    $outputPngDirectory = Split-Path -Parent $OutputPng
    $outputTgaDirectory = Split-Path -Parent $OutputTga
    New-Item -ItemType Directory -Force -Path $outputPngDirectory | Out-Null
    New-Item -ItemType Directory -Force -Path $outputTgaDirectory | Out-Null
    $canvas.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)

    $stream = [System.IO.File]::Open($OutputTga, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $header = New-Object byte[] 18
        $header[2] = 2
        $header[12] = $canvasSize -band 0xff
        $header[13] = ($canvasSize -shr 8) -band 0xff
        $header[14] = $canvasSize -band 0xff
        $header[15] = ($canvasSize -shr 8) -band 0xff
        $header[16] = 32
        $header[17] = 0x28
        $writer.Write($header)

        $rectangle = [System.Drawing.Rectangle]::new(0, 0, $canvasSize, $canvasSize)
        $data = $canvas.LockBits(
            $rectangle,
            [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            $row = New-Object byte[] ($canvasSize * 4)
            for ($y = 0; $y -lt $canvasSize; $y++) {
                $rowPointer = [IntPtr]::Add($data.Scan0, $y * $data.Stride)
                [System.Runtime.InteropServices.Marshal]::Copy($rowPointer, $row, 0, $row.Length)
                $writer.Write($row)
            }
        } finally {
            $canvas.UnlockBits($data)
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
    $canvas.Dispose()
} finally {
    $source.Dispose()
}

Write-Output $OutputTga
