param(
    [string] $OutputPath = ".\Themes\Orgrimmar\Work\PlayerFrame-WithPet-Geometry.png"
)

Add-Type -AssemblyName System.Drawing

$width = 1536
$height = 768
$bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$iron = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 38, 30, 27))
$hide = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 104, 25, 20))
$opening = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 5, 5, 5))
$edge = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 218, 119, 48), 8)

# Compact player body and lower pet dock. Black regions are required transparent openings.
$graphics.FillRectangle($iron, 45, 45, 1445, 485)
$graphics.FillRectangle($iron, 390, 515, 1100, 225)
$graphics.FillEllipse($iron, 55, 75, 410, 410)
$graphics.FillEllipse($opening, 105, 125, 310, 310)
$graphics.DrawEllipse($edge, 105, 125, 310, 310)

$graphics.FillRectangle($hide, 455, 75, 980, 125)
$graphics.FillRectangle($opening, 485, 235, 885, 92)
$graphics.DrawRectangle($edge, 485, 235, 885, 92)
$graphics.FillRectangle($opening, 535, 365, 785, 58)
$graphics.DrawRectangle($edge, 535, 365, 785, 58)

$graphics.FillEllipse($iron, 420, 535, 190, 190)
$graphics.FillEllipse($opening, 458, 573, 114, 114)
$graphics.DrawEllipse($edge, 458, 573, 114, 114)
$graphics.FillRectangle($hide, 600, 535, 800, 82)
$graphics.FillRectangle($opening, 635, 645, 720, 48)
$graphics.DrawRectangle($edge, 635, 645, 720, 48)

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) { New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null }
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$edge.Dispose()
$opening.Dispose()
$hide.Dispose()
$iron.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Output (Resolve-Path $OutputPath)
