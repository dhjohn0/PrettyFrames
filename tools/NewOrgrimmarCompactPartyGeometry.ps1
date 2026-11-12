param(
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\Themes\Orgrimmar\Work\PartyFrame-Compact-Geometry.png')
)

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

$bitmap = [System.Drawing.Bitmap]::new(1536, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)
$iron = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 48, 43, 41))
$hide = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 125, 18, 24))
$bone = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 211, 187, 139), 18)
$clear = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)

$outer = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(16, 125), [System.Drawing.Point]::new(86, 34),
    [System.Drawing.Point]::new(360, 32), [System.Drawing.Point]::new(430, 82),
    [System.Drawing.Point]::new(1400, 82), [System.Drawing.Point]::new(1520, 178),
    [System.Drawing.Point]::new(1485, 430), [System.Drawing.Point]::new(405, 466),
    [System.Drawing.Point]::new(300, 492), [System.Drawing.Point]::new(48, 435)
)
$graphics.FillPolygon($iron, $outer)
$graphics.FillPolygon($hide, [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(430, 104), [System.Drawing.Point]::new(1320, 104),
    [System.Drawing.Point]::new(1360, 145), [System.Drawing.Point]::new(1320, 205),
    [System.Drawing.Point]::new(430, 205), [System.Drawing.Point]::new(395, 150)
))
$graphics.DrawEllipse($bone, 80, 82, 260, 300)

$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.FillEllipse($clear, 112, 112, 196, 240)
$graphics.FillRectangle($clear, 435, 235, 870, 80)
$graphics.FillRectangle($clear, 480, 350, 770, 56)
$graphics.FillEllipse($clear, 1364, 230, 105, 105)

$graphics.Dispose(); $iron.Dispose(); $hide.Dispose(); $bone.Dispose(); $clear.Dispose()
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
Write-Output $OutputPath
