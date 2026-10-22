
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$validationScript = Join-Path $projectRoot 'scripts\Import-EmployeeData.ps1'

if (-not (Test-Path -LiteralPath $validationScript -PathType Leaf)) {
    throw "Validation script not found: $validationScript"
}

$testRoot = Join-Path $env:TEMP (
    'EmployeeDataEdgeTests-' + [guid]::NewGuid().ToString('N')
)

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$script:passed = 0
$script:failed = 0

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

function Test-ExpectedFailure {
    param(
        [string]$Name,
        [string]$CsvPath,
        [string]$ReportPath,
        [string]$ExpectedMessage
    )

    $caughtMessage = ''

    try {
        & $validationScript `
            -CsvPath $CsvPath `
            -ReportPath $ReportPath | Out-Null
    }
    catch {
        $caughtMessage = $_.Exception.Message
    }

    $correctFailure = (
        -not [string]::IsNullOrWhiteSpace($caughtMessage) -and
        $caughtMessage -like "*$ExpectedMessage*"
    )

    Assert-True -Name $Name -Condition $correctFailure
}

try {
    # Test 1: Empty CSV file should be rejected.
    $emptyCsv = Join-Path $testRoot 'empty.csv'

    [System.IO.File]::WriteAllText($emptyCsv, '')

    Test-ExpectedFailure `
        -Name 'Empty CSV is rejected' `
        -CsvPath $emptyCsv `
        -ReportPath (Join-Path $testRoot 'empty-report.csv') `
        -ExpectedMessage 'contains no records'

    # Test 2: Missing required headers should be rejected.
    $missingHeadersCsv = Join-Path $testRoot 'missing-headers.csv'

    $missingHeadersContent = @"
EmployeeID,FirstName
E9001,Lerato
"@

    [System.IO.File]::WriteAllText(
        $missingHeadersCsv,
        $missingHeadersContent
    )

    Test-ExpectedFailure `
        -Name 'Missing required CSV headers are rejected' `
        -CsvPath $missingHeadersCsv `
        -ReportPath (Join-Path $testRoot 'missing-headers-report.csv') `
        -ExpectedMessage 'Missing CSV columns'

    # Test 3: An invalid start date should be flagged.
    $invalidDateCsv = Join-Path $testRoot 'invalid-start-date.csv'

    $invalidDateContent = @"
EmployeeID,FirstName,LastName,Department,Email,EmploymentStatus,StartDate,EndDate
E9002,Amahle,Hadebe,Finance,amahle.hadebe@example.com,NewStarter,03/11/2026,
"@

    [System.IO.File]::WriteAllText(
        $invalidDateCsv,
        $invalidDateContent
    )

    $invalidDateReport = Join-Path $testRoot 'invalid-date-report.csv'

    & $validationScript `
        -CsvPath $invalidDateCsv `
        -ReportPath $invalidDateReport | Out-Null

    $invalidDateResults = @(
        Import-Csv -LiteralPath $invalidDateReport
    )

    $invalidDateRecord = @(
        $invalidDateResults |
            Where-Object { $_.EmployeeID -eq 'E9002' }
    )

    Assert-True `
        -Name 'Invalid start date produces a report record' `
        -Condition ($invalidDateRecord.Count -eq 1)

    $invalidDateIsFlagged = (
        $invalidDateRecord.Count -eq 1 -and
        $invalidDateRecord[0].ValidationStatus -eq 'NeedsReview' -and
        $invalidDateRecord[0].Issues -like '*StartDate must use yyyy-MM-dd format*'
    )

    Assert-True `
        -Name 'Invalid start date is flagged for review' `
        -Condition $invalidDateIsFlagged

    # Test 4: An end date before the start date should be flagged.
    $dateOrderCsv = Join-Path $testRoot 'invalid-date-order.csv'

    $dateOrderContent = @"
EmployeeID,FirstName,LastName,Department,Email,EmploymentStatus,StartDate,EndDate
E9003,Thabo,Ndlovu,IT,thabo.ndlovu@example.com,Offboarding,2026-10-31,2026-10-01
"@

    [System.IO.File]::WriteAllText(
        $dateOrderCsv,
        $dateOrderContent
    )

    $dateOrderReport = Join-Path $testRoot 'date-order-report.csv'

    & $validationScript `
        -CsvPath $dateOrderCsv `
        -ReportPath $dateOrderReport | Out-Null

    $dateOrderResults = @(
        Import-Csv -LiteralPath $dateOrderReport
    )

    $dateOrderRecord = @(
        $dateOrderResults |
            Where-Object { $_.EmployeeID -eq 'E9003' }
    )

    $dateOrderIsFlagged = (
        $dateOrderRecord.Count -eq 1 -and
        $dateOrderRecord[0].ValidationStatus -eq 'NeedsReview' -and
        $dateOrderRecord[0].Issues -like '*EndDate is earlier than StartDate*'
    )

    Assert-True `
        -Name 'End date earlier than start date is flagged' `
        -Condition $dateOrderIsFlagged
}
finally {
    # Remove only the temporary test files created by this test.
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host "`nEdge-case test summary" -ForegroundColor Cyan
Write-Host "Passed: $script:passed"
Write-Host "Failed: $script:failed"

if ($script:failed -gt 0) {
    throw 'One or more employee data edge-case tests failed.'
}

Write-Host "`nAll employee data edge-case tests passed." -ForegroundColor Green
