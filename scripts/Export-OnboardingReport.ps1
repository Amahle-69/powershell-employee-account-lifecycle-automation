
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Locate project files.
$projectRoot = Split-Path -Parent $PSScriptRoot
$validationScript = Join-Path $PSScriptRoot 'Import-EmployeeData.ps1'
$validationReport = Join-Path $projectRoot 'reports\employee-validation-report.csv'
$outputPath = Join-Path $projectRoot 'reports\onboarding-review-report.csv'

# Run validation again so the onboarding report uses fresh results.
if (-not (Test-Path -LiteralPath $validationScript -PathType Leaf)) {
    throw "Validation script not found: $validationScript"
}

& $validationScript

if (-not (Test-Path -LiteralPath $validationReport -PathType Leaf)) {
    throw "Employee validation report was not generated."
}

$employees = @(Import-Csv -LiteralPath $validationReport)

# Include only new starters whose records passed the current checks.
$eligibleEmployees = @(
    $employees | Where-Object {
        $_.EmploymentStatus -eq 'NewStarter' -and
        $_.ValidationStatus -eq 'ReadyForReview'
    }
)

if ($eligibleEmployees.Count -eq 0) {
    Write-Warning 'No eligible new-starter records are ready for review.'
    Write-Warning 'No onboarding report was generated.'
    return
}

# Prepare a manual-review checklist. No accounts are changed.
$onboardingReport = @(
    foreach ($employee in $eligibleEmployees) {
        [pscustomobject]@{
            EmployeeID             = $employee.EmployeeID
            FirstName              = $employee.FirstName
            LastName               = $employee.LastName
            Department              = $employee.Department
            Email                   = $employee.Email
            StartDate               = $employee.StartDate
            ValidationStatus        = $employee.ValidationStatus
            HRApprovalCheck         = 'Pending'
            IdentityVerification    = 'Pending'
            ManagerConfirmation     = 'Pending'
            AccessRequirementsCheck = 'Pending'
            AccountCreation         = 'Not performed - authorised review required'
        }
    }
)

$onboardingReport |
    Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nOnboarding review report generated." -ForegroundColor Green
Write-Host "Eligible employees: $($onboardingReport.Count)"
Write-Host "Output: $outputPath"
Write-Host "No user accounts were created or modified."

$onboardingReport |
    Format-Table EmployeeID, FirstName, LastName, Department, StartDate -AutoSize
