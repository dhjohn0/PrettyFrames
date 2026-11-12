param(
    [Parameter(Mandatory = $true)]
    [string] $SourcePng,

    [Parameter(Mandatory = $true)]
    [string] $OutputPng,

    [switch] $PreserveClassArea,

    [switch] $PreserveLevelArea
)

Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath {
    param(
        [float] $X,
        [float] $Y,
        [float] $Width,
        [float] $Height,
        [float] $Radius
    )

    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$loaded = [System.Drawing.Bitmap]::FromFile($SourcePng)
$image = New-Object System.Drawing.Bitmap($loaded.Width, $loaded.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$copyGraphics = [System.Drawing.Graphics]::FromImage($image)
$copyGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$copyGraphics.DrawImageUnscaled($loaded, 0, 0)
$copyGraphics.Dispose()
$loaded.Dispose()

$graphics = [System.Drawing.Graphics]::FromImage($image)
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$transparent = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Transparent)

$healthPath = New-RoundedRectanglePath -X 590 -Y 322 -Width 1175 -Height 88 -Radius 42
$powerPath = New-RoundedRectanglePath -X 580 -Y 450 -Width 1180 -Height 82 -Radius 35
$graphics.FillPath($transparent, $healthPath)
$graphics.FillPath($transparent, $powerPath)
$graphics.FillEllipse($transparent, 195, 225, 290, 270)
if (-not $PreserveLevelArea) {
    $graphics.FillEllipse($transparent, 160, 460, 75, 75)
}
if (-not $PreserveClassArea) {
    $graphics.FillEllipse($transparent, 1505, 166, 90, 90)
}
$graphics.FillEllipse($transparent, 1857, 303, 160, 160)

$healthPath.Dispose()
$powerPath.Dispose()
$transparent.Dispose()
$graphics.Dispose()
$image.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)
$image.Dispose()
