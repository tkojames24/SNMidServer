<##
 # PowerShell module that contains functions to enforce stricter file permissions on the
 # agent folder of a ServiceNow MID Server.
 #
 # For the "agent" folder and its sub-folders, the access control entries (or ACEs) are restricted
 # to a whitelist of these groups:
 #   - SYSTEM
 #   - Builtin/Administrators (local Administrators)
 #   - if applicable, the specific user running the MID Server Windows service ("Log on as" user)
 #
 # Users are also able to configure a comma separated list of additional groups/users to whitelist.
 #
 # The steps of how this is accomplished
 # 1) Look at the ACE of the top-level agent folder. If it contains only groups of the whitelist,
 #    then the permission enforcements have already been performed.  Do not continue.
 # 2) Look up the Windows service account user. If this is a specific user, add this user to
 #    to the whitelist.
 # 3) For the top-level agent folder and each sub-folder, update the ACEs to only contain the 
 #    whitelist of groups
 # 4) Save the ACLs to file for future reference
 #
 #
 #>
function enforcePerms {
    param([string]$folder, [string]$serviceName, [boolean]$debug, [string]$additionWhiteListedGroups)
    $ACL_FILE = "$folder\etc\fileperm.aclsave"
    
    # ensure that on error, the script continues
    $ErrorActionPreference = "Continue"
    
    if ($debug) {
        $DebugPreference = "Continue"
    } else {
        $DebugPreference = "SilentlyContinue"
    }

    if (-not (Test-Path $folder -PathType Container)) {
        Write-Warning "Cannot locate agent folder: $folder"
        return
    }

    # find the service account user
    $logOnUser = getServiceAccountUser -serviceName $serviceName

    if (-not $logOnUser) {
        Write-Warning "Could not locate Windows service with the name $serviceName"
        return
    }

    # define the white list, dynamically.  using an ArrayList is better for memory
    $whiteList = [System.Collections.ArrayList]@()
    $whiteList.Add("NT AUTHORITY\SYSTEM") > $null
    $whiteList.Add("BUILTIN\Administrators") > $null

    if ($logOnUser -ne "LocalSystem") {
        $whiteList.Add($logOnUser) > $null
    }

    $DOES_NOT_CONTAIN_SPECIAL_CHAR_REGEX = "^[a-zA-Z0-9\-\@\._]+$"
    if ($additionWhiteListedGroups) {
        $additionWhiteListedGroups.Split(",") | foreach {
            $group = $_.trim()
            # SAM account must be 20 characters or less and cannot contain the special characters "/ \ [ ] : ; | = , + * ? < >
            if ($group.startsWith("S-1-5") -or (($group.length -lt 21) -and ($group -match $DOES_NOT_CONTAIN_SPECIAL_CHAR_REGEX))) {
                $whiteList.Add($group) > $null
                Write-Debug "> allowing additional white listing for $group"
            } else {
                Write-Warning "white listed entry $group is not valid.  Ignoring..."
            }
        }
    }

    $GROUP_WHITELIST = $whiteList.ToArray()
    $WHITELIST_HASH_FILE = "$folder\etc\fileperm.grphash"

    # check if we still need to do this
    if ((checkForServiceUserChange -folder $folder -whitelist $GROUP_WHITELIST) -and (enforcementAlreadyPerformed -folder $folder -origACL $ACL_FILE)) {
        Write-Output "File permissions have already been enforced and have not changed. Leaving as-is."
        return
    }

    # save a copy of the ACL in case we need to revert
    $ACL_ORIG = "$folder\etc\fileperm.orig"
    saveACLToFile -folder $folder -file $ACL_ORIG

    # before any work can be done, disable inheritance to get the explicit list of effective ACEs
    Write-Debug "Disabling inheritance and making a copy of the inherited entries"
    # disable inheritance and copies access control entries (ACEs) so we can make changes
    icacls "$folder" /inheritancelevel:d > $null

    if (-not $?) {
        Write-Warning "Could not disable file permission inheritance for folder $folder. Aborting."
        return
    }

    # perform for the top-level agent folder. the sub-folders will inherit the same ACL
    if (replaceACLsForFolder -folder $folder -whitelist $GROUP_WHITELIST) {
        # if no errors, save the ACL so we can refer to it later
        saveACLToFile -folder  $folder -file $ACL_FILE
        # since we're successful, update the whitelist hash file now
        updateWhiteListHashFile
    }
}


function checkForServiceUserChange {
    param([string] $folder, [string] $whitelist)

    $currentWLHash = Get-StringHash $whitelist

    # if file DNE
    if (-not (Test-Path $WHITELIST_HASH_FILE -PathType Leaf)) {
        Write-Debug "Group hash file does not exist"
        # save one for next time
        Out-File -FilePath $WHITELIST_HASH_FILE -InputObject $currentWLHash -Encoding utf8
        # and return false to continue with enforcement
        return $false
    }

    $oldWLHash = Get-Content -Path $WHITELIST_HASH_FILE

    $result = $currentWLHash -eq $oldWLHash

    # there has been a configuration change so save the hash to a temp file for now
    if (!$result) {
        Out-File -Force -FilePath "$WHITELIST_HASH_FILE.temp" -InputObject $currentWLHash -Encoding utf8
    }

    return $result
}

function updateWhiteListHashFile {
    if (Test-Path "$WHITELIST_HASH_FILE.temp" -PathType Leaf) {
        Move-Item -Force -Path "$WHITELIST_HASH_FILE.temp" -Destination "$WHITELIST_HASH_FILE"
        Write-Debug "Saved whitelisted hash for later"
    } else {
        Write-Debug "No temp whitelisted hash file to save"
    }
}

<##
 # Checks to verify whether the enforcement has already been performed
 #
 # STEPS:
 # 1) Check for the existence of [agent]\etc\fileperm.aclsave
 # 2) If exists, compare the current ACL with what was saved
 # 3) If the same, flag enforement is not needed.  Otherwise, continue with enforcement.
 #>
function enforcementAlreadyPerformed {
    param([string] $folder, [string] $origACL)
    

    if (-not (Test-Path $origACL -PathType Leaf)) {
        Write-Debug "Saved ACL file not found."
        return $false
    }

    $WORKING_ACL_FILE = "$folder\fileperm.temp"
    $CHECK_PERM_CMD = "icacls `"$folder`""
    $SAVE_ACL_FILE_CMD = "$CHECK_PERM_CMD /save `"{0}`""

    # what icacls outputs to the screen is different than what it saves to file
    # since we want the ability to restore from file, we'll use what is saved to file

    # get the current ACL
    $output = iex -command ($SAVE_ACL_FILE_CMD -f $WORKING_ACL_FILE)

    # In this case, variable $_ doesn't capture a failure. Need to check $LASTEXITCODE instead.
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Unable to execute command to save the current ACL to a temp file."
        return $false
    }

    if (-not (Test-Path $WORKING_ACL_FILE -PathType Leaf)) {
        Write-Warning "Temp ACL file does not exist"
        return $false
    }

    # TODO: If we had the min req updated to PowerShell 4.0, Get-FileHash would work nicely
    #$hashOfCurrent = (Get-FileHash $WORKING_ACL_FILE).hash
    $output = Get-Content -Path $WORKING_ACL_FILE
    $hashOfCurrent = Get-StringHash $output

    # remove the temp file
    Remove-Item -Path $WORKING_ACL_FILE

    $original = Get-Content -Path $origACL
    $hashOfOriginal = Get-StringHash $original

    # if the file contents are the same, their hashes will be too
    # ((Get-FileHash $origACL).hash -eq $hashOfCurrent) {
    
    return ($hashOfOriginal -eq $hashOfCurrent)
}

function saveACLToFile {
    param([string] $folder, [string] $file)
    $CHECK_PERM_CMD = "icacls `"$folder`""
    $SAVE_ACL_FILE_CMD = "$CHECK_PERM_CMD /save `"{0}`""

    try {
        # save the current ACL to temp file
        $output = iex -command ($SAVE_ACL_FILE_CMD -f $file)
    } catch {
        throw "Unable to execute command to write current ACL to file $file"
    }
}

function getServiceAccountUser {
    param([string] $serviceName)

    Write-Debug "Looking for service name $serviceName";

    $service = Get-WmiObject "win32_service" -filter "Name='$serviceName'";

    if (!$service) {
        Write-Warning "Cannot find service with name $serviceName. Aborting."
        return $null
    }

    $logOnAsUser = $service.StartName;
    Write-Debug "Log on as user detected as $logOnAsUser"

    if ($logOnAsUser -and $logOnAsUser.startsWith(".\")) {
        $hostname = hostname
        # replace the "." with the hostname
        $logOnAsUser = $logOnAsUser.replace(".", $hostname)
        Write-Debug "Swapping hostname of localhost. `"Log on as`" user is now $logOnAsUser"
    }

    return $logOnAsUser
}

function addACLEntry {
    param([string] $folder, [string] $entry)
    
    Write-Debug "Adding entry for $entry"
    
    if ($entry.startsWith("S-1-5")) {
        $command = "icacls `"$folder`" /grant *${entry}:'(OI)(CI)(F)'"
    } else {
        # escape white spaces since icacls doesn't like quotes
        $entry = $entry.replace(" ", "`` ")
        $command = "icacls `"$folder`" /grant ${entry}:'(OI)(CI)(F)'"
    }
    
    # need to redirect STDERR to STDOUT to capture any errors
    $command = "cmd /c `"2>&1`" $command"
    Write-Debug "command = $command"
    $output = iex "$command"
    
    # expected output should have a single line indicating status, any more lines is an error
    if ($output.length -gt 1) {
        $error = $output[0]
        # in the case the entry already has an ACL, the first output line is:
        # processed file: folder_path
        if ($error -like "processed file:*") {
            continue;
        }
        
        Write-Warning "Skipping adding $entry : $error"
    }
}

function removeACLEntry {
    param([string] $folder, [string] $entry)
    
    Write-Debug "Removing entry for $entry"
    
    
    if ($entry.startsWith("S-1-5")) {
        $command = "icacls `"$folder`" /remove *${entry}"
    } else {
        # escape white spaces since icacls doesn't like quotes
        $entry = $entry.replace(" ", "`` ")
        $command = "icacls `"$folder`" /remove $entry"
    }
    
    # need to redirect STDERR to STDOUT to capture any errors
    $command = "cmd /c `"2>&1`" $command"
    Write-Debug "command = $command"
    $output = iex "$command"
    
    # expected output should have a single line indicating status; any more and we most likely got an error
    if ($output.length -gt 1) {
        $error = $output[0]
        
        if ($error -like "processed file:*") {
            continue;
        }
        
        Write-Warning "Skipping removing $entry : $error"
    }
}

<# for the folder:
 #   1) read in the current ACL
 #   2) iterate through the rules and remove the group/user not in the whitelist
 #   3) iterate through the whitelist and add a new ACL
 #>
function replaceACLsForFolder {
    param([string] $folder, [array] $whitelist)

    Write-Debug "for folder $folder"

    # PowerShell swallows output and debug messages with exceptions, so...
    # we will handle each case individually.  We want exceptions to be thrown
    # so that MID issue will be logged.
    
    # The PowerShell cmdlet Set-Acl does not work with the service running as a user
    # that is not part of the Administrators group.  However, the command line tool icacls does.
    #
    # Example icacls output:
    # folder_path BUILTIN\Administrators:(OI)(CI)(F)
    #             HOSTNAME\Group:(CI)(WD)
    #             HOSTNAME\User:(CI)(AD)
    #             CREATOR OWNER:(OI)(CI)(IO)(F)
    #
    # Successfully processed 1 files; Failed processing 0 files
    
    try {
        # get the ACE for the subfolder
        $command = "icacls `"$folder`""
        $aclOutput = iex $command
    } catch {
        throw "Cannot get ACL of folder $folder."
    }
    Write-Debug "ACL output:`n$aclOutput"

    Write-Debug "Removing ACLs not in the whitelist"
    $ACL_OUTPUT_REGEX = "^(.+):[\(A-Z\)]+$"
    $HOSTNAME = hostname
    Write-Debug "Hostname detected as $HOSTNAME"
    foreach ($line in $aclOutput) {
        $line = $line.replace($folder, "").trim()
        
        if (-not ($line -match $ACL_OUTPUT_REGEX)) {
            continue
        }
        
        $entries = $line -split ":"
        $entry = $entries[0]
        $strippedEntry = $entry.replace("$HOSTNAME\", "")
        if (($whitelist.contains($entry)) -or ($whitelist.contains($strippedEntry))) {
            Write-Debug "Not removing $entry since it's in the whitelist"
            continue;
        } else {
            removeACLEntry -folder $folder -entry $entry
        }
    }

    Write-Debug "Adding entries in whitelist to ACL"
    # add new rules
    foreach ($entry in $whitelist) {
        addACLEntry -folder $folder -entry $entry
    }
    
    Write-Debug ">>> new ACL applied"
    return $true
}

#https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/generating-md5-hashes-from-text
function Get-StringHash([String]$String) { 
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($String)
    $algorithm = [System.Security.Cryptography.HashAlgorithm]::Create('MD5')
    $StringBuilder = New-Object System.Text.StringBuilder 
  
    $algorithm.ComputeHash($bytes) | 
    ForEach-Object { 
        $null = $StringBuilder.Append($_.ToString("x2")) 
    } 
  
    $StringBuilder.ToString() 
}