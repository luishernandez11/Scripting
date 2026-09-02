cd\
clear-host

Import-Module ActiveDirectory

# ============================================================
# Active Directory OU Structure Creator
# ============================================================

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       Active Directory OU Structure Creator" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Function: Create OU if it does not already exist
# ============================================================

function New-OUIfMissing {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $existingOU = Get-ADOrganizationalUnit `
        -Filter "Name -eq '$Name'" `
        -SearchBase $Path `
        -SearchScope OneLevel `
        -ErrorAction SilentlyContinue

    if ($existingOU) {
        Write-Host "    [EXISTS]  $Name" -ForegroundColor Yellow

        return $existingOU
    }

    try {
        $newOU = New-ADOrganizationalUnit `
            -Name $Name `
            -Path $Path `
            -ProtectedFromAccidentalDeletion $true `
            -PassThru `
            -ErrorAction Stop

        Write-Host "    [CREATED] $Name" -ForegroundColor Green

        return $newOU
    }
    catch {
        Write-Host "    [ERROR]   Failed to create $Name" -ForegroundColor Red
        Write-Host "             $($_.Exception.Message)" -ForegroundColor Red

        return $null
    }
}

# ============================================================
# Get Active Directory Domain
# ============================================================

try {
    $domain = Get-ADDomain -ErrorAction Stop
}
catch {
    Write-Host "Unable to connect to Active Directory." -ForegroundColor Red
    Write-Host "Make sure the Active Directory PowerShell module is installed." -ForegroundColor Red
    exit 1
}

$domainDN = $domain.DistinguishedName

Write-Host "Active Directory Domain: $($domain.DNSRoot)" -ForegroundColor Cyan
Write-Host "Domain DN: $domainDN" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Prompt for Company Name
# ============================================================

do {
    $companyName = Read-Host "Enter Company Name (Top-Level OU)"

    if ([string]::IsNullOrWhiteSpace($companyName)) {
        Write-Host "Company Name cannot be blank." -ForegroundColor Red
    }

} while ([string]::IsNullOrWhiteSpace($companyName))

# ============================================================
# Create Top-Level OU
# ============================================================

Write-Host ""
Write-Host "Creating Top-Level OU..." -ForegroundColor Cyan

$topOU = New-OUIfMissing `
    -Name $companyName `
    -Path $domainDN

if ($null -eq $topOU) {
    Write-Host "Unable to create or locate the Company OU. Exiting." -ForegroundColor Red
    exit 1
}

$topOUDN = $topOU.DistinguishedName

Write-Host ""
Write-Host "Top-Level OU: $companyName" -ForegroundColor Green
Write-Host ""

# ============================================================
# Define Third-Level and Fourth-Level OU Structure
# ============================================================

$OUStructure = @{
    "Users" = @(
        "Employees"
        "Consultants"
    )

    "Desktops" = @(
        "On-Prem-Desktops"
        "Cloud-Desktops"
    )

    "Servers" = @(
        "On-Prem-Servers"
        "Cloud-Servers"
    )
}

# ============================================================
# Prompt for Four Time Zone / Second-Level OUs
# ============================================================

for ($i = 1; $i -le 4; $i++) {

    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Second-Level OU #$i" -ForegroundColor Cyan
    Write-Host "Enter the Time Zone / Location OU name." -ForegroundColor Gray
    Write-Host "Leave blank to SKIP this OU." -ForegroundColor Gray
    Write-Host ""

    $secondLevelName = Read-Host "Time Zone / OU #$i"

    # --------------------------------------------------------
    # Skip if blank
    # --------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($secondLevelName)) {

        Write-Host ""
        Write-Host "[SKIPPED] Second-Level OU #$i" -ForegroundColor DarkYellow
        Write-Host ""

        continue
    }

    # --------------------------------------------------------
    # Create Second-Level OU
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Creating Second-Level OU: $secondLevelName" -ForegroundColor Cyan

    $secondLevelOU = New-OUIfMissing `
        -Name $secondLevelName `
        -Path $topOUDN

    if ($null -eq $secondLevelOU) {
        Write-Host "Unable to create $secondLevelName. Skipping its child OUs." -ForegroundColor Red
        continue
    }

    $secondLevelOUDN = $secondLevelOU.DistinguishedName

    # --------------------------------------------------------
    # Create Third-Level OUs
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "  Creating third-level OUs..." -ForegroundColor Cyan

    foreach ($thirdLevelName in $OUStructure.Keys) {

        $thirdLevelOU = New-OUIfMissing `
            -Name $thirdLevelName `
            -Path $secondLevelOUDN

        if ($null -eq $thirdLevelOU) {
            Write-Host "    Unable to create $thirdLevelName. Skipping children." -ForegroundColor Red
            continue
        }

        $thirdLevelOUDN = $thirdLevelOU.DistinguishedName

        # ----------------------------------------------------
        # Create Fourth-Level OUs
        # ----------------------------------------------------

        foreach ($fourthLevelName in $OUStructure[$thirdLevelName]) {

            New-OUIfMissing `
                -Name $fourthLevelName `
                -Path $thirdLevelOUDN | Out-Null
        }
    }

    Write-Host ""
    Write-Host "Completed: $secondLevelName" -ForegroundColor Green
    Write-Host ""
}

# ============================================================
# Display Final OU Structure
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "              OU CREATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Final OU Structure:" -ForegroundColor Cyan
Write-Host ""

Write-Host $companyName -ForegroundColor White

$secondLevelOUs = Get-ADOrganizationalUnit `
    -Filter * `
    -SearchBase $topOUDN `
    -SearchScope OneLevel `
    -ErrorAction SilentlyContinue

foreach ($secondLevelOU in $secondLevelOUs) {

    Write-Host "├── $($secondLevelOU.Name)" -ForegroundColor White

    $thirdLevelOUs = Get-ADOrganizationalUnit `
        -Filter * `
        -SearchBase $secondLevelOU.DistinguishedName `
        -SearchScope OneLevel `
        -ErrorAction SilentlyContinue

    foreach ($thirdLevelOU in $thirdLevelOUs) {

        Write-Host "│   ├── $($thirdLevelOU.Name)" -ForegroundColor Gray

        $fourthLevelOUs = Get-ADOrganizationalUnit `
            -Filter * `
            -SearchBase $thirdLevelOU.DistinguishedName `
            -SearchScope OneLevel `
            -ErrorAction SilentlyContinue

        foreach ($fourthLevelOU in $fourthLevelOUs) {
            Write-Host "│   │   ├── $($fourthLevelOU.Name)" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Done!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
