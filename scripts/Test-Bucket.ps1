$ErrorActionPreference = 'Stop'

$bucketPath = Join-Path $PSScriptRoot '..\bucket'
$manifests = @(Get-ChildItem -LiteralPath $bucketPath -Filter '*.json' -File)

foreach ($manifest in $manifests) {
    try {
        $app = Get-Content -LiteralPath $manifest.FullName -Raw | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in $($manifest.Name): $_"
    }

    if (-not $app.version) {
        throw "$($manifest.Name): missing 'version'"
    }

    if ($app.architecture) {
        foreach ($variant in $app.architecture.PSObject.Properties) {
            if (-not $variant.Value.url -or -not $variant.Value.hash) {
                throw "$($manifest.Name): architecture '$($variant.Name)' needs 'url' and 'hash'"
            }
        }
    }
    elseif (-not $app.url -or -not $app.hash) {
        throw "$($manifest.Name): missing 'url' or 'hash'"
    }
}

Write-Host "Validated $($manifests.Count) manifest(s)."
