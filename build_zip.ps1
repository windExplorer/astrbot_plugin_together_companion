# Package the plugin into a zip under dist/, named with the version from metadata.yaml.
# IMPORTANT: forces forward slash '/' as the zip internal separator.
# Windows Compress-Archive writes backslashes '\', which break Linux unzip and
# AstrBot resource lookup (room server fails to find web/ assets).
param(
    [string]$Root = (Resolve-Path .).Path
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Read version from metadata.yaml
$metaPath = Join-Path $Root 'metadata.yaml'
if (-not (Test-Path $metaPath)) {
    Write-Error "metadata.yaml not found"
    exit 1
}
$version = $null
foreach ($line in (Get-Content $metaPath)) {
    if ($line -match '^version:\s*"?([0-9][0-9A-Za-z.\-]*)"?\s*$') {
        $version = $Matches[1]
        break
    }
}
if (-not $version) {
    Write-Error "cannot parse version from metadata.yaml"
    exit 1
}

$pluginName = 'astrbot_plugin_together_companion'
$distDir = Join-Path $Root 'dist'
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
$out = Join-Path $distDir "$pluginName`_$version.zip"

# Exclusions
$exclDirs = @('.git', 'Refs', '__pycache__', 'dist')
$exclFiles = @('.gitignore')

# Collision check: refuse to overwrite an existing same-version package.
# Bump metadata.yaml version first, then repackage. Old packages are kept.
if (Test-Path $out) {
    Write-Error "Package already exists: $out`nBump version in metadata.yaml before repackaging. Existing packages are kept (not overwritten)."
    exit 1
}

$zip = [System.IO.Compression.ZipFile]::Open($out, [System.IO.Compression.ZipArchiveMode]::Create)
$count = 0
Get-ChildItem -Path $Root -Recurse -Force |
    Where-Object { -not $_.PSIsContainer } |
    ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length + 1).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
        $top = $rel.Split('/')[0]
        if ($exclDirs -contains $top) { return }
        if ($exclFiles -contains $_.Name) { return }
        $arc = "$pluginName/" + $rel
        $entry = $zip.CreateEntry($arc)
        $src = [System.IO.File]::OpenRead($_.FullName)
        $dst = $entry.Open()
        $src.CopyTo($dst)
        $src.Dispose()
        $dst.Dispose()
        $count++
    }
$zip.Dispose()

Write-Output "Packaged $count files -> $out (version $version, forward slashes)"
