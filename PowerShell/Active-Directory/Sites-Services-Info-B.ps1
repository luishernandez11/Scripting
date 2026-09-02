cd\
clear-host

# Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Gathers detailed Active Directory Sites and Services topology metrics.
.DESCRIPTION
    This script queries Active Directory to compile a comprehensive report of 
    all Sites, associated Subnets, Domain Controllers, Operating Systems, 
    Global Catalogs, IP addresses, Bridgehead servers, Site Links (including Cost & Interval), 
    and the Inter-Site Topology Generator (ISTG).
.OUTPUTS
    Outputs an array of custom PSCustomObjects. Can be piped to Out-GridView or Export-Csv.
#>

# Ensure Active Directory Module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "The Active Directory PowerShell module is required. Please install RSAT."
    exit
}

Write-Progress -Activity "AD Topology Audit" -Status "Collecting base forest metadata..."

# 1. Fetch data up front using valid property mappings and .NET Forest instance methods
$Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$AllSiteLinks = Get-ADReplicationSiteLink -Filter * -Properties Cost, ReplicationFrequencyInMinutes, SitesIncluded
$AllSubnets   = Get-ADReplicationSubnet -Filter * -Properties Site
$AllDCs       = Get-ADDomainController -Filter * -Properties OperatingSystem

# GetAllSites() must be called as an instance method from the retrieved Forest object
$NetSites = $Forest.Sites

$Report = foreach ($NetSite in $NetSites) {
    $SiteName = $NetSite.Name
    Write-Progress -Activity "AD Topology Audit" -Status "Processing Site: $SiteName"
    
    # 2. Extract Subnets linked to this specific site
    $SiteSubnets = ($AllSubnets | Where-Object { $_.Site -match "CN=$SiteName,CN=Sites," }).Name -join ", "
    if (-not $SiteSubnets) { $SiteSubnets = "None Assigned" }

    # 3. Find Domain Controllers matching this specific site
    $DCsInSite = $AllDCs | Where-Object { $_.Site -eq $SiteName }

    # 4. Resolve Site Links, Costs, and Replication Intervals
    $MatchedLinks = $AllSiteLinks | Where-Object { 
        ($_.SitesIncluded | Out-String) -match "CN=$SiteName,CN=Sites," 
    }
    
    $SiteLinkNames = ($MatchedLinks.Name) -join " | "
    $SiteLinkCosts = ($MatchedLinks.Cost) -join " | "
    $SiteLinkIntervals = ($MatchedLinks.ReplicationFrequencyInMinutes) -join " min | "
    if ($SiteLinkIntervals) { $SiteLinkIntervals += " min" }

    # 5. Identify Inter-Site Topology Generator (ISTG)
    $IstgServer = $NetSite.InterSiteTopologyGenerator.Name

    # 6. Identify Preferred Bridgehead Servers for this Site
    $Bridgeheads = @()
    foreach ($transport in $NetSite.PreferredInboundBridgeheadServers) {
        $Bridgeheads += $transport.Name
    }
    $BridgeheadList = ($Bridgeheads | Select-Object -Unique) -join ", "
    if (-not $BridgeheadList) { $BridgeheadList = "None (Managed by KCC)" }

    # 7. Iterate through each Domain Controller found inside this site
    if ($DCsInSite) {
        foreach ($DC in $DCsInSite) {
            # Check Global Catalog status
            $IsGC = $DC.IsGlobalCatalog -eq $true

            # Gather IP Addresses
            $IPAddresses = ($DC.IPv4Address, $DC.IPv6Address | Where-Object { $_ }) -join ", "

            # Build flat record output with custom column order
            [PSCustomObject]@{
                "Site Name"            = $SiteName
                "Domain Controller"    = $DC.HostName
                "Operating System"     = $DC.OperatingSystem
                "IP Address(es)"       = $IPAddresses
                "Site Link Name"       = $SiteLinkNames
                "Link Cost"            = $SiteLinkCosts
                "Replication Interval" = $SiteLinkIntervals
                "Is Global Catalog"    = $IsGC
                "ISTG Server"          = $IstgServer
                "Bridgehead Servers"   = $BridgeheadList
                "Associated Subnets"   = $SiteSubnets
            }
        }
    } else {
        # Edge Case: Administrative Site boundary exists but has no active DCs
        [PSCustomObject]@{
            "Site Name"            = $SiteName
            "Domain Controller"    = "Empty Site (No DCs)"
            "Operating System"     = "N/A"
            "IP Address(es)"       = "N/A"
            "Site Link Name"       = $SiteLinkNames
            "Link Cost"            = $SiteLinkCosts
            "Replication Interval" = $SiteLinkIntervals
            "Is Global Catalog"    = $false
            "ISTG Server"          = $IstgServer
            "Bridgehead Servers"   = $BridgeheadList
            "Associated Subnets"   = $SiteSubnets
        }
    }
}

Write-Progress -Activity "AD Topology Audit" -Completed

# Output directly to GridView for easy interaction
$Report | Out-GridView -Title "Active Directory Sites & Services Inventory"

# Uncomment the line below to seamlessly generate a report spreadsheet instead:
# $Report | Export-Csv -Path "C:\Temp\AD_Sites_Services_Report.csv" -NoTypeInformation -Encoding UTF-8
