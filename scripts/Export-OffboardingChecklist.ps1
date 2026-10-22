
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Locate the project files.
$projectRoot = Split-Path -Parent $PSScriptRoot
$validationScript = Join-Path $PSScriptRoot 'Import-EmployeeData.ps1'
$validationReport = Join-Path $projectRoot 'reports\employee-validation-report.csv'
$outputPath = Join-Path $projectRoot 'reports\offboarding-checklist.csv'

# Verify that the validation script exists.
if (-not (Test-Path -LiteralPath $validationScript -PathType Leaf)) {
    throw "Validation script not found: $validationScript"
}

# Refresh validation results before preparing the checklist.
& $validationScript | Out-Null

if (-not (Test-Path -LiteralPath $validationReport -PathType Leaf)) {
    throw "Employee validation report was not generated."
}

$employees = @(Import-Csv -LiteralPath $validationReport)

# Include only offboarding records that passed the current validation rules.
$eligibleEmployees = @(
    $employees | Where-Object {
        $_.EmploymentStatus -eq 'Offboarding' -and
        $_.ValidationStatus -eq 'ReadyForReview'
    }
)

if ($eligibleEmployees.Count -eq 0) {
    Write-Warning 'No eligible offboarding records are ready for review.'
    Write-Warning 'No offboarding checklist was generated.'
    return
}

# Prepare a checklist for manual review.
$checklist = @(
    foreach ($employee in $eligibleEmployees) {
        [pscustomobject]@{
            EmployeeID                = $employee.EmployeeID
            FirstName                 = $employee.FirstName
            LastName                  = $employee.LastName
            Department                = $employee.Department
            Email                     = $employee.Email
            PlannedEndDate            = $employee.EndDate
            ValidationStatus          = $employee.ValidationStatus
            HRApproval                = 'Pending'
            ManagerConfirmation       = 'Pending'
            LastWorkingDayConfirmed   = 'Pending'
            CompanyAssetsReturned     = 'Pending'
            DataHandoverReviewed      = 'Pending'
            MailboxAndDataRetention   = 'Pending'
            AccessRemovalReview       = 'Pending'
            AccountDisablement        = 'Not performed - authorised action required'
            ChecklistStatus           = 'Open - manual review required'
        }
    }
)

# Export the checklist.
$checklist |
    Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nOffboarding checklist generated." -ForegroundColor Green
Write-Host "Eligible employees: $($checklist.Count)"
Write-Host "Output: $outputPath"
Write-Host "No user accounts were disabled or modified."

$checklist |
    Format-Table EmployeeID, FirstName, LastName, PlannedEndDate, ChecklistStatus -AutoSize
