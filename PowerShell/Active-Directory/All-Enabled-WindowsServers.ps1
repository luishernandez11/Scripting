clear-host

$MyReport = "C:\Temp\AD_Enabled_Servers_Report.csv"

$Hosts = Get-ADComputer -Filter 'OperatingSystem -notlike "*Server*" -and Enabled -eq $true' `
    -Properties OperatingSystem, IPv4Address, LastLogonDate, CanonicalName | 
    Select-Object @{Name="Server Name"; Expression={$_.Name}}, 
                  @{Name="Operating System"; Expression={$_.OperatingSystem}}, 
                  @{Name="IP Address"; Expression={$_.IPv4Address}}, 
                  @{Name="Last Logon Date"; Expression={$_.LastLogonDate}}, 
                  @{Name="AD Path"; Expression={$_.CanonicalName}}

if ($Hosts) {
    $Hosts | Export-Csv -Path $MyReport -NoTypeInformation -Encoding UTF8
    Write-Host "Success! Report created at: $MyReport" -ForegroundColor Green
    Write-Host "Total enabled servers found: $($Hosts.Count)" -ForegroundColor Cyan
} else {
    Write-Host "No enabled Windows Servers were found in Active Directory." -ForegroundColor Yellow
}
