param(
    [Parameter(Mandatory = $true)]
    [string] $SourcePng,

    [Parameter(Mandatory = $true)]
    [string] $OutputTga
)

Add-Type -AssemblyName System.Drawing

$canvasWidth = 1024
$canvasHeight = 512
$artTop = 18
$artHeight = 475

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
$graphics.DrawImage($source, 0, $artTop, $canvasWidth, $artHeight)
$graphics.Dispose()
$source.Dispose()

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

Write-Output "Built PlayerFrame-WithPet ($canvasWidth x $canvasHeight)"
