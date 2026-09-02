cd\
clear-host

# Ensure the Active Directory module is loaded
Import-Module ActiveDirectory

# Retrieve all Active Directory sites using the .NET DirectoryServices context
$Context = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Name)
$ADSites = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($Context).Sites

# Cache all AD Replication Site Links to prevent spamming the domain controller in the loop
$AllSiteLinks = Get-ADReplicationSiteLink -Filter *

$Report = @()

foreach ($Site in $ADSites) {
    # 1. Get subnets associated with this specific site
    $Subnets = Get-ADReplicationSubnet -Filter * | Where-Object { $_.Site -match $Site.Name }
    $SubnetList = if ($Subnets) { ($Subnets.Name) -join ", " } else { "No Subnets Assigned" }

    # 2. Identify the Inter-Site Topology Generator (ISTG) server for this site
    $IstgServer = $Site.InterSiteTopologyGenerator -replace ".*CN=NTDS Settings,CN=|,CN=Servers,CN=.*"

    # 3. Retrieve preferred Bridgehead Servers configured for this site
    $Bridgeheads = $Site.BridgeheadServers | ForEach-Object { $_.Name }

    # 4. Find Site Links that include this site, extracting Cost and Replication Intervals
    $MatchedLinks = $AllSiteLinks | Where-Object { $_.SitesIncluded -contains $Site.Name }
    
    if ($MatchedLinks) {
        $SiteLinkNames = ($MatchedLinks.Name) -join " | "
        $SiteLinkCosts = ($MatchedLinks.Cost) -join " | "
        $SiteLinkIntervals = ($MatchedLinks.ReplicationFrequencyInMinutes | ForEach-Object { "$_ min" }) -join " | "
    } else {
        $SiteLinkNames = "None (Isolated Site)"
        $SiteLinkCosts = "N/A"
        $SiteLinkIntervals = "N/A"
    }

    # 5. Get all Domain Controllers operating inside this site
    $DCsInSite = Get-ADDomainController -Filter * | Where-Object { $_.Site -eq $Site.Name }

    if ($DCsInSite) {
        foreach ($DC in $DCsInSite) {
            $ShortDCName = $DC.Name

            # Evaluate Role Statuses
            $IsISTG = if ($ShortDCName -eq $IstgServer) { $true } else { $false }
            $IsBridgehead = if ($Bridgeheads -contains $DC.HostName -or $Bridgeheads -contains $ShortDCName) { $true } else { $false }

            $Report += [PSCustomObject]@{
                "AD Site Name"      = $Site.Name
                "Site Subnets"      = $SubnetList
                "Associated Links"  = $SiteLinkNames
                "Link Cost"         = $SiteLinkCosts
                "Repl Interval"     = $SiteLinkIntervals
                "Server Name"       = $DC.HostName
                "IP Address"        = $DC.IPv4Address
                "Is ISTG?"          = $IsISTG
                "Is Bridgehead?"    = $IsBridgehead
                "OS Version"        = $DC.OperatingSystem
            }
        }
    } else {
        # Catch empty / template sites
        $Report += [PSCustomObject]@{
            "AD Site Name"      = $Site.Name
            "Site Subnets"      = $SubnetList
            "Associated Links"  = $SiteLinkNames
            "Link Cost"         = $SiteLinkCosts
            "Repl Interval"     = $SiteLinkIntervals
            "Server Name"       = "No DCs in site"
            "IP Address"        = "N/A"
            "Is ISTG?"          = "N/A"
            "Is Bridgehead?"    = "N/A"
            "OS Version"        = "N/A"
        }
    }
}

# Display the output cleanly as a grid in the console
$Report | Format-Table -AutoSize

# Optional: Uncomment the line below to export the data to a CSV document
# $Report | Export-Csv -Path "C:\Temp\AD_Complete_Topology_Report.csv" -NoTypeInformation
