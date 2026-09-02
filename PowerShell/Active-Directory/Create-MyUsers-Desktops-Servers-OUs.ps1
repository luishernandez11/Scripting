cd\
clear-host

Import-Module ActiveDirectory

# Get the current AD domain
$domainDN = (Get-ADDomain).DistinguishedName

Write-Host "Domain: $domainDN" -ForegroundColor Cyan
Write-Host ""

# Define the OU structure
$ouStructure = @{
    "MyUsers" = @(
        "On-Prem-Desktops"
        "Cloud-Desktops"
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

foreach ($parentOU in $ouStructure.Keys) {

    # Check whether the parent OU exists
    $parent = Get-ADOrganizationalUnit `
        -Filter "Name -eq '$parentOU'" `
        -SearchBase $domainDN `
        -SearchScope OneLevel `
        -ErrorAction SilentlyContinue

    if ($null -eq $parent) {

        Write-Host "Creating: OU=$parentOU,$domainDN" -ForegroundColor Green

        New-ADOrganizationalUnit `
            -Name $parentOU `
            -Path $domainDN `
            -ProtectedFromAccidentalDeletion $true

        # Get the newly created OU
        $parent = Get-ADOrganizationalUnit `
            -Filter "Name -eq '$parentOU'" `
            -SearchBase $domainDN `
            -SearchScope OneLevel
    }
    else {
        Write-Host "Already exists: OU=$parentOU,$domainDN" -ForegroundColor Yellow
    }

    # Create child OUs
    foreach ($childOU in $ouStructure[$parentOU]) {

        $child = Get-ADOrganizationalUnit `
            -Filter "Name -eq '$childOU'" `
            -SearchBase $parent.DistinguishedName `
            -SearchScope OneLevel `
            -ErrorAction SilentlyContinue

        if ($null -eq $child) {

            Write-Host "  Creating: OU=$childOU,$($parent.DistinguishedName)" -ForegroundColor Green

            New-ADOrganizationalUnit `
                -Name $childOU `
                -Path $parent.DistinguishedName `
                -ProtectedFromAccidentalDeletion $true
        }
        else {
            Write-Host "  Already exists: OU=$childOU,$($parent.DistinguishedName)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "OU structure creation complete." -ForegroundColor Cyan