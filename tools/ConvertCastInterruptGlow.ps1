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
$canvasHeight = 128
$source = [System.Drawing.Bitmap]::FromFile($SourcePng)
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

# Keep only the two clean generated highlight bands. The noisy material that
# image generation placed in the middle is deliberately excluded.
$topSource = [System.Drawing.Rectangle]::new(0, 288, $source.Width, 48)
$bottomSource = [System.Drawing.Rectangle]::new(0, 384, $source.Width, 48)
$topDestination = [System.Drawing.Rectangle]::new(0, 12, $canvasWidth, 42)
$bottomDestination = [System.Drawing.Rectangle]::new(0, 74, $canvasWidth, 42)
$graphics.DrawImage($source, $topDestination, $topSource, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.DrawImage($source, $bottomDestination, $bottomSource, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.Dispose()
$source.Dispose()

$canvas.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)

$stream = [System.IO.File]::Open($OutputTga, [System.IO.FileMode]::Create)
$writer = [System.IO.BinaryWriter]::new($stream)
$header = New-Object byte[] 18
$header[2] = 2
$header[12] = $canvasWidth -band 0xff
$header[13] = ($canvasWidth -shr 8) -band 0xff
$header[14] = $canvasHeight -band 0xff
$header[15] = ($canvasHeight -shr 8) -band 0xff
$header[16] = 32
$header[17] = 0x28
$writer.Write($header)

$rectangle = [System.Drawing.Rectangle]::new(0, 0, $canvasWidth, $canvasHeight)
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
