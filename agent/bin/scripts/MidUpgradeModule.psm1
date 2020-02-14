$logFile = $null;
$logFilePrefix = "MidUpgradeLog";
$psVer = 1;
$statusFile = $null;

function removeFilesWithTimout{
    param([string]$baseDir, [string]$extractedFilesDir, [string[]]$itemsToRemove, [int]$timeoutInSeconds, [int]$sleepTimeInSeconds)
    
    $retryCount = 0;
    $maxRetries = $timeoutInSeconds / $sleepTimeInSeconds;
    
    logToFile -msg "Starting to remove items:";
    
    # Go on every item
    foreach ($item in $itemsToRemove){
        $success = $false;
        $relPathItem = $item;
        $item = join-path -Path $baseDir -ChildPath $item;
        # Try delete the item for $maxRetries or until successful
        while ($retryCount -lt $maxRetries -and -not $success) {
            try{
                # Case this is a folder
                if (Test-Path -Path $item -PathType Container){
                    # Special case for JRE content, only remove if we have JRE folder in extracted files path
                    if ($relPathItem.toLower() -eq "jre"){
                        $extractedJreFolderPath = Join-Path -path $extractedFilesDir -ChildPath $relPathItem;
                        if (-not (test-path $extractedJreFolderPath)){
                            logToFile -msg "`tFolder JRE does not exist in extracted files - skipping removing JRE folder";
                            break;
                        }
                    }
                    logToFile -msg "`tRemoving directory: remove-item '$item' -Recurse -Force -ErrorAction stop;"
                    remove-item $item -Recurse -Force -ErrorAction stop;
                }
                # Case this is file
                elseif (Test-Path -Path $item -PathType Leaf){
                    logToFile -msg "`tRemoving files(s): remove-item '$item' -Force -ErrorAction stop;";
                    remove-item $item -Force -ErrorAction stop;
                }
                # Case the $item does not exist
                else{
                    logToFile -msg "`t$item no longer exist - skipping";
                }
                $success = $true; # Remove of item was successful - break the while
            }
            catch {
                $success = $false;
                $retryCount++;
                if ($retryCount -ge $maxRetries) {
                    logToFile -msg "`t`tFailed to remove items for more than $maxRetries with a $sleepTimeInSeconds delay; Quit!" -quit;
                }
                logToFile -msg "`t`tFailed to remove $item; This was attempt number $retryCount; Sleeping for $sleepTimeInSeconds and trying again - overall timeout=$timeoutInSeconds";
                Start-Sleep -seconds $sleepTimeInSeconds;
            }
        }
    }
}

function copyFiles{
    param([string]$src, [string]$dst, [string[]]$exclude)
    
    if ($src.toLower() -eq $dst.toLower()){
        logToFile -msg "Cannot copy from and to the same folder/file";
        return;
    }
    if ((-not $src) -or (-not $dst)){
        logToFile -msg "Source or Destination is empty - cannot continue with copy";
        return;
    }
    
    if (-not(test-path $src)){
        logToFile -msg "Could not copy files from $src to $dst as $src does not exist";
        return;
    }
    
    $src = (Get-Item $src).FullName;
    
    # If we are trying to copy a file, make sure the $dst does not point to a file, it should be a directory
    # For example, if $src = c:\some_file $dst should be a directory c:\some_directory\
    # The side effect noticed, is that if we copy c:\some_file to c:\another_file the result is a new file: c:\another_file\some_file.
    # This is why we make sure $dst is a directory
    if ((test-path $src -PathType Leaf) -and (-not $dst.endsWith("\"))){
        if ($dst.lastIndexOf("\") -gt -1){
            $dst = $dst.substring(0,$dst.lastIndexOf("\"));
        }
    }
    verifyDestinationFolderExist -dst $dst;
    
    logToFile -msg "Start copying files from $src to $dst :";
    
    try{
        # Unfortunately, copy-item with -recursive and -exclude does not work (the exclusion does not work on subfolders)
        # This is a manual recurse with a simple exclusion (no regex/wildcard supported)
        $srcChildren = Get-ChildItem -Path $src -Recurse;
        foreach ($child in $srcChildren){
            if (-not $child -or -not $child.FullName){
                continue;
            }
            $relativeChildPath = $child.FullName.Substring($src.length);
            if ($relativeChildPath.startsWith("\")){
                $relativeChildPath = $relativeChildPath.substring(1); # remove first \
            }
            $toFullPath = Join-Path -path $dst -ChildPath $relativeChildPath;
            
            # If this file is in the excluded list, skip and move to the next one
            if ($exclude -and ($exclude -contains $relativeChildPath -or $exclude -contains $child.FullName)){
                logToFile -msg ("`t!Will not copy: " + $child.FullName + " as it is marked as excluded");
                continue;
            }
            
            if ($child.PSIsContainer) {
                # If directory already exist - skip
                if (test-path $toFullPath -PathType Container){
                    continue;
                }
                # If directory does not exist - create it and log
                try{
                    New-Item -ItemType "directory" -Path $toFullPath -ErrorAction Stop;
                    logToFile -msg ("`tCreating folder: " + $toFullPath);
                } catch {
                    logToFile -msg ("`tCould not create a folder: " + $toFullPath);
                }
                
            } else {
                # This is a file
                logToFile -msg ("`tRunning command: Copy-Item " + $child.FullName + " -Destination $toFullPath -Force;");
                try{
                    Copy-Item $child.FullName -Destination $toFullPath -Force -ErrorAction stop;
                } catch{
                    logToFile -msg ("`t`tCould not copy file: " + $toFullPath);
                }
            }
        }
    }
    catch{
        $errMsg = $_.Exception.Message;
        logToFile -msg "Could not copy all files from $src to $dst. $errMsg" -quit;
    }
}

function verifyMidServiceIsDown{
    param([string]$serviceName, [int]$timeout=120)
    
    verifyMidServiceStatus -expectedStatus "stopped" -serviceName $serviceName -timeout $timeout;
}

function startMidService{
    param([string]$serviceName, [int]$timeout=120)
    
    try{
        logToFile -msg "Trying to start service $serviceName ..."
        if ($psVer -gt 2){
            Start-Service -name $serviceName *>> $logFile # redirect all streams to file
        }
        else{
            Start-Service -name $serviceName 2>&1 >> $logFile; # PowerShell 2 does not have redirection of warning
        }
    }
    catch{
        $user = $env:UserName;
        logToFile -msg "Could not start service $serviceName, does $user has enough privileges to start this service?" -quit
    }
    verifyMidServiceStatus -expectedStatus "running" -serviceName $serviceName -timeout $timeout;
}

function stopMidService{
    param([switch]$stopService, [string]$midServiceName)
    if ($stopService){
        logToFile -msg "Trying to stop service $midServiceName ..."
        try{
            if ($psVer -gt 2){
                Stop-Service -name $midServiceName *>> $logFile;
            } else {
                Stop-Service -name $midServiceName 2>&1 >> $logFile;
            }
        } catch {
            logToFile -msg "Could not stop service $serviceName, does $user has enough privileges to start this service?" -quit
        }
    }
    verifyMidServiceIsDown -serviceName $midServiceName;
}

function verifyMidServiceStatus{
    param([string]$expectedStatus, [string]$serviceName, [int]$timeout=120)
    
    $i=0;
    $delay = 5; # number of seconds to sleep;
    $iterations = $timeout / $delay;
    
    logToFile -msg "Checking service $serviceName status";
    $srv = Get-Service -name $serviceName;
    if (-not $srv){
        logToFile -msg "Could not read service name $serviceName" -quit;
    }
    
    $srvStatus = $srv.status.toString();
    logToFile "`tService $serviceName is in status = $srvStatus";
    while ($srvStatus.toLower() -ne $expectedStatus.toLower() -and $i -lt $iterations){
        Start-Sleep -seconds $delay; # Wait 5 second this way $i = number of seconds waited
        $srv = Get-Service -name $serviceName;
        $srvStatus = $srv.status.toString();
        $i++;
        logToFile -msg "`tWaiting for service $serviceName to be $expectedStatus, attempt number $i; status = $srvStatus...";
    }
    
    $srv = Get-Service -name $serviceName;
    $srvStatus = $srv.status.toString();
    if ($srvStatus.toLower() -ne $expectedStatus.toLower()){
        logToFile -msg "Service $serviceName was not $expectedStatus within $timeout seconds" -quit;
    }
    
    logToFile -msg "`tService $serviceName is $srvStatus - continue";
    
    #return $true;
}

<#
    This is the main method where the MID upgrade copy files flow starts (called from Java MIDDistUpgradeRunnerForWindows).
    This method copies files from one location to the other.
    $newAgentExtractedDir: a String represents the folder of the new agent files after extraction (not Zipped)
    $midBaseDir: a String representing the MID installation directory
    $commaSeparatedItemsToRemove: a comma separated items (direcotries or files) to remove before copying new files
    $commaSeparatedLastFilesToCopyList: a String with comma separated list of files to copy after the main copy was done - this is used to indicate upgrade complete
    $commaSeparatedExcludeFiles: a String with comma separated files to be excluded. A file will not be excluded if it is specifically mantioned by name in commaSeparatedSourceList
    $midPid: a String representing the MID service process ID, is ued only if $midServiceName is not supplied
    $midServiceName: a String, optional, representing the MID service name; if supplied the $midPid is not used.
    $stopService: a switch, instruct the method whether or not to stop the MID service or just wait until the service is stopped (the stop should be in JAVA code)
    $packageStamp: a String, represents the current version package stamp
    
    If the destination folder does not exist, we will attempt to create it.
#>
function mainMidUpgrade{
    param([string]$newAgentExtractedDir, [string]$midBaseDir, [string]$commaSeparatedItemsToRemove, [string]$commaSeparatedLastFilesToCopyList, [string]$commaSeparatedExcludeFiles, 
        [string]$midPid, [string]$midServiceName, [switch]$stopService, [string]$packageStamp, [bool]$isTest)
    
    # Set up log file
    if (-not $midBaseDir){
        $midBaseDir = ".";
    }
    $logFile = (join-path -path $midBaseDir -ChildPath ("logs\" + $logFilePrefix + "_" + $packageStamp + ".log")).toString().trim();
    $statusFile = (join-path -path $midBaseDir -ChildPath ("logs\upgradeStatus.log")).toString().trim();
    "In progress" > $statusFile;
    verifyLogFileExist -logFileFullPath $logFile;
    
    # Make sure we have the minimum PowerShell version
    getPsVer;
    
    # Get MID Service Name
    if ($pid -and -not $midServiceName){
        $midServiceName = getMIDServiceName -pid $midPid -midBaseDir $midBaseDir -isTest $isTest;
    }
    if (-not $midServiceName){
        logToFile -msg "Critical: Could not locate MID service name" -quit;
    }
 
    $excludeList = $commaSeparatedExcludeFiles -split "\s*,\s*"; #split and trim
    $lastFilesToCopy = $commaSeparatedLastFilesToCopyList -split "\s*,\s*"; #split and trim 
    $removeItems = $commaSeparatedItemsToRemove -split "\s*,\s*"; #split and trim 
    
    logToFile -msg "---------=========   Starting MID upgrade ....   =========---------";
    logToFile -msg "Got package: $packageStamp";
    logToFile -msg "MID Server Service = '$midServiceName'";
    
    # Removing 1 year old upgrade logs.
    removeOldUpgradeLogFiles -logFile $logFile;
    
    ###### Main flow ####
    stopMidService -stopService $stopService -midServiceName $midServiceName;
    if ($removeItems){
        removeFilesWithTimout -baseDir $midBaseDir -extractedFilesDir $newAgentExtractedDir -itemsToRemove $removeItems -timeoutInSeconds 600 -sleepTimeInSeconds 5;
    }
    # Copy all new agent files, skipping excluded files
    copyFiles -src $newAgentExtractedDir -dst $midBaseDir -exclude $excludeList;
    
    # Copy last files - that will indicate that the MID upgrade had completed.
    logToFile -msg "Finished copying new agent files. Finalizing: now copy last files in order to indicate Upgrade Complete";
    foreach ($lastFileToCopy in $lastFilesToCopy){
        $src = createFullPathFile -path $newAgentExtractedDir -file $lastFileToCopy;
        $dst = createFullPathFile -path $midBaseDir -file $lastFileToCopy;
        
        logToFile -msg "`tAbout to copy $src to $dst";
        copyFiles -src $src -dst $dst -exclude $null;
    }
    
    startMidService -serviceName $midServiceName;
    logToFile -msg "---------=========   MID upgrade ended ....   =========---------";
    "Completed" > $statusFile;
}

function createFullPathFile{
    param([string]$path, [string]$file)
    
    # If the file already has the full path - return the file;
    if ($file -match "^\w\:\\|^\\\\"){
        return $file;
    }
    
    return join-path -path $path -ChildPath $file;
}

function getPsVer{
    try{
        $psVer = $PSVersionTable.PSVersion.Major;
    } catch{
        logToFile -msg "Cannot determine PowerShell version, is PowerShell version 1?" -quit
    }
    if ($psVer -lt 2){
        logToFile -msg "Supported PowerShell version is 2.0 and above" -quit
    }
    logToFile -msg "PowerShell version $psVer detected.";
}

function logToFile{
    param([Parameter(ValueFromPipeline=$true)][string]$msg, [switch]$quit);
    
    $oMsg = $msg;
    write-host $msg;
    if ($quit){
        $msg = (Get-Date -format g) + " ERROR: " + $msg;
    }else {
        $msg = (Get-Date -format g) + " INFO: " + $msg;
    }
    
    if ($logFile){
        out-file -filePath $logFile -Append -force -inputObject $msg;
    }
    
    if ($quit){
        $oMsg += "(" + $_.Exception.Message + ")"
        "Error`n$oMsg" > $statusFile;
        write-host "---------=========   MID upgrade ended ....   =========---------";
        out-file -filePath $logFile -Append -force -inputObject "---------=========   MID upgrade ended ....   =========---------";
        throw "Error: $oMsg";
    }
}

function verifyLogFileExist{
    param([string] $logFileFullPath)
    
    if (-not (test-path $logFileFullPath -PathType Leaf)){
        try{
            $null = New-Item -force -ItemType "file" -Path $logFileFullPath;
        }
        catch{
            throw "Could not create the log file, existing upgrade process";
        }
    }
}

function verifyDestinationFolderExist{
    param([string] $dst)
    
    if (-not(test-path $dst -PathType Container)){
        try{
            $null = New-Item -ItemType "directory" -Path $dst
        }
        catch{
            logTofile -msg "Could not create the target directory $dst, existing upgrade process" -quit;
        }
    }
}

function getDirectoryFromPath{
    param([string] $path)
    
    # If the path is a not a directory, get the path until the last slash
    if (-not (test-path -Path $path -PathType Container)){
        $lastSlashIndex = $path.lastIndexOf("\");
        $path = $path.substring(0,$lastSlashIndex);
    }
    
    return $path;
}

function removeOldUpgradeLogFiles{
    param([string] $logFile)
    
    $logFileDir = getDirectoryFromPath -path $logFile;
    $oldFiles = Get-ChildItem -path $logFileDir | where-object {$_.PSIsContainer -eq $false -and $_.name.StartsWith($logFilePrefix)} | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-365)}
    
    foreach ($oldFile in $oldFiles){
        if ($oldFile -and $oldFile.FullName){
            logToFile -msg ("About to delete old file: " + $oldFile.FullName.toString());
            remove-item $oldFile.FullName;
        }
    }
}

function getMidServiceName{
    param([string]$pid, [string]$midBaseDir, [bool]$isTest)
    
    $mSrvName = getMIDServiceNameByPid -pid $pid;
    if (-not $mSrvName){
        $mSrvName = getMidServiceNameFromFile -midBaseDir $midBaseDir -isTest $isTest;
    }
    
    return $mSrvName;
}

function getMIDServiceNameByPid{
    param([string]$pid)
    
    $prc = (Get-WmiObject -Query "select CommandLine from Win32_process where ProcessId=$pid");
    if (-not $prc -or -not $prc.CommandLine){
        logToFile -msg "Could not locate MID service based on PID: Process with PID=$pid, does not exist or do no have CommandLine attribute";
        return $False;
    }
    if (-not $prc.CommandLine.toString().toLower().startsWith($midBaseDir.toLower())){
        logTofile -msg ("Could not locate MID service based on PID: Process with PID=$pid, does not starts with the path as inputed, process CommandLine=" + $prc.CommandLine + " but the base dir=$midBaseDir");
        return $False;
    }
    
    $srv = Get-WmiObject Win32_Service | Where-Object {$_.ProcessId -eq $pid };
    if ($srv -and $srv.name){
        logToFile -msg ("Got MID service name (by PID) = " + $srv.name);
        return $srv.name;
    }else{
        logToFile -msg "Could not locate service with pid=$pid";
        return $False;
    }
    
    return $False;
}

function getMidServiceNameFromFile{
    param([string]$midBaseDir, [bool]$isTest)
    
    # If this is testing, remove the fake folder in order to find the real file
    if ($isTest -and ($midBaseDir.endsWith("fake") -or $midBaseDir.endsWith("fake\"))){
        $midBaseDir = $midBaseDir.substring(0, $midBaseDir.lastIndexOf("\fake"));
    }
    
    $wrapperName = (Get-Content $midBaseDir\conf\wrapper-override.conf | Select-String -Pattern "^wrapper.name");
    if ($wrapperName){
        $items = $wrapperName -split "=", 2;
        if ($items[1]){
            logToFile -msg ("Got MID service name (from wrapper-override.conf file) = " + $items[1]);
            return $items[1];
        }
    }
    
    return $null;
}