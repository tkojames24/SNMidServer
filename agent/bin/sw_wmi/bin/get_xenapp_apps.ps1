param(
	  $Path,
	  [switch]$XA5
	  )
 
	  
$erroractionpreference = "SilentlyContinue" #"Stop" "Inquire"

## Add Citrix cmdlets
Add-PSSnapin Citrix* 
Set-ExecutionPolicy RemoteSigned
###########################################################################################################
##                        Export XenApp Applications
###########################################################################################################

function XAExport
{	
	$XAAppArray = @{}
	
	$XAApps = Get-XAApplicationReport * | ?{$_.FolderPath.Contains($Path)}
	
	if($XAApps.length -le 0)
		{
		$XAApps = Get-XAApplicationReport * | ?{$Path.Contains($_.FolderPath) -or $Path.Contains($_.DisplayName)}
		}
		
	foreach($XAApp in $XAApps)
	{
		## Retrieve CTP v3 cmdlet specific data that is different from XenApp 6 PowerShell SDK
		If ($XA5 -eq $True)
		{							
				If ($($XAApp.ApplicationType) -eq "ServerInstalled" -or $($XAApp.ApplicationType) -eq "StreamedToClientOrInstalled" -or $($XAApp.ApplicationType) -eq "StreamedToServer" -or $($XAApp.ApplicationType) -eq "StreamedToClientOrStreamedToServer" -or $($XAApp.ApplicationType) -eq "ServerDesktop")
				{
					$XAServerNames = Get-xaserver -BrowserName $($XAApp.browsername) | Select-Object $_.ServerName
					$XAServer = [string]::join(",",$XAServerNames)
					$ServerNames = '"' + $XAServer + '"'
				}
				Else
				{ 
					$ServerNames = "localhost"
				}
			
			If ($($XAApp.CommandLineExecutable) -like '"*')
				{
				$XACommandLine = '"' + $($XAApp.CommandLineExecutable) + " " + $($XAApp.CommandLineArguments)
				}
			Else
				{
				$XACommandLine = $($XAApp.CommandLineExecutable) + " " + $($XAApp.CommandLineArguments) 
				}

			If ($($XAApp.ContentAddress) -like '"*')
				{
				$XAContent = '"' + $($XAApp.ContentAddress)
				}
			Else
				{
				$XAContent = $($XAApp.ContentAddress) 
				}				
		}
		Else
		{				
		If ($($XAApp.ApplicationType) -eq "ServerInstalled" -or $($XAApp.ApplicationType) -eq "StreamedToClientOrInstalled" -or $($XAApp.ApplicationType) -eq "StreamedToServer" -or $($XAApp.ApplicationType) -eq "StreamedToClientOrStreamedToServer" -or $($XAApp.ApplicationType) -eq "ServerDesktop")
				{
					$XAServerNames = Get-xaapplication -BrowserName $($XAApp.browsername) | Get-xaserver | Select-Object $_.ServerName
					$XAServer = [string]::join(",",$XAServerNames)
					$ServerNames = '"' + $XAServer + '"'
				}
				Else
				{ 
					$ServerNames = "localhost"
				}		
			
			If ($($XAApp.CommandLineExecutable) -like '"*')
				{
				$XACommandLine = '"' + $($XAApp.CommandLineExecutable)
				}
			Else
				{
				$XACommandLine = $($XAApp.CommandLineExecutable)
				}

			If ($($XAApp.ContentAddress) -like '"*')
				{
				$XAContent = '"' + $($XAApp.ContentAddress)
				}
			Else
				{
				$XAContent = $($XAApp.ContentAddress) 
				}
		}
		
				Write-Host "$($XAApp.FolderPath)/$($XAApp.DisplayName)##$($XAApp.BrowserName)##$($XAApp.Enabled)##$($XAApp.ApplicationType)##$($ServerNames)##$($XAContent) $($XACommandLine)"
	}	
}

If ($Path -eq "" -or $Path -eq "Applications" -or $Path -eq "Applications/")
	{
	Write-Host "Input cannot be Empty or Applications"
	Exit
	}
	
XAExport
