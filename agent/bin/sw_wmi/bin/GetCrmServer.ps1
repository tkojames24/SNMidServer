Param(
$username,
$password
)
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force;
$cred = New-Object System.Management.Automation.PSCredential ($username, $secpasswd);
Add-PSSnapin Microsoft.Crm.PowerShell;
Get-CrmServer -DwsServerUrl http://localhost -credential $cred | select Name, Roles |ConvertTo-Csv