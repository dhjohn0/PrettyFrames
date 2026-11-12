param(
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\Themes\Orgrimmar\Work\UnitFrame-Geometry.png')
)

Add-Type -AssemblyName System.Drawing

$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null

$bitmap = [System.Drawing.Bitmap]::new(1024, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$iron = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 62, 58, 56))
$hide = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 122, 18, 22))
$bone = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 214, 190, 139), 13)
$guide = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 235, 92, 49), 4)

# Original full-canvas composition. These shapes are a geometry worksheet, not final art.
$silhouette = [System.Drawing.Drawing2D.GraphicsPath]::new()
$silhouette.AddPolygon([System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(22, 118),
    [System.Drawing.Point]::new(72, 38),
    [System.Drawing.Point]::new(245, 18),
    [System.Drawing.Point]::new(326, 72),
    [System.Drawing.Point]::new(940, 72),
    [System.Drawing.Point]::new(1002, 126),
    [System.Drawing.Point]::new(978, 428),
    [System.Drawing.Point]::new(330, 446),
    [System.Drawing.Point]::new(248, 494),
    [System.Drawing.Point]::new(66, 466),
    [System.Drawing.Point]::new(18, 390)
))
$graphics.FillPath($iron, $silhouette)

# Oxblood banner and bar backplates establish the intended independent live regions.
$graphics.FillPolygon($hide, [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(330, 92), [System.Drawing.Point]::new(925, 92),
    [System.Drawing.Point]::new(958, 132), [System.Drawing.Point]::new(925, 194),
    [System.Drawing.Point]::new(330, 194), [System.Drawing.Point]::new(300, 140)
))
$graphics.DrawPolygon($bone, [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(74, 126), [System.Drawing.Point]::new(134, 54),
    [System.Drawing.Point]::new(246, 62), [System.Drawing.Point]::new(304, 138),
    [System.Drawing.Point]::new(282, 370), [System.Drawing.Point]::new(218, 446),
    [System.Drawing.Point]::new(112, 436), [System.Drawing.Point]::new(56, 364)
))

# Transparent portrait and bars. Magenta guides make their boundaries explicit to the art pass.
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$clear = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
$portrait = [System.Drawing.Drawing2D.GraphicsPath]::new()
$portrait.AddPolygon([System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(104, 136), [System.Drawing.Point]::new(150, 92),
    [System.Drawing.Point]::new(224, 98), [System.Drawing.Point]::new(268, 150),
    [System.Drawing.Point]::new(254, 340), [System.Drawing.Point]::new(208, 392),
    [System.Drawing.Point]::new(136, 386), [System.Drawing.Point]::new(92, 332)
))
$graphics.FillPath($clear, $portrait)
$graphics.FillRectangle($clear, 354, 226, 566, 68)
$graphics.FillRectangle($clear, 410, 326, 462, 46)
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
$graphics.DrawPath($guide, $portrait)
$graphics.DrawRectangle($guide, 354, 226, 566, 68)
$graphics.DrawRectangle($guide, 410, 326, 462, 46)

$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$portrait.Dispose()
$silhouette.Dispose()
$guide.Dispose()
$bone.Dispose()
$clear.Dispose()
$hide.Dispose()
$iron.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Output $OutputPath
