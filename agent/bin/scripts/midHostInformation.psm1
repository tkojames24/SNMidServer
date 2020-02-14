function getServiceLogOnAs{
    param([string]$pid, [string]$serviceName)
    
    $srvDetails = $null;
    
    if ($pid){
        $srvDetails = Get-WmiObject Win32_Service | Where-Object {$_.ProcessId -eq $pid };
    }
    if (-not $srvDetails -and $serviceName){
        $srvDetails = Get-WmiObject Win32_Service | Where-Object {$_.Name -eq $serviceName };
    }
    
    if ($srvDetails -and $srvDetails.StartName){
        return $srvDetails.StartName;
    }
    
    return $null;
}
# Return the status the service. If the service is not stopped we wait 5 seconds and 
# query the service status again we repeat this step 3 times. Give enough time to stop the Service
function getStatus {
    param ([string] $serviceName)

    $srvState = Get-WmiObject -Query "Select * from Win32_Service where name='$srv'" | Select-Object -ExpandProperty State
    $tries = 0
    if ($srvState -ne "Stopped" -and $tries -le 2) {
        Start-Sleep -Seconds 5
        $srvState = Get-WmiObject -Query "Select * from Win32_Service where name='$srv'" | Select-Object -ExpandProperty State
        $tries++
    }

    return $srvState
}

# For the input service, it goes through all services with the same execuable paths and different names
# It deletes any of these services which are stopped
# Returns the list of all services which were successfully deleted 
function deleteDuplicateServices {
    param ([string] $srvName)

    # Get the executable path for the service without passed parameters
    $srvPathName = Get-WmiObject -Query "select * from Win32_Service where name='$srvName'" | Select-Object -ExpandProperty PathName
    $wrapperPath = [regex]::Matches($srvPathName,'(^"(.*?)")') | Select-Object -ExpandProperty Value
    if ($wrapperPath -eq $null) {
        $wrapperPath = ($srvPathName -split '\s+')[0]
    }

    # Find all the services with the same wrapper path
    $wrapperPath = $wrapperPath.Replace("`\", "`\`\")
    $srvWithSamePath = Get-WmiObject -Query "select * from Win32_Service where PathName like '$wrapperPath%' AND NOT name='$srvName'"| Select-Object -ExpandProperty Name
    $deletedServices = @()
    foreach ( $srv in $srvWithSamePath) {
        $srvStatus = getStatus $srv
        if ($srvStatus -eq "Stopped") {
            Write-Host "Trying to delete the service $srv"
            sc.exe delete $srv | Out-Null
            if ($?) {
               $deletedServices += $srv 
               Write-Host "$srv was successfully deleted"       
            } else {
               Write-Warning "Unable to delete the service $srv"
            }
        } else {
            Write-Warning "Uanble to delete the serviec $srv since it was not stopped"   
        }
    }
    return ($deletedServices -join "|")
}
