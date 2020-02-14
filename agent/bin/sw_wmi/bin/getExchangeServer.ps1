
$username = $Args[0]
$password = ConvertTo-SecureString $Args[1] -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
$hostname = $Args[2]
$url = "http://" + $hostname + "/PowerShell/"
clear-history
$error.Clear()
$errorActionPreference = "SilentlyContinue"
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $url -Credential $credential -Authentication Kerberos -ErrorAction Stop
Import-PSSession $Session -ErrorAction SilentlyContinue -AllowClobber

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

# For CAS and Hub identification
if($Args[3] -eq '1' )
{
# Create the temp files name
$path = $env:temp
$number = get-random
$xmlpath = $path+"\"+$number+"exchange_pwrshell_output.xml"
Get-ExchangeServer  -status -Identity $hostname| select CurrentDomainControllers | export-clixml $xmlpath
Get-MailboxServer | select name,DatabaseAvailabilityGroup | convertto-csv -delimiter ':' | out-file $path\mailboxcluster.txt
Get-ExchangeServer  -status | select Fqdn,IsMailboxServer,IsHubTransportServer,IsClientAccessServer,DistinguishedName,edition,AdminDisplayVersion | convertto-csv -delimiter ':'
echo "Path: $path"
echo "XMLpath: $xmlpath"
}
# For CAS connection section
if($Args[3] -eq '2' )
{
  $path = $env:temp
  Get-ExchangeServer  -status | select Fqdn,IsMailboxServer,IsHubTransportServer,IsClientAccessServer,DistinguishedName,edition,AdminDisplayVersion | convertto-csv -delimiter ':'
  Get-MailboxServer | select name,DatabaseAvailabilityGroup | convertto-csv -delimiter ':' | out-file $path\mailboxcluster.txt
  echo "Path: $path"
}
# For Mailbox identification
if($Args[3] -eq '3' )
{
  # Create the temp files name
  $path = $env:temp
  $number = get-random
  $xmlpath = $path+"\"+$number+"exchange_pwrshell_output.xml"
  $filepath=$path+"\"+$number+"mailboxinfo.txt"
  $storagepath=$path+"\"+$number+"storage.csv"
  # Get the domain controllers and export to xml
  Get-ExchangeServer  -status -Identity $hostname| select CurrentDomainControllers | export-clixml $xmlpath
  # Create list of users that uses the mailbox
  get-mailbox -server $hostname -ErrorAction SilentlyContinue | Get-MailboxPermission -ErrorAction SilentlyContinue | where {$_.user.tostring() -notlike "NT AUTHORITY*"} | select user -unique | ft -HideTableHeaders | out-file $filepath
  # Count the mailboxes on the current mailbox server
  $count = get-mailbox -server $hostname | group-object -property:ServerName | foreach {$_.count.tostring()}
  # Append the number of mailboxes to the text file
  #echo "count:$count" | out-file -Append $filepath
  $string ="count:$count" 
  $version = Get-ExchangeServer  -status -Identity $hostname| foreach {$_.AdminDisplayVersion.tostring()}
 if ( $version -like "Version 14*")
{
  $string = $string + "CAL:false"
}
else
{
  # Get the license name for enterprise CAL
  $license_name = Get-ExchangeServerAccessLicense -ErrorAction SilentlyContinue | where {$_.licensename.tostring() -like "*Enterprise CAL"} | foreach {$_.licensename.tostring()}
  # Get the number of enterprise CAL's in use
  $enter = Get-ExchangeServerAccessLicenseUser -LicenseName $license_name | Measure-Object | foreach { $_.count.tostring()}
  if($enter -eq "0")
  {
    #echo "CAL:false" | out-file -Append $filepath
   $string = $string + "CAL:false"
  }
  else
  {
    $string = $string + "CAL:true"
  } 
}
  $cluster = Get-MailboxServer -Identity $hostname | foreach{ $_.DatabaseAvailabilityGroup.tostring()} | Get-DatabaseAvailabilityGroup -status| select OperationalServers| fl
  echo $string | out-file -Append $filepath
  echo $cluster | out-file -Append $filepath
  Get-MailboxDatabase | select LogFolderPath,EdbFilePath,TemporaryDataFolderPath | convertto-csv -delimiter '@'| out-file $storagepath 
  Get-ExchangeServer  -status | select Fqdn,IsMailboxServer,IsHubTransportServer,IsClientAccessServer,DistinguishedName,edition,AdminDisplayVersion | convertto-csv -delimiter ':' | Out-Default
  echo "Path: $xmlpath" | Out-Default
  echo "Mailbox file: $filepath" | Out-Default
  echo "Storage file: $storagepath" | Out-Default
  }