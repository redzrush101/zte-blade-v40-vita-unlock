[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputImage,
    [Parameter(Mandatory)] [string] $OutputImage,
    [Parameter(Mandatory)] [string] $AvbTool,
    [Parameter(Mandatory)] [string] $Key,
    [string] $Python,
    [long] $PartitionSize = 67108864
)

$ErrorActionPreference = "Stop"

if (-not $Python) {
    $scoopPython = Join-Path $env:USERPROFILE "scoop\apps\python\current\python.exe"
    $Python = if (Test-Path -LiteralPath $scoopPython) {
        $scoopPython
    } else {
        (Get-Command python -ErrorAction Stop).Source
    }
}

if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    $scoopOpenSsl = Join-Path $env:USERPROFILE "scoop\apps\openssl\current\bin"
    if (-not (Test-Path -LiteralPath $scoopOpenSsl)) {
        throw "OpenSSL was not found"
    }
    $env:PATH = "$scoopOpenSsl;$env:PATH"
}

$inputPath = (Resolve-Path -LiteralPath $InputImage).Path
$avbPath = (Resolve-Path -LiteralPath $AvbTool).Path
$keyPath = (Resolve-Path -LiteralPath $Key).Path
$outputPath = [IO.Path]::GetFullPath($OutputImage)

Copy-Item -LiteralPath $inputPath -Destination $outputPath -Force

& $Python $avbPath erase_footer --image $outputPath
if ($LASTEXITCODE) { throw "avbtool erase_footer failed" }

& $Python $avbPath add_hash_footer `
    --image $outputPath `
    --partition_name boot `
    --partition_size $PartitionSize `
    --algorithm SHA256_RSA4096 `
    --key $keyPath `
    --salt 609e1cb304df264e93dd97bedfbbb58cca37467125b890ae7c9a283af164d35b `
    --prop "com.android.build.boot.fingerprint:ZTE/P606F02_1/P606F02:11/RP1A.201005.001/20220720.145553:user/release-keys" `
    --prop "com.android.build.boot.os_version:11"
if ($LASTEXITCODE) { throw "avbtool add_hash_footer failed" }

& $Python $avbPath info_image --image $outputPath
if ($LASTEXITCODE) { throw "avbtool info_image failed" }

Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath
