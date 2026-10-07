#Requires -Version 7.4

param(
    [string] $BucketPath = (Join-Path $PSScriptRoot '..\bucket'),
    [switch] $CheckDownloads
)

$ErrorActionPreference = 'Stop'
$schemaPath = Join-Path $PSScriptRoot 'vendor\scoop.schema.json'
$manifests = @(Get-ChildItem -LiteralPath $BucketPath -Filter '*.json' -File)
$downloads = [System.Collections.Generic.List[object]]::new()

if ($manifests.Count -eq 0) {
    throw "No manifests found in '$BucketPath'"
}

foreach ($manifest in $manifests) {
    try {
        $json = Get-Content -LiteralPath $manifest.FullName -Raw
        if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
            throw 'Schema validation returned false'
        }
        $app = $json | ConvertFrom-Json
    }
    catch {
        throw "$($manifest.Name): invalid JSON or Scoop schema violation: $_"
    }

    $variants = @([pscustomobject]@{ Name = 'default'; Value = $app })
    if ($app.architecture) {
        if (@($app.architecture.PSObject.Properties).Count -eq 0) {
            throw "$($manifest.Name): architecture must not be empty"
        }
        $variants = @($app.architecture.PSObject.Properties)
    }

    foreach ($variant in $variants) {
        $urls = @($variant.Value.url)
        $hashes = @($variant.Value.hash)
        if (-not $variant.Value.url -or -not $variant.Value.hash) {
            throw "$($manifest.Name): '$($variant.Name)' needs 'url' and 'hash'"
        }
        if ($urls.Count -ne $hashes.Count) {
            throw "$($manifest.Name): '$($variant.Name)' URL and hash counts must match"
        }
        for ($index = 0; $index -lt $urls.Count; $index++) {
            if ($hashes[$index] -notmatch '^(sha256:)?[a-fA-F0-9]{64}$') {
                throw "$($manifest.Name): '$($variant.Name)' requires SHA-256 hashes"
            }
            $downloads.Add([pscustomobject]@{
                App = $manifest.BaseName
                Architecture = $variant.Name
                Url = $urls[$index]
                Hash = ($hashes[$index] -replace '^sha256:', '')
            })
        }
    }
}

Write-Host "Validated $($manifests.Count) manifest(s) against the Scoop schema."

if ($CheckDownloads) {
    foreach ($download in $downloads) {
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            # Scoop's URL fragment can rename the file; it is not part of the HTTP request.
            $url = ($download.Url -split '#', 2)[0]
            Invoke-WebRequest -Uri $url -OutFile $tempFile -TimeoutSec 300
            $actualHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash
            if ($actualHash -ine $download.Hash) {
                throw "$($download.App) ($($download.Architecture)): SHA-256 mismatch; expected $($download.Hash), got $actualHash"
            }
            Write-Host "Verified $($download.App) ($($download.Architecture)): $url"
        }
        finally {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}
