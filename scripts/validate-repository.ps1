[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Assert-Condition {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$requiredFiles = @(
    'README.md',
    'docs/raceday-erd.png',
    'docs/endpoint-plan.md',
    'docs/raceday-database.sql',
    '.github/workflows/validate.yml'
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $repositoryRoot $relativePath
    Assert-Condition (Test-Path -LiteralPath $fullPath -PathType Leaf) "Missing required file: $relativePath"
    Assert-Condition ((Get-Item -LiteralPath $fullPath).Length -gt 0) "Required file is empty: $relativePath"
}

$pngPath = Join-Path $repositoryRoot 'docs/raceday-erd.png'
$pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
$expectedPngSignature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
Assert-Condition ($pngBytes.Length -gt 8) 'ERD PNG is too small to be valid.'
Assert-Condition (-not (Compare-Object $expectedPngSignature $pngBytes[0..7])) 'ERD file does not have a valid PNG signature.'

$sql = Get-Content (Join-Path $repositoryRoot 'docs/raceday-database.sql') -Raw
$requiredTables = @('Users', 'ParticipantProfiles', 'Events', 'Categories', 'EventEnrollments', 'Results')
foreach ($table in $requiredTables) {
    Assert-Condition ($sql -match "(?im)^CREATE TABLE dbo\.$table\s*$") "SQL script does not create dbo.$table."
}

Assert-Condition (($sql | Select-String -Pattern '(?im)^\s*CONSTRAINT\s+PK_' -AllMatches).Matches.Count -ge 6) 'Every entity must have a primary-key constraint.'
Assert-Condition (($sql | Select-String -Pattern '(?im)FOREIGN KEY' -AllMatches).Matches.Count -ge 8) 'Expected foreign-key relationships are missing.'
Assert-Condition (($sql | Select-String -Pattern '(?im)^\s*INSERT INTO dbo\.' -AllMatches).Matches.Count -ge 6) 'Every entity must receive seed data.'
Assert-Condition ($sql -match "THROW 50015") 'Post-deployment verification checks are missing.'

$endpointPlan = Get-Content (Join-Path $repositoryRoot 'docs/endpoint-plan.md') -Raw
$endpointAreas = @('Authentication', 'User profile', 'Event endpoints', 'Category endpoints', 'Event enrolment', 'Result endpoints')
foreach ($area in $endpointAreas) {
    Assert-Condition ($endpointPlan -match [regex]::Escape($area)) "Endpoint plan is missing the $area area."
}

$requiredColumns = @('HTTP method', 'Route', 'Description', 'Role required', 'Request body', 'Expected response')
foreach ($column in $requiredColumns) {
    Assert-Condition ($endpointPlan -match [regex]::Escape($column)) "Endpoint plan is missing the '$column' column."
}

$readme = Get-Content (Join-Path $repositoryRoot 'README.md') -Raw
foreach ($section in @('RaceDay', 'Organiser', 'Participant', 'CI/CD', 'YouTube')) {
    Assert-Condition ($readme -match [regex]::Escape($section)) "README is missing required content: $section."
}

$commitCount = [int](& git -C $repositoryRoot rev-list --count HEAD)
Assert-Condition ($LASTEXITCODE -eq 0) 'Unable to inspect Git commit history.'
Assert-Condition ($commitCount -ge 20) "Repository has $commitCount commits; at least 20 meaningful commits are required."

Write-Host "Repository validation passed: $($requiredFiles.Count) required files, $($requiredTables.Count) SQL entities, and $commitCount commits."

