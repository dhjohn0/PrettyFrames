Add-Type -AssemblyName System.Drawing

$output = Join-Path $PSScriptRoot '..\Themes\Orgrimmar\Work\RaidFrame-Full-Geometry.png'
$bitmap = [System.Drawing.Bitmap]::new(1024, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

$outer = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(64, 92),
    [System.Drawing.Point]::new(84, 72),
    [System.Drawing.Point]::new(940, 72),
    [System.Drawing.Point]::new(960, 92),
    [System.Drawing.Point]::new(960, 420),
    [System.Drawing.Point]::new(940, 440),
    [System.Drawing.Point]::new(84, 440),
    [System.Drawing.Point]::new(64, 420)
)
$iron = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 44, 39, 37))
$hide = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 112, 35, 28))
$rail = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 25, 22, 21))
$bronze = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 139, 76, 34), 10)
$edge = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 17, 15, 14), 14)

$graphics.FillPolygon($iron, $outer)
$graphics.DrawPolygon($edge, $outer)
$graphics.FillRectangle($hide, 82, 92, 860, 136)
$graphics.DrawRectangle($bronze, 82, 92, 860, 136)
$graphics.FillRectangle($rail, 80, 238, 864, 172)
$graphics.DrawRectangle($bronze, 80, 238, 864, 172)

$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$transparent = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
$graphics.FillRectangle($transparent, 80, 248, 856, 152)

$transparent.Dispose()
$edge.Dispose()
$bronze.Dispose()
$rail.Dispose()
$hide.Dispose()
$iron.Dispose()
$graphics.Dispose()
$bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

Write-Output $output
