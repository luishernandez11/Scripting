# Define the path to the file containing server names or IPs
$serverListPath = "C:\windows\temp\servers.txt"

# Check if the file exists
if (-Not (Test-Path $serverListPath)) {
    Write-Host "Server list file not found at $serverListPath" -ForegroundColor Red
    exit
}

# Read the server names from the file
$servers = Get-Content $serverListPath

# Output file for results
$outputFile = "C:\windows\temp\Network_Report.txt"

# Initialize an array to store results
$results = @()

foreach ($server in $servers) {
    Write-Host "Checking $server ..." -ForegroundColor Cyan

    # Check if the server is reachable
    if (Test-Connection -ComputerName $server -Count 2 -Quiet) {
        try {
            # Get IP address
            $ipAddresses = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $server | 
                           Where-Object { $_.IPEnabled -eq $true } | 
                           Select-Object -ExpandProperty IPAddress

            # Get DNS servers
            $dnsServers = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $server | 
                          Where-Object { $_.IPEnabled -eq $true } | 
                          Select-Object -ExpandProperty DNSServerSearchOrder
            
            # Format results
            $ipString = if ($ipAddresses) { $ipAddresses -join ", " } else { "N/A" }
            $dnsString = if ($dnsServers) { $dnsServers -join ", " } else { "N/A" }

            # Store in an array
            $results += [PSCustomObject]@{
                Server    = $server
                IPAddress = $ipString
                DNSServers = $dnsString
            }

        } catch {
            Write-Host "Error retrieving data from $server" -ForegroundColor Yellow
            $results += [PSCustomObject]@{
                Server    = $server
                IPAddress = "Error"
                DNSServers = "Error"
            }
        }
    } else {
        Write-Host "$server is unreachable!" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Server    = $server
            IPAddress = "Unreachable"
            DNSServers = "Unreachable"
        }
    }
}

# Export results to a CSV file
$results | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Results saved to $outputFile" -ForegroundColor Green