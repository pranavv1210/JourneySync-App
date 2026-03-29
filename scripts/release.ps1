param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Title,

    [int]$BuildNumber = 0,

    [string]$NotesFile
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
    Write-Error $Message
    exit 1
}

function Require-Command($Command) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Fail "Required command '$Command' was not found."
    }
}

function Get-PubspecVersionParts($PubspecPath) {
    $match = Select-String -Path $PubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$'
    if (-not $match) {
        Fail "Could not find a valid version entry in pubspec.yaml."
    }

    return @{
        Version = $match.Matches[0].Groups[1].Value
        BuildNumber = [int]$match.Matches[0].Groups[2].Value
        RawLine = $match.Line.Trim()
    }
}

function Require-CleanGitTree($RepoRoot) {
    $status = git -C $RepoRoot status --short
    if ($status) {
        Fail "Git working tree is not clean. Commit or stash your changes before running the release script."
    }
}

function Require-File($Path) {
    if (-not (Test-Path $Path)) {
        Fail "Required file not found: $Path"
    }
}

function Get-PreviousTag($RepoRoot, $CurrentTag) {
    $tags = git -C $RepoRoot tag --sort=-creatordate
    foreach ($tag in $tags) {
        if ($tag -ne $CurrentTag) {
            return $tag
        }
    }

    return $null
}

function Build-ReleaseNotes($RepoRoot, $Version, $PreviousTag, $OutputPath) {
    $range = if ($PreviousTag) { "$PreviousTag..HEAD" } else { "HEAD" }
    $commitSubjects = git -C $RepoRoot log $range --pretty=format:"- %s"

    if (-not $commitSubjects) {
        $commitSubjects = "- General fixes and improvements"
    }

    $previousTagLabel = if ($PreviousTag) { $PreviousTag } else { "initial development" }

    @"
JourneySync Android release for v$Version.

What's included
$commitSubjects

Download
- journeysync-v$Version.apk attached in this release

Notes
- Built from the latest `main` branch state
- Changes included since $previousTagLabel
"@ | Set-Content -Path $OutputPath -Encoding ascii
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$androidKeyProperties = Join-Path $repoRoot "android\key.properties"
$dartDefinesPath = Join-Path $repoRoot "dart_defines.local.json"
$apkPath = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-release.apk"
$releaseNotesPath = Join-Path $env:TEMP "journeysync-release-notes-$Version.md"
$tag = "v$Version"
$releaseTitle = if ($Title) { $Title } else { "JourneySync v$Version" }

Require-Command git
Require-Command flutter
Require-Command gh

Require-CleanGitTree $repoRoot
Require-File $pubspecPath
Require-File $androidKeyProperties
Require-File $dartDefinesPath

gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail "GitHub CLI is not authenticated. Run 'gh auth login' once, then rerun this script."
}

$currentVersion = Get-PubspecVersionParts $pubspecPath
$resolvedBuildNumber = if ($BuildNumber -gt 0) { $BuildNumber } else { $currentVersion.BuildNumber + 1 }
$newVersionLine = "version: $Version+$resolvedBuildNumber"

$pubspecContent = Get-Content $pubspecPath -Raw
$updatedPubspecContent = [regex]::Replace(
    $pubspecContent,
    '^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\s*$',
    $newVersionLine,
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)

if ($updatedPubspecContent -eq $pubspecContent) {
    Fail "Failed to update pubspec.yaml with version $newVersionLine."
}

Set-Content -Path $pubspecPath -Value $updatedPubspecContent -Encoding ascii

$existingTag = git -C $repoRoot tag --list $tag
if ($existingTag) {
    Fail "Git tag $tag already exists."
}

Write-Host "Building signed release APK for $tag..."
flutter build apk --release --dart-define-from-file=dart_defines.local.json
if ($LASTEXITCODE -ne 0) {
    Fail "Flutter build failed."
}

Require-File $apkPath

$releaseAssetPath = Join-Path $repoRoot "build\app\outputs\flutter-apk\journeysync-$tag.apk"
Copy-Item -Path $apkPath -Destination $releaseAssetPath -Force

$previousTag = Get-PreviousTag $repoRoot $tag

if ($NotesFile) {
    Require-File $NotesFile
    Copy-Item -Path $NotesFile -Destination $releaseNotesPath -Force
} else {
    Build-ReleaseNotes $repoRoot $Version $previousTag $releaseNotesPath
}

git -C $repoRoot add pubspec.yaml
git -C $repoRoot commit -m "Release $tag"
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to create the release commit."
}

git -C $repoRoot push origin HEAD
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to push the release commit."
}

git -C $repoRoot tag -a $tag -m $releaseTitle
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to create git tag $tag."
}

git -C $repoRoot push origin $tag
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to push git tag $tag."
}

gh release create $tag $releaseAssetPath --title $releaseTitle --notes-file $releaseNotesPath
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to create the GitHub release."
}

Write-Host ""
Write-Host "Release published successfully."
Write-Host "Tag: $tag"
Write-Host "Title: $releaseTitle"
Write-Host "Asset: $releaseAssetPath"
