param(
    [string] $SourcePath = (Join-Path $PSScriptRoot '..\Themes\Shared\Sources\PortraitThreatGlow-Generation.png')
)

Add-Type -AssemblyName System.Drawing

$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $addonRoot 'Themes\Shared\Sources'
$assetRoot = Join-Path $addonRoot 'Themes\Shared\Assets'
$outputPng = Join-Path $sourceRoot 'PortraitThreatGlow.png'
$outputTga = Join-Path $assetRoot 'PortraitThreatGlow.tga'
$size = 256

function Write-Tga([System.Drawing.Bitmap] $Bitmap, [string] $Path) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $header = New-Object byte[] 18
        $header[2] = 2
        $header[12] = $Bitmap.Width -band 0xff
        $header[13] = ($Bitmap.Width -shr 8) -band 0xff
        $header[14] = $Bitmap.Height -band 0xff
        $header[15] = ($Bitmap.Height -shr 8) -band 0xff
        $header[16] = 32
        $header[17] = 0x28
        $writer.Write($header)

        $rectangle = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
        $data = $Bitmap.LockBits(
            $rectangle,
            [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            $row = New-Object byte[] ($Bitmap.Width * 4)
            for ($y = 0; $y -lt $Bitmap.Height; $y++) {
                [System.Runtime.InteropServices.Marshal]::Copy(
                    [IntPtr]::Add($data.Scan0, $y * $data.Stride), $row, 0, $row.Length
                )
                $writer.Write($row)
            }
        } finally {
            $Bitmap.UnlockBits($data)
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Generated source does not exist: $SourcePath"
}
New-Item -ItemType Directory -Force -Path $sourceRoot, $assetRoot | Out-Null

$source = [System.Drawing.Bitmap]::FromFile([System.IO.Path]::GetFullPath($SourcePath))
$canvas = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
    # Image generation establishes the visual profile. Average it around each
    # radius so the runtime primitive is perfectly circular and stays clean at
    # the 60-100 pixel sizes used by unit-frame portraits.
    $sourceCenterX = ($source.Width - 1) / 2.0
    $sourceCenterY = ($source.Height - 1) / 2.0
    $sourceRadius = [Math]::Min($source.Width, $source.Height) / 2.0
    $outputRadius = $size / 2.0
    $radialAlpha = New-Object double[] ([int]$outputRadius + 1)

    for ($radius = 0; $radius -le $outputRadius; $radius++) {
        $sampleRadius = ($radius / $outputRadius) * $sourceRadius
        $sum = 0.0
        $samples = 720
        for ($sample = 0; $sample -lt $samples; $sample++) {
            $angle = (2.0 * [Math]::PI * $sample) / $samples
            $x = [Math]::Max(0, [Math]::Min($source.Width - 1,
                [int][Math]::Round($sourceCenterX + [Math]::Cos($angle) * $sampleRadius)))
            $y = [Math]::Max(0, [Math]::Min($source.Height - 1,
                [int][Math]::Round($sourceCenterY + [Math]::Sin($angle) * $sampleRadius)))
            $sum += $source.GetPixel($x, $y).A
        }
        $average = $sum / $samples / 255.0
        $radialAlpha[$radius] = [Math]::Min(255, 255 * 1.10 * [Math]::Pow($average, 0.72))
    }

    # A small radial blur removes quantization without softening the inward edge.
    $smoothedAlpha = New-Object double[] $radialAlpha.Length
    for ($radius = 0; $radius -lt $radialAlpha.Length; $radius++) {
        $sum = 0.0
        $weight = 0.0
        for ($offset = -2; $offset -le 2; $offset++) {
            $sampleRadius = $radius + $offset
            if ($sampleRadius -ge 0 -and $sampleRadius -lt $radialAlpha.Length) {
                $sampleWeight = 3 - [Math]::Abs($offset)
                $sum += $radialAlpha[$sampleRadius] * $sampleWeight
                $weight += $sampleWeight
            }
        }
        $smoothedAlpha[$radius] = $sum / $weight
    }

    # Carry a restrained portion of the hot rim farther toward the center.
    # This illuminates the portrait instead of reading as a second inner ring;
    # the center still reaches zero alpha so faces remain legible.
    $peakRadius = 0
    for ($radius = 1; $radius -lt $smoothedAlpha.Length; $radius++) {
        if ($smoothedAlpha[$radius] -gt $smoothedAlpha[$peakRadius]) {
            $peakRadius = $radius
        }
    }
    if ($peakRadius -gt 0) {
        $peakAlpha = $smoothedAlpha[$peakRadius]
        for ($radius = 0; $radius -lt $peakRadius; $radius++) {
            $inwardTail = $peakAlpha * 0.70 * [Math]::Pow($radius / $peakRadius, 2.2)
            $smoothedAlpha[$radius] = [Math]::Max($smoothedAlpha[$radius], $inwardTail)
        }
    }

    $center = ($size - 1) / 2.0
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            $distance = [Math]::Sqrt([Math]::Pow($x - $center, 2) + [Math]::Pow($y - $center, 2))
            if ($distance -ge $outputRadius) {
                $alpha = 0
            } else {
                $lower = [int][Math]::Floor($distance)
                $upper = [Math]::Min($lower + 1, $smoothedAlpha.Length - 1)
                $fraction = $distance - $lower
                $alpha = [int][Math]::Round(
                    $smoothedAlpha[$lower] * (1.0 - $fraction) + $smoothedAlpha[$upper] * $fraction
                )
            }
            $canvas.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, 255, 255, 255))
        }
    }

    $canvas.Save($outputPng, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Tga $canvas $outputTga
} finally {
    $canvas.Dispose()
    $source.Dispose()
}

Write-Output "Built shared PortraitThreatGlow (256 x 256)."
