param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string] $ThemeName
)

$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$themeRoot = [System.IO.Path]::GetFullPath((Join-Path $addonRoot (Join-Path 'Themes' $ThemeName)))
$themesRoot = [System.IO.Path]::GetFullPath((Join-Path $addonRoot 'Themes'))

if (-not $themeRoot.StartsWith($themesRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Resolved theme path is outside the Themes directory.'
}

$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Failure([string] $Message) { $failures.Add($Message) }
function Add-Warning([string] $Message) { $warnings.Add($Message) }

$themeFile = Join-Path $themeRoot 'Theme.lua'
$assetRoot = Join-Path $themeRoot 'Assets'
$sourceRoot = Join-Path $themeRoot 'Sources'

if (-not (Test-Path -LiteralPath $themeFile)) {
    throw "Theme file does not exist: $themeFile"
}

$registrationLua = Get-Content -Raw -LiteralPath $themeFile
$registration = [regex]::Match($registrationLua, 'RegisterTheme\("([^"]+)"')
if (-not $registration.Success) {
    Add-Failure 'Theme.lua does not contain a recognizable PF:RegisterTheme call.'
}
$themeId = if ($registration.Success) { $registration.Groups[1].Value } else { '<unknown>' }

# Theme fragments are intentionally plain Lua files beside Theme.lua. Read the
# complete authoring surface so assets and optional sections can move out of
# the final registration file without weakening validation.
$themeLuaFiles = @(Get-ChildItem -LiteralPath $themeRoot -Filter '*.lua' -File | Sort-Object Name)
$themeLua = ($themeLuaFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"

$assetMatches = [regex]::Matches(
    $themeLua,
    '(?m)^\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*"([^"]+\.tga)"'
)
$assetMap = @{}
foreach ($match in $assetMatches) {
    $assetMap[$match.Groups[1].Value] = $match.Groups[2].Value
}

$expected = @{
    statusBar = @(512, 64)
    portraitFrame = @(256, 256)
    indicatorFrame = @(128, 128)
    castBarFrame = @(1024, 128)
    castBarInterruptGlow = @(1024, 128)
    playerFrameWithPet = @(1024, 512)
    playerFrameWithPetHealthOnly = @(1024, 512)
    unitFrame = @(1024, 512)
    unitFrameOneBar = @(1024, 512)
    targetOfTargetFrame = @(1024, 512)
    targetOfTargetFrameOneBar = @(1024, 512)
    partyFrame = @(1024, 512)
    partyConnector = @(128, 256)
    raidFrame = @(1024, 256)
    raidThreatGlow = @(256, 128)
    raidTargetClasp = @(32, 128)
    raidGroupHeader = @(512, 128)
    raidLeavesMaple = @(256, 256)
    raidLeavesGolden = @(256, 256)
    raidLeavesOak = @(256, 256)
    raidLeavesAspen = @(256, 256)
    nameplateFrame = @(1024, 256)
    restingIndicator = @(512, 256)
}

if ($themeLua -match '(?m)^\s*classResources\s*=\s*\{') {
    $expected.classResourcePointFrame = @(128, 128)
    $expected.classResourceBarFrame = @(1024, 128)
    $expected.classResourceTotemFrame = @(128, 128)
    $expected.classResourceJewelActive = @(128, 128)
    $expected.classResourceJewelEmpty = @(128, 128)
    $expected.classResourceAmmoActive = @(128, 128)
    $expected.classResourceAmmoEmpty = @(128, 128)
}

$validatedAssetRoles = 0
foreach ($key in $expected.Keys) {
    if ($key -eq 'playerFrameWithPetHealthOnly' -and -not $assetMap.ContainsKey($key)) {
        continue
    }
    if (-not $assetMap.ContainsKey($key)) {
        Add-Failure "Missing required asset key: $key"
        continue
    }

    $validatedAssetRoles++

    $fileName = $assetMap[$key]
    $assetPath = Join-Path $assetRoot $fileName
    if (-not (Test-Path -LiteralPath $assetPath)) {
        Add-Failure "Missing runtime asset for ${key}: $fileName"
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($assetPath)
    if ($bytes.Length -lt 18) {
        Add-Failure "Invalid TGA header: $fileName"
        continue
    }
    $width = $bytes[12] + 256 * $bytes[13]
    $height = $bytes[14] + 256 * $bytes[15]
    $contract = $expected[$key]
    if ($bytes[2] -ne 2) { Add-Failure "$fileName is not an uncompressed true-color TGA." }
    if ($bytes[16] -ne 32) { Add-Failure "$fileName is not 32 bits per pixel." }
    if (($bytes[17] -band 0x20) -eq 0) { Add-Failure "$fileName is not top-origin." }
    if ($width -ne $contract[0] -or $height -ne $contract[1]) {
        Add-Failure "$fileName is ${width}x${height}; expected $($contract[0])x$($contract[1])."
    }
    $expectedLength = 18 + $width * $height * 4
    if ($bytes.Length -ne $expectedLength) {
        Add-Failure "$fileName length does not match an uncompressed 32-bit ${width}x${height} TGA."
    }

    $sourceName = [System.IO.Path]::ChangeExtension($fileName, '.png')
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $sourceName))) {
        Add-Warning "No same-name editable PNG for $fileName; document its deterministic origin."
    }
}

$referencedFiles = @($assetMap.Values | Sort-Object -Unique)
if (Test-Path -LiteralPath $assetRoot) {
    foreach ($asset in Get-ChildItem -LiteralPath $assetRoot -Filter '*.tga' -File) {
        if ($asset.Name -notin $referencedFiles) {
            Add-Warning "Unreferenced runtime TGA: $($asset.Name)"
        }
    }
}

$tocPath = Join-Path $addonRoot 'PrettyFrames.toc'
$toc = Get-Content -LiteralPath $tocPath
$themeLine = "Themes\$ThemeName\Theme.lua"
$themeIndex = [array]::IndexOf($toc, $themeLine)
$databaseIndex = [array]::IndexOf($toc, 'Database.lua')
if ($themeIndex -lt 0) { Add-Failure "PrettyFrames.toc does not register $themeLine." }
elseif ($databaseIndex -lt 0 -or $themeIndex -gt $databaseIndex) {
    Add-Failure "$themeLine must load before Database.lua."
}

foreach ($luaFile in $themeLuaFiles) {
    $line = "Themes\$ThemeName\$($luaFile.Name)"
    $index = [array]::IndexOf($toc, $line)
    if ($index -lt 0) {
        Add-Failure "PrettyFrames.toc does not register $line."
    } elseif ($index -gt $themeIndex) {
        Add-Failure "$line must load no later than $themeLine; Theme.lua is the final registration file."
    }
}

$registeredIds = Get-ChildItem -LiteralPath (Join-Path $addonRoot 'Themes') -Filter 'Theme.lua' -Recurse -File |
    ForEach-Object {
        $match = [regex]::Match((Get-Content -Raw -LiteralPath $_.FullName), 'RegisterTheme\("([^"]+)"')
        if ($match.Success) { $match.Groups[1].Value }
    }
if ($themeId -ne '<unknown>' -and @($registeredIds | Where-Object { $_ -eq $themeId }).Count -ne 1) {
    Add-Failure "Theme ID is not unique: $themeId"
}

foreach ($warning in $warnings) { Write-Warning $warning }
foreach ($failure in $failures) { Write-Error $failure }

if ($failures.Count -gt 0) {
    throw "Theme validation failed with $($failures.Count) error(s)."
}

Write-Output "PASS: $ThemeName ($themeId)"
Write-Output "Validated $validatedAssetRoles declared asset roles and TOC registration."
if ($warnings.Count -gt 0) { Write-Output "Warnings: $($warnings.Count)" }
