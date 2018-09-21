$result = [System.Net.Dns]::GetHostEntry($computer)  
$resolvedHostName = [string]$result.HostName

function Get-HBAWin {  
param(  
[String[]]$ComputerName = $ENV:ComputerName, 
[Switch]$LogOffline  
)  

$ComputerName | ForEach-Object {  
    try { 
        $Computer = $_ 
     
        $Params = @{ 
            Namespace    = 'root\WMI' 
            Class        = 'MSFC_FCAdapterHBAAttributes'  
            ComputerName = $Computer  
            ErrorAction  = 'Stop' 
            } 

        $Results = @()

        Get-WmiObject @Params  | ForEach-Object {  
            $InstanceName = $_.InstanceName -replace '\\','\\' 
            $Params['class']='MSFC_FibrePortHBAAttributes' 
            $Params['filter']="InstanceName='$InstanceName'"  
            $fpAttr = Get-WmiObject @Params | Select -Expandproperty Attributes #| % { ($_.PortWWN)}
            $PortWWN = $fpAttr.PortWWN
            $ports = ($PortWWN | % {"{0:x2}" -f $_}) -join ":"  
            
            $params['class'] = 'MSFC_HBAFCPInfo'
            $fc = Get-WmiObject @Params | % { $_.GetFcpTargetMapping($portwwn,1)}
            $Details = @()
            
            if ($fc.hbastatus -ne 0) {
                $FC = Get-WmiObject @Params | % { $_.GetFcpTargetMapping($portwwn,$fc.totalentrycount)}
                for ($i = 0; $i -lt $fc.totalentrycount; $i++) {
                    $Detail = "" | select "FCPWWN","FCNWWN", "FCID", "FCLun", "ScsiBus", "ScsiOSLun", "ScsiTarget", "DeviceID", "LunNum", "FrameSerialNumber", "Size", "SCSITargetId", "SCSILogicalUnit","Name","SystemName"
                    $Detail.FCPWWN = ($fc.entry[$i].fcpid.portwwn | ForEach-Object {'{0:x2}' -f $_}) -join ':'
                    $Detail.FCNWWN = ($fc.entry[$i].fcpid.nodewwn | ForEach-Object {'{0:x2}' -f $_}) -join ':'
                    $Detail.fcid = '{0:x2}' -f ($fc.entry[$i].fcpid.fcid)
                    $Detail.fcLun = $fc.entry[$i].fcpid.fcpLun
                    $Detail.ScsiBus = $fc.entry[$i].ScsiId.ScsiBusNumber 
                    $Detail.ScsiOSLun = $fc.entry[$i].ScsiId.ScsiOSLun
                    $Detail.ScsiTarget = $fc.entry[$i].ScsiId.ScsiTargetNumber
                    $LunDetail = Get-WmiObject Win32_DiskDrive  -computername $resolvedHostName | Where-Object {($_.SCSITargetId -eq $Detail.SCSITarget) -and ($_.scsilogicalunit -eq $Detail.ScsiOSLun) -and ($_.SCSIbus -eq $Detail.SCSIbus)}
                    if ($LunDetail) {
                        $Detail.DeviceID = $LunDetail.DeviceID
                        $Detail.LUNNum = $LunDetail.SCSILogicalUnit 
                        $Detail.FrameSerialNumber = $LunDetail.SerialNumber
                        $Detail.Size = [Math]::Round($LunDetail.Size / 1GB, 2)
                        $Detail.SCSITargetId = $LunDetail.SCSITargetId
                        $Detail.SCSILogicalUnit = $LunDetail.SCSILogicalUnit
                        $Detail.Name = $LunDetail.Name
                        $Detail.SystemName = $LunDetail.SystemName
                    }
                    $Details += $detail
                }
            }
            [HashTable]$hash=@{  
                    ComputerName     = $_.__SERVER  
                    NodeWWN          = (($_.NodeWWN) | ForEach-Object {'{0:x2}' -f $_}) -join ':' 
                    PortWWN          = $Ports 
                    Active           = $_.Active  
                    DriverName       = $_.DriverName  
                    DriverVersion    = $_.DriverVersion  
                    FirmwareVersion  = $_.FirmwareVersion  
                    Manufacturer     = $_.Manufacturer 
                    Model            = $_.Model  
                    SerialNumber     = $_.SerialNumber
                    ModelDescription = $_.ModelDescription 
                    UniqueAdapterId  = $_.UniqueAdapterId 
                    NumberOfPorts    = $_.NumberOfPorts 
                    FabricName       = (($fpAttr.FabricName )| ForEach-Object {'{0:x2}' -f $_}) -join ':' 
                    PortFcId         = $fpAttr.PortFcId
                    PortType         = $fpAttr.PortType
                    PortState        = $fpAttr.PortState
                    PortSpeed        = $fpAttr.PortSpeed
                    NumberofDiscoveredPorts = $fpAttr.NumberofDiscoveredPorts
                    Misc             = $Details
                  }  
            $Results += $hash
      }
$Results | ConvertTo-JSON 

    }
    catch { 
        '{ "error": "' + $_.Exception.Message + '" }'
    } 
}  
  
}


function Escape-JSONString($str){
	if ($str -eq $null) {return ""}
	$str = $str.ToString().Replace('"','\"').Replace('\','\\').Replace("`n",'\n').Replace("`r",'\r').Replace("`t",'\t')
	return $str;
}

function ConvertTo-JSON($maxDepth = 4,$forceArray = $false) {
	begin {
		$data = @()
	}
	process{
		$data += $_
	}
	
	end{
	
		if ($data.length -eq 1 -and $forceArray -eq $false) {
			$value = $data[0]
		} else {	
			$value = $data
		}

		if ($value -eq $null) {
			return "null"
		}		

		$dataType = $value.GetType().Name
		
		switch -regex ($dataType) {
	            'String'  {
					return  "`"{0}`"" -f (Escape-JSONString $value )
				}
	            '(System\.)?DateTime'  {return  "`"{0:yyyy-MM-dd}T{0:HH:mm:ss}`"" -f $value}
	            'Int64|Int32|Double' {return  "$value"}
				'Boolean' {return  "$value".ToLower()}
	            '(System\.)?Object\[\]' { # array
					
					if ($maxDepth -le 0){return "`"$value`""}
					
					$jsonResult = ''
					foreach($elem in $value){
						#if ($elem -eq $null) {continue}
						if ($jsonResult.Length -gt 0) {$jsonResult +=', '}				
						$jsonResult += ($elem | ConvertTo-JSON -maxDepth ($maxDepth -1))
					}
					return "[" + $jsonResult + "]"
	            }
				'(System\.)?Hashtable' { # hashtable
					$jsonResult = ''
					foreach($key in $value.Keys){
						if ($jsonResult.Length -gt 0) {$jsonResult +=', '}
						$jsonResult += 
@"
	"{0}": {1}
"@ -f $key , ($value[$key] | ConvertTo-JSON -maxDepth ($maxDepth -1) )
					}
					return "{" + $jsonResult + "}"
				}
	            default { #object
					if ($maxDepth -le 0){return  "`"{0}`"" -f (Escape-JSONString $value)}
					
					return "{" +
						(($value | Get-Member -MemberType *property | % { 
@"
	"{0}": {1}
"@ -f $_.Name , ($value.($_.Name) | ConvertTo-JSON -maxDepth ($maxDepth -1) )			
					
					}) -join ', ') + "}"
	    		}
		}
	}
}

get-hbawin -ComputerName $resolvedHostName