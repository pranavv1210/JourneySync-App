param(
    [ValidateSet('none', 'patch', 'minor', 'major')]
    [string]$Bump = 'patch',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$definesPath = Join-Path $repoRoot 'dart_defines.local.json'
$keyPropertiesPath = Join-Path $repoRoot 'android\key.properties'
$apkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-sideload-release.apk'
$landingApkPath = Join-Path $repoRoot 'landing\public\journeysync.apk'

function Invoke-Checked([string]$Label, [scriptblock]$Command) {
    Write-Host "`n==> $Label"
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

function Set-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

foreach ($command in @('git', 'flutter', 'dart', 'npm', 'gh')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found."
    }
}
foreach ($required in @($pubspecPath, $definesPath, $keyPropertiesPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required file not found: $required" }
}

$match = Select-String -Path $pubspecPath -Pattern '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$'
if (-not $match) { throw 'pubspec.yaml does not contain a valid semantic version.' }
$oldVersion = "$($match.Matches[0].Groups[1].Value).$($match.Matches[0].Groups[2].Value).$($match.Matches[0].Groups[3].Value)"
$major = [int]$match.Matches[0].Groups[1].Value
$minor = [int]$match.Matches[0].Groups[2].Value
$patch = [int]$match.Matches[0].Groups[3].Value
$build = [int]$match.Matches[0].Groups[4].Value

switch ($Bump) {
    'major' { $major++; $minor = 0; $patch = 0; $build++ }
    'minor' { $minor++; $patch = 0; $build++ }
    'patch' { $patch++; $build++ }
    'none'  { }
}
$newVersion = "$major.$minor.$patch"

if ($Bump -ne 'none') {
    $versionFiles = @(
        'pubspec.yaml',
        'lib/services/app_version.dart',
        'lib/services/geocoding_service.dart',
        'landing/src/data/site-content.ts',
        'landing/src/components/BetaDownloadClient.tsx',
        'landing/src/components/modals/DownloadModal.tsx',
        'landing/src/components/sections/DownloadSection.tsx',
        'landing/src/components/sections/BikeModeSection.tsx'
    )
    foreach ($relativePath in $versionFiles) {
        $path = Join-Path $repoRoot $relativePath
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace($oldVersion, $newVersion)
        if ($relativePath -eq 'pubspec.yaml') {
            $content = [regex]::Replace($content, '^version:\s*\d+\.\d+\.\d+\+\d+\s*$', "version: $newVersion+$build", 'Multiline')
        }
        Set-Utf8NoBom $path $content
    }
}

Invoke-Checked 'Dart format check' { dart format --output=none --set-exit-if-changed . }
Invoke-Checked 'Flutter analysis' { flutter analyze }
Invoke-Checked 'Flutter tests' { flutter test }
Invoke-Checked 'Landing lint' { npm --prefix landing run lint }
Invoke-Checked 'Landing production build' { npm --prefix landing run build }
Invoke-Checked 'Signed Android release build' { flutter build apk --flavor sideload --release --dart-define-from-file=dart_defines.local.json }

Copy-Item -LiteralPath $apkPath -Destination $landingApkPath -Force
$buildHash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
$landingHash = (Get-FileHash -LiteralPath $landingApkPath -Algorithm SHA256).Hash
if ($buildHash -ne $landingHash) { throw 'Landing APK checksum does not match the release build.' }
Write-Host "APK SHA-256: $buildHash"

$buildToolsRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
$aapt = Get-ChildItem -LiteralPath $buildToolsRoot -Filter 'aapt.exe' -Recurse |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
$apkSigner = Get-ChildItem -LiteralPath $buildToolsRoot -Filter 'apksigner.bat' -Recurse |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $aapt -or -not $apkSigner) { throw 'Android aapt/apksigner tools were not found.' }
$badging = & $aapt dump badging $apkPath | Select-Object -First 1
if ($badging -notmatch "name='com\.journeysync\.app'" -or $badging -notmatch "versionName='$([regex]::Escape($newVersion))'") {
    throw "APK metadata did not match com.journeysync.app $newVersion. Found: $badging"
}
Invoke-Checked 'APK signature verification' { & $apkSigner verify $apkPath }

Invoke-Checked 'Diff whitespace validation' { git -C $repoRoot diff --check }
Invoke-Checked 'Stage intended repository changes' { git -C $repoRoot add -A }
$staged = git -C $repoRoot diff --cached --name-only
if (-not $staged) { throw 'There are no changes to commit.' }
if ($staged -match '(^|/)(\.env|dart_defines\.local\.json|key\.properties|.*\.(jks|keystore|p12))$') {
    throw 'A secret or signing file is staged. Unstage it before continuing.'
}
Invoke-Checked 'Commit release change' { git -C $repoRoot commit -m $Message }

if (-not $SkipPush) {
    Invoke-Checked 'Push current branch' { git -C $repoRoot push origin HEAD }
    $commitSha = (git -C $repoRoot rev-parse HEAD).Trim()
    $runId = $null
    for ($attempt = 0; $attempt -lt 20 -and -not $runId; $attempt++) {
        Start-Sleep -Seconds 6
        $runJson = gh run list --commit $commitSha --limit 5 --json databaseId,workflowName |
            ConvertFrom-Json
        $runId = ($runJson | Where-Object workflowName -eq 'Flutter CI/CD Quality Pipeline' |
            Select-Object -First 1).databaseId
    }
    if (-not $runId) { throw "No GitHub Actions run appeared for commit $commitSha." }
    Invoke-Checked 'GitHub Actions verification' { gh run watch $runId --exit-status }

    $expectedLength = (Get-Item -LiteralPath $landingApkPath).Length
    $deploymentVerified = $false
    for ($attempt = 0; $attempt -lt 30 -and -not $deploymentVerified; $attempt++) {
        try {
            $page = Invoke-WebRequest -Uri 'https://journeysyncrideapp.in/' -UseBasicParsing -TimeoutSec 30
            $apkHead = Invoke-WebRequest -Uri "https://journeysyncrideapp.in/journeysync.apk?v=$newVersion" -Method Head -UseBasicParsing -TimeoutSec 30
            $deploymentVerified =
                $page.StatusCode -eq 200 -and
                $page.Content.Contains("v$newVersion") -and
                $apkHead.StatusCode -eq 200 -and
                [long]$apkHead.Headers['Content-Length'] -eq $expectedLength
        } catch { $deploymentVerified = $false }
        if (-not $deploymentVerified) { Start-Sleep -Seconds 10 }
    }
    if (-not $deploymentVerified) { throw 'Landing deployment did not serve the expected version and APK size in time.' }
    Write-Host "CI and landing deployment verified for commit $commitSha."
}

Write-Host "Released version: $newVersion+$build"
Write-Host "Landing APK: $landingApkPath"
