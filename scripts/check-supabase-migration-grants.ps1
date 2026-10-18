param(
    [string]$MigrationDirectory = (Join-Path $PSScriptRoot '..\supabase\migrations'),
    [string]$EnforceFromVersion = '20261018000000'
)

$ErrorActionPreference = 'Stop'
$violations = [System.Collections.Generic.List[string]]::new()

function Normalize-SqlIdentifier([string]$Identifier) {
    return $Identifier.Trim('"').ToLowerInvariant()
}

$migrationFiles = Get-ChildItem -LiteralPath $MigrationDirectory -Filter '*.sql' -File |
    Where-Object { $_.BaseName -match '^(\d{14})_' -and $Matches[1] -ge $EnforceFromVersion } |
    Sort-Object Name

foreach ($file in $migrationFiles) {
    $sql = Get-Content -LiteralPath $file.FullName -Raw

    $tableMatches = [regex]::Matches(
        $sql,
        '(?is)\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?public\.(?<name>"?[a-z_][a-z0-9_]*"?)'
    )
    foreach ($match in $tableMatches) {
        $table = Normalize-SqlIdentifier $match.Groups['name'].Value
        $escaped = [regex]::Escape($table)
        $hasRls = $sql -match "(?is)\balter\s+table\s+(?:only\s+)?public\.`"?$escaped`"?\s+enable\s+row\s+level\s+security\b"
        $hasGrantDecision = $sql -match "(?is)\b(?:grant|revoke)\b[^;]*\bon\s+(?:table\s+)?public\.`"?$escaped`"?\b"
        if (-not $hasRls) {
            $violations.Add("$($file.Name): public.$table does not enable RLS in its creation migration.")
        }
        if (-not $hasGrantDecision) {
            $violations.Add("$($file.Name): public.$table has no explicit GRANT or REVOKE decision.")
        }
    }

    $functionMatches = [regex]::Matches(
        $sql,
        '(?is)\bcreate\s+(?:or\s+replace\s+)?function\s+public\.(?<name>"?[a-z_][a-z0-9_]*"?)\s*\('
    )
    foreach ($match in $functionMatches) {
        $function = Normalize-SqlIdentifier $match.Groups['name'].Value
        $escaped = [regex]::Escape($function)
        $hasRevoke = $sql -match "(?is)\brevoke\b[^;]*\bon\s+function\s+public\.`"?$escaped`"?\s*\("
        if (-not $hasRevoke) {
            $violations.Add("$($file.Name): public.$function() does not revoke default function execution.")
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Validated explicit Data API authorization for $($migrationFiles.Count) migration(s)."
