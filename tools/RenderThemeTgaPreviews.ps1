param(
    [Parameter(Mandatory = $true)][string] $ThemeName,
    [string] $OutputRoot = (Join-Path $PSScriptRoot '..\Themes')
)

Add-Type -AssemblyName System.Drawing

$themeRoot = Join-Path (Join-Path $PSScriptRoot '..\Themes') $ThemeName
$assetRoot = Join-Path $themeRoot 'Assets'
$previewRoot = Join-Path $OutputRoot ($ThemeName + '-Previews')
New-Item -ItemType Directory -Force -Path $previewRoot | Out-Null

foreach ($asset in Get-ChildItem -LiteralPath $assetRoot -Filter '*.tga' -File) {
    $bytes = [System.IO.File]::ReadAllBytes($asset.FullName)
    $width = $bytes[12] + 256 * $bytes[13]
    $height = $bytes[14] + 256 * $bytes[15]
    if ($bytes[2] -ne 2 -or $bytes[16] -ne 32) { throw "Unsupported TGA: $($asset.Name)" }
    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $offset = 18
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $b = $bytes[$offset]; $g = $bytes[$offset + 1]; $r = $bytes[$offset + 2]; $a = $bytes[$offset + 3]
            $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $r, $g, $b))
            $offset += 4
        }
    }
    $output = Join-Path $previewRoot ([System.IO.Path]::ChangeExtension($asset.Name, '.png'))
    $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

Write-Output $previewRoot
