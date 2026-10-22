
$ErrorActionPreference = 'Stop'

# Locate the project files.
$projectRoot = Split-Path -Parent $PSScriptRoot
$validationScript = Join-Path $projectRoot 'scripts\Import-EmployeeData.ps1'
$reportPath = Join-Path $projectRoot 'reports\employee-validation-report.csv'

$passed = 0
$failed = 0

function Assert-True {
    param(
        [string]$Name,
        [bool]$Condition
    )

    if ($Condition) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:failed++
    }
}

# Confirm that the validation script exists.
Assert-True `
    -Name 'Validation script exists' `
    -Condition (Test-Path -LiteralPath $validationScript -PathType Leaf)

if (-not (Test-Path -LiteralPath $validationScript -PathType Leaf)) {
    throw "Cannot run tests because the validation script is missing."
}

# Run the real validation script to generate a fresh report.
& $validationScript | Out-Null

Assert-True `
    -Name 'Validation report was generated' `
    -Condition (Test-Path -LiteralPath $reportPath -PathType Leaf)

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Cannot continue because the validation report was not generated."
}

# Read the generated report.
$results = @(Import-Csv -LiteralPath $reportPath)

Assert-True `
    -Name 'All six employee records are included' `
    -Condition ($results.Count -eq 6)

# Check the record that should pass the current validation rules.
$lerato = @($results | Where-Object { $_.EmployeeID -eq 'E1001' })

Assert-True `
    -Name 'Lerato is marked ReadyForReview' `
    -Condition (
        $lerato.Count -eq 1 -and
        $lerato[0].ValidationStatus -eq 'ReadyForReview'
    )

# Check that the missing department is detected.
$thabo = @($results | Where-Object { $_.EmployeeID -eq 'E1002' })

Assert-True `
    -Name 'Missing department is flagged' `
    -Condition (
        $thabo.Count -eq 1 -and
        $thabo[0].ValidationStatus -eq 'NeedsReview' -and
        $thabo[0].Issues -match 'Missing Department'
    )

# Check that the malformed email is detected.
$zanele = @($results | Where-Object { $_.EmployeeID -eq 'E1003' })

Assert-True `
    -Name 'Invalid email format is flagged' `
    -Condition (
        $zanele.Count -eq 1 -and
        $zanele[0].ValidationStatus -eq 'NeedsReview' -and
        $zanele[0].Issues -match 'Invalid email format'
    )

# Check that both records with duplicate IDs are flagged.
$duplicateRecords = @(
    $results | Where-Object { $_.EmployeeID -eq 'E1004' }
)

$flaggedDuplicates = @(
    $duplicateRecords | Where-Object {
        $_.ValidationStatus -eq 'NeedsReview' -and
        $_.Issues -match 'Duplicate EmployeeID'
    }
)

Assert-True `
    -Name 'Both duplicate employee ID records are flagged' `
    -Condition (
        $duplicateRecords.Count -eq 2 -and
        $flaggedDuplicates.Count -eq 2
    )

# Check the offboarding record.
$sipho = @($results | Where-Object { $_.EmployeeID -eq 'E1005' })

Assert-True `
    -Name 'Sipho passes the current validation rules' `
    -Condition (
        $sipho.Count -eq 1 -and
        $sipho[0].ValidationStatus -eq 'ReadyForReview'
    )

# Verify the expected overall totals.
$readyCount = @(
    $results | Where-Object { $_.ValidationStatus -eq 'ReadyForReview' }
).Count

$reviewCount = @(
    $results | Where-Object { $_.ValidationStatus -eq 'NeedsReview' }
).Count

Assert-True `
    -Name 'Two records are ready for review' `
    -Condition ($readyCount -eq 2)

Assert-True `
    -Name 'Four records need review' `
    -Condition ($reviewCount -eq 4)

# Print the test summary.
Write-Host "`nTest summary" -ForegroundColor Cyan
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"

if ($failed -gt 0) {
    throw "One or more employee validation tests failed."
}

Write-Host "`nAll employee validation tests passed." -ForegroundColor Green
