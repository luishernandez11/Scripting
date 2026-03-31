Import-Module DnsServer
$DNSServer = "labdc01" #Enter your server name
$zones = Get-DnsServerZone -ComputerName $DNSServer | Where { $_.IsReverseLookUpZone -eq $False -and $_.ZoneType -eq "Primary" }

foreach ($item in $zones) 
{
	$zone = $item.zonename
	$results = Get-DnsServerResourceRecord $zone -ComputerName $DNSServer | select @{ n = 'ZoneName'; e = { $zone } }, HostName, RecordType, @{
		n = 'RecordData';
		e = {
			if ($_.RecordType -eq 'A') { $_.RecordData.IPv4Address.IPAddressToString }
			elseIf ($_.RecordType -eq 'AAAA') { $_.RecordData.IPv6Address.IPAddressToString }
			elseIf ($_.RecordType -eq 'CNAME') { $_.RecordData.HostNameAlias }
			elseIf ($_.RecordType -eq 'NS') { $_.RecordData.NameServer }
			elseIf ($_.RecordType -eq 'SOA') { 'SOA Record' }
			elseIf ($_.RecordType -eq 'SRV') { 'SRV Record' }
			elseIf ($_.RecordType -eq 'TXT') { 'TXT Record' }
			Else { $_.RecordData.NameServer.ToUpper() }
		}
	}
	#Adjust pattyh as appropriate.
        if (Test-Path "C:\Windows\Temp\_Tools\$zone.csv") { remove-item "C:\Windows\Temp\_Toolsp\$zone.csv" }
	$results | Export-Csv -NoTypeInformation "C:\Windows\Temp\_Tools\$zone.csv"
}