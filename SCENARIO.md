
#  PowerShell Employee Account Lifecycle Automation

## 1. Business Scenario

Mahlangu Business Solutions is a fictional company that uses an IT Support team to help manage employee account administration.

The Human Resources (HR) department provides employee information in CSV files when employees join the company or leave their positions.

The IT Support team needs a consistent way to validate these records, identify incomplete information, detect duplicate employee IDs, and prepare account administration reports.

The initial version of this project will use fictional employee records and simulate the workflow. It will not create, disable, modify, or delete real user accounts.

## 2. Business Problem

Processing employee records manually can introduce errors and delays.

Examples include:

- Employee records with missing first names, surnames, departments, or employee IDs.
- Duplicate employee IDs that could cause records to be processed incorrectly.
- Invalid or incomplete email addresses.
- Onboarding records that need additional information before they can be processed.
- Offboarding requests that need a checklist and review by authorised IT staff.

These issues can make account administration less consistent and increase the risk of mistakes.

## 3. Proposed Solution

Develop a PowerShell automation tool that imports structured CSV files, validates employee records, reports data quality issues, and prepares onboarding and offboarding documentation.

The tool will be developed and tested locally before any Active Directory integration is considered.

## 4. Project Objectives

- Use PowerShell 5.1-compatible scripts to process employee records.
- Import CSV data using `Import-Csv`.
- Validate required employee fields.
- Detect duplicate employee IDs.
- Identify invalid or missing information.
- Generate clear validation reports.
- Prepare onboarding summaries and offboarding checklists.
- Include error handling and useful logging.
- Test normal and invalid input scenarios.
- Use Git and GitHub to track and publish the project.

## 5. Fictional Employee Scenarios

### Scenario A: New employee

Lerato Mthembu joins the Finance department. HR submits her employee information, and IT needs to validate the record before preparing an onboarding report.

### Scenario B: Missing information

Thabo Ndlovu's HR record does not contain a department. The script should flag the record instead of treating it as ready for processing.

### Scenario C: Duplicate employee ID

Two records contain the same employee ID. The script should identify the duplicate and report the affected records for review.

### Scenario D: Employee departure

Sipho Khumalo leaves the company. The script should prepare an offboarding checklist for authorised IT staff rather than automatically disabling or deleting an account.

All company details and employee information in this project are fictional and intended for demonstration and testing.

## 6. Planned Workflow

1. Import the HR CSV file.
2. Validate the file structure and required fields.
3. Check for missing values, invalid data, and duplicate employee IDs.
4. Separate valid records from records requiring review.
5. Generate a validation report.
6. Prepare onboarding or offboarding reports where appropriate.
7. Review test results and document known limitations.

## 7. Technology Stack

- **Scripting language:** Windows PowerShell 5.1
- **Editor:** Visual Studio Code
- **Data interchange:** CSV and `Import-Csv`
- **Version control:** Git
- **Repository hosting:** GitHub
- **Target integration:** Windows Active Directory Domain Services (AD DS), in an authorised lab at a later stage

## 8. Safety and Scope

The initial version is a local simulation that uses fictional data.

It will not connect to a production directory or make changes to real employee accounts. Any future AD DS integration will require an authorised lab, appropriate permissions, validation, and safeguards before account changes are permitted.

## 9. Expected Outcome

The finished project should demonstrate how PowerShell can reduce repetitive data-checking work, make employee records easier to review, and help IT Support prepare consistent account administration documentation.

The project will include scripts, sample data, test cases, generated reports, and instructions for running the solution.
