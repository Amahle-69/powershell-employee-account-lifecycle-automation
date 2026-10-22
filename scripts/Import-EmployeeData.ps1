
[CmdletBinding()]
param(
    [string]$CsvPath,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

# Locate project folders.
$projectRoot = Split-Path -Parent $PSScriptRoot

# Use the normal project CSV unless a test file is supplied.
if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $inputPath = Join-Path $projectRoot 'data\employees.csv'
}
else {
    $inputPath = $CsvPath
}

# Use the normal report unless a separate destination is supplied.
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportDirectory = Join-Path $projectRoot 'reports'
    $outputPath = Join-Path $reportDirectory 'employee-validation-report.csv'
}
else {
    $outputPath = $ReportPath
    $reportDirectory = Split-Path -Parent $outputPath
}

# Check that the input file exists.
if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
    throw "Employee CSV file not found: $inputPath"
}

# Import employee records.
$employees = @(Import-Csv -LiteralPath $inputPath -ErrorAction Stop)

if ($employees.Count -eq 0) {
    throw "The employee CSV contains no records."
}

# Verify the required CSV columns.
$expectedHeaders = @(
    'EmployeeID',
    'FirstName',
    'LastName',
    'Department',
    'Email',
    'EmploymentStatus',
    'StartDate',
    'EndDate'
)

$actualHeaders = @($employees[0].PSObject.Properties.Name)
$missingHeaders = @(
    $expectedHeaders | Where-Object { $actualHeaders -notcontains $_ }
)

if ($missingHeaders.Count -gt 0) {
    throw "Missing CSV columns: $($missingHeaders -join ', ')"
}

# Find duplicate employee IDs, ignoring case and surrounding spaces.
$duplicateIDs = @(
    $employees |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.EmployeeID)
        } |
        Group-Object -Property {
            ([string]$_.EmployeeID).Trim().ToUpperInvariant()
        } |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { $_.Name }
)

$results = @()

foreach ($employee in $employees) {
    $issues = @()

    # Validate required fields.
    foreach ($field in @(
        'EmployeeID',
        'FirstName',
        'LastName',
        'Department',
        'Email',
        'EmploymentStatus',
        'StartDate'
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$employee.$field)) {
            $issues += "Missing $field"
        }
    }

    # Check the email format.
    if (-not [string]::IsNullOrWhiteSpace([string]$employee.Email)) {
        $emailPattern = '^[^@\s]+@[^@\s]+\.[^@\s]+$'

        if ($employee.Email -notmatch $emailPattern) {
            $issues += 'Invalid email format'
        }
    }

    # Check for duplicate employee IDs.
    $normalizedID = ([string]$employee.EmployeeID).Trim().ToUpperInvariant()

    if ($duplicateIDs -contains $normalizedID -and $normalizedID -ne '') {
        $issues += 'Duplicate EmployeeID'
    }

    # Validate the start date using yyyy-MM-dd.
    $startDateValue = $null
    $startDateIsValid = $false

    if (-not [string]::IsNullOrWhiteSpace([string]$employee.StartDate)) {
        try {
            $startDateValue = [datetime]::ParseExact(
                [string]$employee.StartDate,
                'yyyy-MM-dd',
                [Globalization.CultureInfo]::InvariantCulture
            )

            $startDateIsValid = $true
        }
        catch {
            $issues += 'StartDate must use yyyy-MM-dd format'
        }
    }

    # Validate the employment status and end date.
    if ($employee.EmploymentStatus -eq 'NewStarter') {
        if (-not [string]::IsNullOrWhiteSpace([string]$employee.EndDate)) {
            $issues += 'EndDate should be blank for NewStarter'
        }
    }
    elseif ($employee.EmploymentStatus -eq 'Offboarding') {
        if ([string]::IsNullOrWhiteSpace([string]$employee.EndDate)) {
            $issues += 'Missing EndDate for Offboarding'
        }
        else {
            try {
                $endDateValue = [datetime]::ParseExact(
                    [string]$employee.EndDate,
                    'yyyy-MM-dd',
                    [Globalization.CultureInfo]::InvariantCulture
                )

                if (
                    $startDateIsValid -and
                    $endDateValue -lt $startDateValue
                ) {
                    $issues += 'EndDate is earlier than StartDate'
                }
            }
            catch {
                $issues += 'EndDate must use yyyy-MM-dd format'
            }
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace(
        [string]$employee.EmploymentStatus
    )) {
        $issues += 'EmploymentStatus must be NewStarter or Offboarding'
    }

    # Prepare a review status without changing any accounts.
    if ($issues.Count -gt 0) {
        $validationStatus = 'NeedsReview'
        $issuesText = $issues -join '; '
    }
    else {
        $validationStatus = 'ReadyForReview'
        $issuesText = 'None'
    }

    $results += [pscustomobject]@{
        EmployeeID       = $employee.EmployeeID
        FirstName        = $employee.FirstName
        LastName         = $employee.LastName
        Department       = $employee.Department
        Email            = $employee.Email
        EmploymentStatus = $employee.EmploymentStatus
        StartDate        = $employee.StartDate
        EndDate          = $employee.EndDate
        ValidationStatus = $validationStatus
        Issues           = $issuesText
    }
}

# Create the reports folder if it does not exist.
if (-not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory | Out-Null
}

# Export validation results to CSV.
$results | Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8

# Display a summary and the validation results.
$needsReviewCount = @(
    $results | Where-Object { $_.ValidationStatus -eq 'NeedsReview' }
).Count

$readyCount = @(
    $results | Where-Object { $_.ValidationStatus -eq 'ReadyForReview' }
).Count

Write-Host "`nEmployee validation completed." -ForegroundColor Green
Write-Host "Records imported: $($employees.Count)"
Write-Host "Ready for review: $readyCount"
Write-Host "Needs review: $needsReviewCount"
Write-Host "Report saved to: $outputPath"

$results |
    Format-Table EmployeeID, FirstName, LastName, ValidationStatus, Issues -Wrap -AutoSize
