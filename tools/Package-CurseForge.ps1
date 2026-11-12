[CmdletBinding()]
param(
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$addonName = "PrettyFrames"
$projectRoot = Split-Path -Parent $PSScriptRoot
$tocPath = Join-Path $projectRoot "$addonName.toc"

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Could not find $addonName.toc at $tocPath."
}

$tocLines = @(Get-Content -LiteralPath $tocPath)
$versionLine = $tocLines | Where-Object { $_ -match '^## Version:\s*(.+?)\s*$' } | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^## Version:\s*(.+?)\s*$') {
    throw "$addonName.toc must contain a non-empty '## Version:' field."
}

$version = $Matches[1]
if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "TOC version '$version' is not a supported semantic version (for example, 1.2.3 or 1.2.3-beta.1)."
}

$interfaceLine = $tocLines | Where-Object { $_ -match '^## Interface:\s*(\d+)\s*$' } | Select-Object -First 1
if (-not $interfaceLine) {
    throw "$addonName.toc must contain a numeric '## Interface:' field."
}

$tocFiles = @(
    $tocLines |
        Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' } |
        ForEach-Object { $_.Trim() }
)

if ($tocFiles.Count -eq 0) {
    throw "$addonName.toc does not declare any runtime files."
}

foreach ($relativePath in $tocFiles) {
    $sourcePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "TOC runtime file is missing: $relativePath"
    }
}

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
}

New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

$stagingRoot = Join-Path ([IO.Path]::GetTempPath()) ("PrettyFrames-package-" + [guid]::NewGuid().ToString("N"))
$stagedAddon = Join-Path $stagingRoot $addonName
$archivePath = Join-Path $resolvedOutput "$addonName-$version.zip"
$checksumPath = "$archivePath.sha256"

try {
    New-Item -ItemType Directory -Path $stagedAddon -Force | Out-Null

    Copy-Item -LiteralPath $tocPath -Destination $stagedAddon

    foreach ($relativePath in $tocFiles) {
        $sourcePath = Join-Path $projectRoot $relativePath
        $destinationPath = Join-Path $stagedAddon $relativePath
        $destinationParent = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
    }

    $assetDirectories = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "Themes") -Directory -Recurse | Where-Object { $_.Name -eq "Assets" })
    if ($assetDirectories.Count -eq 0) {
        throw "No runtime theme Assets directories were found."
    }

    foreach ($assetDirectory in $assetDirectories) {
        $assetFiles = @(Get-ChildItem -LiteralPath $assetDirectory.FullName -File -Recurse)
        foreach ($assetFile in $assetFiles) {
            if ($assetFile.Extension -ne ".tga") {
                throw "Unexpected non-TGA file in a runtime Assets directory: $($assetFile.FullName)"
            }

            $relativePath = [IO.Path]::GetRelativePath($projectRoot, $assetFile.FullName)
            $destinationPath = Join-Path $stagedAddon $relativePath
            $destinationParent = Split-Path -Parent $destinationPath
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
            Copy-Item -LiteralPath $assetFile.FullName -Destination $destinationPath
        }
    }

    foreach ($releaseDocument in @("README.md", "CHANGELOG.md", "LICENSE", "LICENSE.txt", "LICENSE.md")) {
        $documentPath = Join-Path $projectRoot $releaseDocument
        if (Test-Path -LiteralPath $documentPath -PathType Leaf) {
            Copy-Item -LiteralPath $documentPath -Destination $stagedAddon
        }
    }

    $forbiddenSegments = @("docs", "Sources", "Work", "tools", "dist")
    $stagedFiles = @(Get-ChildItem -LiteralPath $stagedAddon -File -Recurse)
    foreach ($stagedFile in $stagedFiles) {
        $relativePath = [IO.Path]::GetRelativePath($stagedAddon, $stagedFile.FullName)
        $segments = $relativePath -split '[\\/]'
        foreach ($segment in $forbiddenSegments) {
            if ($segments -contains $segment) {
                throw "Forbidden development path entered the package: $relativePath"
            }
        }
    }

    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    if (Test-Path -LiteralPath $checksumPath) {
        Remove-Item -LiteralPath $checksumPath -Force
    }

    Compress-Archive -LiteralPath $stagedAddon -DestinationPath $archivePath -CompressionLevel Optimal

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entries = @($archive.Entries | Where-Object { $_.Name })
        if ($entries.Count -ne $stagedFiles.Count) {
            throw "Archive verification failed: expected $($stagedFiles.Count) files, found $($entries.Count)."
        }

        foreach ($entry in $entries) {
            $normalizedName = $entry.FullName -replace '\\', '/'
            if (-not $normalizedName.StartsWith("$addonName/", [StringComparison]::Ordinal)) {
                throw "Archive entry is not inside the $addonName root folder: $normalizedName"
            }
        }

        if (-not ($entries.FullName -contains "$addonName/$addonName.toc")) {
            throw "Archive verification failed: $addonName/$addonName.toc is missing."
        }
    } finally {
        $archive.Dispose()
    }

    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath $checksumPath -Value "$hash  $addonName-$version.zip" -Encoding ascii

    $archiveInfo = Get-Item -LiteralPath $archivePath
    Write-Host "Created $($archiveInfo.FullName)"
    Write-Host "Version: $version"
    Write-Host "Files: $($stagedFiles.Count)"
    Write-Host "Size: $($archiveInfo.Length) bytes"
    Write-Host "SHA256: $hash"
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
