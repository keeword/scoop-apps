#Requires -Version 7.4
$ErrorActionPreference = 'Stop'

$validator = Join-Path $PSScriptRoot 'Test-Bucket.ps1'
$fixturePath = Join-Path ([System.IO.Path]::GetTempPath()) "scoop-bucket-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixturePath | Out-Null
$manifestPath = Join-Path $fixturePath 'app.json'
$passed = 0

function New-Manifest {
    return @{
        version = '1.0.0'
        homepage = 'https://example.com/app'
        license = 'MIT'
        architecture = @{ '64bit' = @{
            url = 'https://example.com/app.zip'
            hash = 'a' * 64
        } }
    }
}

function Assert-Rejected([string] $Name, [hashtable] $Manifest, [string] $Expected) {
    $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
    $failure = $null
    try { & $validator -BucketPath $fixturePath }
    catch { $failure = $_.Exception.Message }
    if (-not $failure -or $failure -notmatch $Expected) {
        throw "${Name}: expected rejection matching '$Expected', got '$failure'"
    }
    Write-Host "PASS: $Name"
    $script:passed++
}

try {
    & $validator
    $passed++

    $manifest = New-Manifest
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
    & $validator -BucketPath $fixturePath
    $passed++

    $manifest = New-Manifest
    $manifest.Remove('homepage')
    Assert-Rejected 'Missing homepage' $manifest 'schema violation'

    $manifest = New-Manifest
    $manifest['shortucts'] = @(@('app.exe', 'App'))
    Assert-Rejected 'Misspelled field' $manifest 'schema violation'

    $manifest = New-Manifest
    $manifest.architecture = @{ x86 = $manifest.architecture['64bit'] }
    Assert-Rejected 'Unsupported architecture' $manifest 'schema violation'

    $manifest = New-Manifest
    $manifest.architecture['64bit'].hash = 'not-a-hash'
    Assert-Rejected 'Invalid hash' $manifest 'schema violation'

    $manifest = New-Manifest
    $manifest.architecture['64bit'].hash = 'sha1:' + ('a' * 40)
    Assert-Rejected 'Non-SHA-256 hash' $manifest 'requires SHA-256'

    $manifest = New-Manifest
    $manifest.architecture['64bit'].Remove('hash')
    Assert-Rejected 'Missing architecture hash' $manifest "needs 'url' and 'hash'"

    $manifest = New-Manifest
    $manifest.architecture['64bit'].url = @('https://example.com/a.zip', 'https://example.com/b.zip')
    Assert-Rejected 'URL and hash counts differ' $manifest 'counts must match'

    $manifest = New-Manifest
    $variant = $manifest.architecture['64bit']
    $manifest.Remove('architecture')
    $manifest.url = $variant.url
    $manifest.hash = 'sha256:' + $variant.hash
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
    & $validator -BucketPath $fixturePath
    $passed++

    $manifest.url = @('https://example.com/a.zip', 'https://example.com/b.zip')
    $manifest.hash = @(('a' * 64), ('b' * 64))
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
    & $validator -BucketPath $fixturePath
    $passed++

    # Supply known download bytes to test hashing and cleanup without network access.
    $downloadBytes = [System.Text.Encoding]::UTF8.GetBytes('download fixture')
    $downloadHash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($downloadBytes))
    $downloadFiles = [System.Collections.Generic.List[string]]::new()
    $downloadStub = {
        param([string] $Uri, [string] $OutFile, [int] $TimeoutSec)
        $downloadFiles.Add($OutFile)
        [System.IO.File]::WriteAllBytes($OutFile, $downloadBytes)
    }.GetNewClosure()
    Set-Item -Path Function:Invoke-WebRequest -Value $downloadStub

    $manifest = New-Manifest
    $manifest.architecture['64bit'].hash = $downloadHash
    $manifest.architecture.arm64 = @{ url = 'https://example.com/arm64.zip'; hash = $downloadHash }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
    & $validator -BucketPath $fixturePath -CheckDownloads
    if ($downloadFiles.Count -ne 2 -or @($downloadFiles | Where-Object { Test-Path -LiteralPath $_ }).Count) {
        throw 'Download validation must check all architectures and remove temporary files'
    }
    $passed++

    $manifest.architecture['64bit'].hash = 'a' * 64
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath
    $failure = $null
    try { & $validator -BucketPath $fixturePath -CheckDownloads }
    catch { $failure = $_.Exception.Message }
    if ($failure -notmatch 'SHA-256 mismatch' -or (Test-Path -LiteralPath $downloadFiles[-1])) {
        throw 'Hash mismatch must fail validation and remove the downloaded file'
    }
    $passed++

    Set-Content -LiteralPath $manifestPath -Value '{ invalid JSON'
    $failure = $null
    try { & $validator -BucketPath $fixturePath }
    catch { $failure = $_.Exception.Message }
    if ($failure -notmatch 'invalid JSON') { throw 'Invalid JSON was not rejected' }
    $passed++

    Remove-Item -LiteralPath $manifestPath
    $failure = $null
    try { & $validator -BucketPath $fixturePath }
    catch { $failure = $_.Exception.Message }
    if ($failure -notmatch 'No manifests') { throw 'Empty bucket was not rejected' }
    $passed++

    Write-Host "Passed $passed manifest validation checks."
}
finally {
    # The fixture contains only the single file created above; no recursive deletion.
    if (Test-Path -LiteralPath $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force }
    Remove-Item -LiteralPath $fixturePath -Force
}
