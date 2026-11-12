param(
    [Parameter(Mandatory = $true)]
    [string] $IntactSourcePng,

    [Parameter(Mandatory = $true)]
    [string] $EditedSourcePng,

    [Parameter(Mandatory = $true)]
    [string] $OutputPng
)

Add-Type -AssemblyName System.Drawing

$intact = [System.Drawing.Bitmap]::FromFile($IntactSourcePng)
$editedLoaded = [System.Drawing.Bitmap]::FromFile($EditedSourcePng)
$edited = New-Object System.Drawing.Bitmap($editedLoaded.Width, $editedLoaded.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$copyGraphics = [System.Drawing.Graphics]::FromImage($edited)
$copyGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$copyGraphics.DrawImageUnscaled($editedLoaded, 0, 0)
$copyGraphics.Dispose()
$editedLoaded.Dispose()

# Both generated revisions retain identical level-medallion geometry. Restore
# only pixels whose alpha changed in that local region: this repairs missing
# bronze and removes the edit artifact without replacing surrounding v3 art.
for ($y = 410; $y -le 610; $y++) {
    for ($x = 90; $x -le 310; $x++) {
        $intactPixel = $intact.GetPixel($x, $y)
        $editedPixel = $edited.GetPixel($x, $y)
        if ([Math]::Abs([int] $intactPixel.A - [int] $editedPixel.A) -gt 8) {
            $edited.SetPixel($x, $y, $intactPixel)
        }
    }
}

$intact.Dispose()
$edited.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)
$edited.Dispose()
