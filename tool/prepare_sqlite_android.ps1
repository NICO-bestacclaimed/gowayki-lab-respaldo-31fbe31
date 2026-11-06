# Pre-fetch official sqlite3 3.9.0 Android artifacts when a nested build hook
# cannot reach GitHub. Hashes match sqlite3's published asset_hashes.dart.
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$cacheRoot = Join-Path $repositoryRoot '.dart_tool\hooks_runner\shared\sqlite3\build'
$artifacts = @(
    @{ Name = 'libsqlite3.arm.android.so'; Hash = 'f33868d94e80992af137c7cf046a99406800f15434e289733cf472346be00ed4' },
    @{ Name = 'libsqlite3.arm64.android.so'; Hash = 'e684ef8646ffd48b95bae58bf29c55ffd85acebac2a7118ffde9fd02df37d629' },
    @{ Name = 'libsqlite3.x64.android.so'; Hash = 'ff28e78c5b790b3eafc15ceface32c3f5626ef80f622a726c60b0b802825699a' }
)
foreach ($artifact in $artifacts) {
    $directory = Join-Path $cacheRoot ('download-' + $artifact.Hash.Substring(0, 8))
    $destination = Join-Path $directory 'libsqlite3.so'
    $fullDestination = [System.IO.Path]::GetFullPath($destination)
    if (-not $fullDestination.StartsWith($repositoryRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Artifact cache must stay inside the repository.'
    }
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    if ((Test-Path -LiteralPath $destination) -and
        ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $artifact.Hash)) {
        Write-Output ('Verified cached ' + $artifact.Name)
        continue
    }
    $temporary = $destination + '.download'
    Invoke-WebRequest -Uri ('https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.9.0/' + $artifact.Name) -OutFile $temporary -TimeoutSec 45
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $artifact.Hash) { throw ('SHA-256 mismatch: ' + $artifact.Name) }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
    Write-Output ('Downloaded and verified ' + $artifact.Name)
}
