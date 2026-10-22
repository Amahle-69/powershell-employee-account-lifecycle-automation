
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptsDirectory = Join-Path $projectRoot 'scripts'
$reportsDirectory = Join-Path $projectRoot 'reports'

$onboardingScript = Join-Path $scriptsDirectory 'Export-OnboardingReport.ps1'
$offboardingScript = Join-Path $scriptsDirectory 'Export-OffboardingChecklist.ps1'

$onboardingPath = Join-Path $reportsDirectory 'onboarding-review-report.csv'
$offboardingPath = Join-Path $reportsDirectory 'offboarding-checklist.csv'

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

# Check that both workflow scripts exist.
Assert-True `
    -Name 'Onboarding script exists' `
    -Condition (Test-Path -LiteralPath $onboardingScript -PathType Leaf)

Assert-True `
    -Name 'Offboarding script exists' `
    -Condition (Test-Path -LiteralPath $offboardingScript -PathType Leaf)

if (
    -not (Test-Path -LiteralPath $onboardingScript -PathType Leaf) -or
    -not (Test-Path -LiteralPath $offboardingScript -PathType Leaf)
) {
    throw 'A lifecycle script is missing. Fix the file path before testing.'
}

# Generate fresh reports.
& $onboardingScript | Out-Null
& $offboardingScript | Out-Null

# Verify report files were generated.
Assert-True `
    -Name 'Onboarding report exists' `
    -Condition (Test-Path -LiteralPath $onboardingPath -PathType Leaf)

Assert-True `
    -Name 'Offboarding checklist exists' `
    -Condition (Test-Path -LiteralPath $offboardingPath -PathType Leaf)

if (
    -not (Test-Path -LiteralPath $onboardingPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $offboardingPath -PathType Leaf)
) {
    throw 'One or more reports were not generated.'
}

# Import the generated reports.
$onboarding = @(Import-Csv -LiteralPath $onboardingPath)
$offboarding = @(Import-Csv -LiteralPath $offboardingPath)

# Verify that only the expected employees were selected.
Assert-True `
    -Name 'Exactly one onboarding record was selected' `
    -Condition ($onboarding.Count -eq 1)

Assert-True `
    -Name 'Lerato is selected for onboarding review' `
    -Condition (
        $onboarding.Count -eq 1 -and
        $onboarding[0].EmployeeID -eq 'E1001'
    )

Assert-True `
    -Name 'Onboarding HR approval remains pending' `
    -Condition (
        $onboarding.Count -eq 1 -and
        $onboarding[0].HRApprovalCheck -eq 'Pending'
    )

Assert-True `
    -Name 'Onboarding does not create an account' `
    -Condition (
        $onboarding.Count -eq 1 -and
        $onboarding[0].AccountCreation -eq
        'Not performed - authorised review required'
    )

Assert-True `
    -Name 'Exactly one offboarding record was selected' `
    -Condition ($offboarding.Count -eq 1)

Assert-True `
    -Name 'Sipho is selected for offboarding review' `
    -Condition (
        $offboarding.Count -eq 1 -and
        $offboarding[0].EmployeeID -eq 'E1005'
    )

Assert-True `
    -Name 'Offboarding checklist remains open for review' `
    -Condition (
        $offboarding.Count -eq 1 -and
        $offboarding[0].ChecklistStatus -eq
        'Open - manual review required'
    )

Assert-True `
    -Name 'Account disablement was not performed' `
    -Condition (
        $offboarding.Count -eq 1 -and
        $offboarding[0].AccountDisablement -eq
        'Not performed - authorised action required'
    )

# Display a concise summary.
Write-Host "`nLifecycle report test summary" -ForegroundColor Cyan
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"

if ($failed -gt 0) {
    throw 'One or more lifecycle report tests failed.'
}

Write-Host "`nAll lifecycle report tests passed." -ForegroundColor Green
