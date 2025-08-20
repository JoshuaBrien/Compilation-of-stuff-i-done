#Creates lnk file execute powershell code
#Modified (Taken) from https://gist.github.com/r00t-3xp10it/5bf1e26d42ddb75ac443b867e076d419

#menu for easier handling but you can also call the function directly
function menu{
    # Global variables to store user settings
    if (-not $global:menu_input_shortcut_savepath) { $global:menu_input_shortcut_savepath = $null }
    if (-not $global:menu_input_shortcut_iconLocation) { $global:menu_input_shortcut_iconLocation = $null }
    if (-not $global:menu_input_shortcut_chooseicon) { $global:menu_input_shortcut_chooseicon = $true }
    if (-not $global:menu_input_shortcut_description) { $global:menu_input_shortcut_description = $null }
    if (-not $global:menu_input_shortcut_command) { $global:menu_input_shortcut_command = $null }
    if (-not $global:menu_input_shortcut_runasadmin) { $global:menu_input_shortcut_runasadmin = $false }
    if (-not $global:menu_input_shortcut_hide) { $global:menu_input_shortcut_hide = $false }
    if (-not $global:menu_input_shortcut_runhidden) { $global:menu_input_shortcut_runhidden = $false }
    if (-not $global:verbose) { $global:verbose = $false }

    do {
        Clear-Host
        #Prints banners
        Write-Host "

        
        "
        Write-Host " (        )     )   (                                 
 )\ )  ( /(  ( /(   )\ )  *   )   (            *   )  
(()/(  )\()) )\()) (()/(` )  /(   )\      (  ` )  /(  
 /(_))((_)\ ((_)\   /(_))( )(_))(((_)     )\  ( )(_)) 
(_))   _((_)  ((_) (_)) (_(_()) )\___  _ ((_)(_(_())  
/ __| | || | / _ \ | _ \|_   _|((/ __|| | | ||_   _|  
\__ \ | __ || (_) ||   /  | |   | (__ | |_| |  | |    
|___/ |_||_| \___/ |_|_\  |_|    \___| \___/   |_|    
                                                      " -ForegroundColor Red
        Write-Host "Created by JOB (Joshua O'Brien)"
        Write-Host "Inspired by r00t-3xp10it`nLink to his work:https://gist.github.com/r00t-3xp10it/5bf1e26d42ddb75ac443b867e076d419" 
        Write-Host "This script creates a Windows shortcut (.lnk file) that executes a specified PowerShell command.`n"
        
        # Display current settings
        Write-Host "Current Settings:" -ForegroundColor Yellow
        Write-Host "  Path: $(if($global:menu_input_shortcut_savepath) {$global:menu_input_shortcut_savepath} else {'Default'})"
        Write-Host "  Icon: $(if($global:menu_input_shortcut_iconLocation) {$global:menu_input_shortcut_iconLocation} else {'Auto-select'})"
        Write-Host "  Description: $(if($global:menu_input_shortcut_description) {$global:menu_input_shortcut_description} else {'Default'})"
        Write-Host "  Command: $(if($global:menu_input_shortcut_command) {$global:menu_input_shortcut_command} else {'calc.exe'})"
        Write-Host "  Run as Admin: $global:menu_input_shortcut_runasadmin"
        Write-Host "  Verbose: $global:verbose`n"
        Write-Host "  Run in Hidden Terminal: $global:menu_input_shortcut_runhidden"

        Write-Host "[1] Configure shortcut save path"
        Write-Host "[2] Configure icon location"
        Write-Host "[3] Choose icon from list of common icons"
        Write-Host "[4] Set shortcut description"
        Write-Host "[5] Set command to execute"
        Write-Host "[6] Run as administrator"
        Write-Host "[7] Hide shortcut file"
        Write-Host "[8] Run in hidden terminal window"
        Write-Host "[9] Verbose mode"
        Write-Host "[c] Create shortcut with current settings" -ForegroundColor Green
        Write-Host "[q] Quit script"
        
        $menu_choice = Read-Host "`nEnter your choice (1-9, c, or q to quit)"

        switch ($menu_choice.ToLower()) {
            '1' {
                Write-Host "`nCurrent path: $(if($global:menu_input_shortcut_savepath) {$global:menu_input_shortcut_savepath} else {'Default: ' + $env:USERPROFILE + '\Desktop\FunnyShortcut.lnk'})"
                $input_path = Read-Host "Enter new shortcut save path (or press Enter to keep current)"
                if (-not [string]::IsNullOrEmpty($input_path)) {
                    $global:menu_input_shortcut_savepath = $input_path
                    Write-Host "Shortcut save path updated to: $global:menu_input_shortcut_savepath" -ForegroundColor Green
                }
                Read-Host "Press Enter to return to main menu"
            }
            '2' {
                Write-Host "`nCurrent icon: $(if($global:menu_input_shortcut_iconLocation) {$global:menu_input_shortcut_iconLocation} else {'Auto-select from list'})"
                $input_icon = Read-Host "Enter icon location (or press Enter to keep current)"
                if (-not [string]::IsNullOrEmpty($input_icon)) {
                    $global:menu_input_shortcut_iconLocation = $input_icon
                    $global:menu_input_shortcut_chooseicon = $false
                    Write-Host "Icon location updated to: $global:menu_input_shortcut_iconLocation" -ForegroundColor Green
                }
                Read-Host "Press Enter to return to main menu"
            }
            '3' {
                $choice = Read-Host "`nDo you want to choose an icon from a list of common icons? (Y/N, current: $(if($global:menu_input_shortcut_chooseicon) {'Y'} else {'N'}))"
                if ($choice -imatch '^y') {
                    $global:menu_input_shortcut_chooseicon = $true
                    $global:menu_input_shortcut_iconLocation = $null
                    Write-Host "Will prompt to choose icon from list when creating shortcut." -ForegroundColor Green
                } elseif ($choice -imatch '^n') {
                    $global:menu_input_shortcut_chooseicon = $false
                    Write-Host "Will use first available icon automatically." -ForegroundColor Green
                }
                Read-Host "Press Enter to return to main menu"
            }
            '4' {
                Write-Host "`nCurrent description: $(if($global:menu_input_shortcut_description) {$global:menu_input_shortcut_description} else {'Default: Windows Shortcut'})"
                $input_desc = Read-Host "Enter shortcut description (or press Enter to keep current)"
                if (-not [string]::IsNullOrEmpty($input_desc)) {
                    $global:menu_input_shortcut_description = $input_desc
                    Write-Host "Description updated to: $global:menu_input_shortcut_description" -ForegroundColor Green
                }
                Read-Host "Press Enter to return to main menu"
            }
            '5' {
                Write-Host "`nCurrent command: $(if($global:menu_input_shortcut_command) {$global:menu_input_shortcut_command} else {'Default: calc.exe'})"
                $input_cmd = Read-Host "Enter command to execute (or press Enter to keep current)"
                if (-not [string]::IsNullOrEmpty($input_cmd)) {
                    $global:menu_input_shortcut_command = $input_cmd
                    Write-Host "Command updated to: $global:menu_input_shortcut_command" -ForegroundColor Green
                }
                Read-Host "Press Enter to return to main menu"
            }
            '6' {
                $global:menu_input_shortcut_runasadmin = -not $global:menu_input_shortcut_runasadmin
                Write-Host "Run as administrator: $global:menu_input_shortcut_runasadmin" -ForegroundColor Green
                Read-Host "Press Enter to return to main menu"
            }
            '7' {
                Write-Host "Hiding shortcut file is not implemented yet." -ForegroundColor Yellow
                Read-Host "Press Enter to return to main menu"
            }
            '8' {
                $global:menu_input_shortcut_runhidden = -not $global:menu_input_shortcut_runhidden
                Write-Host "Run in hidden terminal window: $global:menu_input_shortcut_runhidden" -ForegroundColor Green
                Read-Host "Press Enter to return to main menu"
            }
            '9' {
                $global:verbose = -not $global:verbose
                Write-Host "Verbose mode: $global:verbose" -ForegroundColor Green
                Read-Host "Press Enter to return to main menu"
            }
            'c' {
                Write-Host "`nCreating shortcut with current settings..." -ForegroundColor Green
                funny_shortcut -shortcut_savepath $global:menu_input_shortcut_savepath -shortcut_iconLocation $global:menu_input_shortcut_iconLocation -shortcut_chooseicon:$global:menu_input_shortcut_chooseicon -shortcut_description $global:menu_input_shortcut_description -shortcut_command $global:menu_input_shortcut_command -shortcut_runasadmin:$global:menu_input_shortcut_runasadmin -verbose:$global:verbose
                Read-Host "`nPress Enter to return to main menu"
            }
            'q' {
                Write-Host "Quitting script." -ForegroundColor Red
                return
            }
            default {
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

function funny_shortcut{
    param(
    <#
    .SYNOPSIS
    Creates a windows shortcut that executes powershell code.

    .DESCRIPTION
    This function creates a Windows shortcut (.lnk file) that executes a specified PowerShell command.

    .PARAMETER SHORTCUT_SAVEPATH
    Location of the shortcut file

    .PARAMETER SHORTCUT_ICONLOCATION
    Location of the icon file for the shortcut

    .PARAMETER SHORTCUT_CHOOSEICON
    Allow user to choose the icon from a list of common icons

    .PARAMETER SHORTCUT_DESCRIPTION
    Description of the shortcut
    
    .PARAMETER SHORTCUT_COMMAND
    Execute when the shortcut is run

    .PARAMETER SHORTCUT_RUNASADMIN
    Execute the shortcut with administrative privileges

    .PARAMETER SHORTCUT_HIDE
    Hides the shortcut file from the user

    .PARAMETER SHORTCUT_RUNHIDDEN
    Runs it in a hidden terminal window

    .PARAMETER VERBOSE
    If set, will output additional information during execution
    #>
    
    [string]$shortcut_savepath,
    [string]$shortcut_iconLocation,
    [switch]$shortcut_chooseicon,
    [switch]$shortcut_runasadmin,
    [switch]$shortcut_hide,
    [switch]$shortcut_runhidden,
    [string]$shortcut_description,
    [string]$shortcut_command,
    [switch]$verbose
    )

    # Initialize WScript.Shell object
    $wshell = New-Object -ComObject WScript.Shell
    $Powershell_location = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" 

    # -- DEFINE SHORTCUT PATH --
    if ([string]::IsNullOrEmpty($shortcut_savepath)) {
        $shortcut_savepath = "$env:USERPROFILE\Desktop\FunnyShortcut.lnk"
        if ($verbose) {
            Write-Host "No shortcut path provided, using default: $shortcut_savepath"
        }
    }
    else{
        if ($verbose) {
            Write-Host "Using provided shortcut path: $shortcut_savepath"
        }
    }

    # Ensure the directory exists
    $shortcut_Directory = Split-Path -Path $shortcut_savepath -Parent
    if (-not (Test-Path -Path $shortcut_Directory)) {
        if ($verbose) {
            Write-Host "Creating directory: $shortcut_Directory"
        }
        New-Item -ItemType Directory -Path $shortcutDirectory -Force | Out-Null
    }

    # Check if the lnk file already exists and remove it
    if (Test-Path -Path $shortcut_savepath) {
        if ($verbose) {
            Write-Host "Shortcut already exists at $shortcut_savepath. Overwriting..."
        }
        Remove-Item -Path $shortcut_savepath -Force
    }
    
    # Create the shortcut object
    if ($verbose) {
        Write-Host "Creating new shortcut at $shortcut_savepath"
    }
    $shortcut = $wshell.CreateShortcut($shortcut_savepath)

    # -- DEFINE ICON LOCATION -- 
    if ([string]::IsNullOrEmpty($shortcut_iconLocation)) {
        #Loop through the default icon locations
        $SearchIconsList = @(
        "$Env:WINDIR\system32\WSCollect.exe",
        "$Env:WINDIR\system32\ComputerDefaults.exe",
        "$Env:WINDIR\system32\CustomInstallExec.exe",
        "$Env:PROGRAMFILES\Windows Defender\MpCmdRun.exe",
        "$Env:PROGRAMFILES\PCHealthCheck\PCHealthCheckBroker.exe",
        "$Env:PROGRAMFILES\Windows Defender\Offline\OfflineScannerShell.exe",
        "$Env:PROGRAMFILES\Microsoft Office 15\ClientX64\IntegratedOffice.exe",
        "${Env:PROGRAMFILES(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$Env:PROGRAMFILES\Microsoft Office\root\Office16\excelcnv.exe",
        "$Env:PROGRAMFILES\Microsoft Office\root\Office16\OUTLOOK.exe",
        "$Env:WINDIR\system32\WindowsPowerShell\v1.0\powershell.exe",
        "$Env:PROGRAMFILES\Google\Chrome\Application\Chrome.exe",
        "$Env:LOCALAPPDATA\Programs\Opera GX\opera.exe",
        "$Env:PROGRAMFILES\Mozilla Firefox\Firefox.exe",
        "$Env:PROGRAMFILES\WinRAR\WinRAR.exe",
        "$Env:PROGRAMFILES\ShareX\ShareX.exe",
        "$Env:WINDIR\system32\GamePanel.exe",
        "$Env:WINDIR\system32\mspaint.exe",
        "$Env:WINDIR\system32\wscript.exe",
        "$Env:WINDIR\system32\mmc.exe",
        "$Env:WINDIR\system32\wsl.exe",
        "$Env:WINDIR\system32\cmd.exe",
        "$Env:WINDIR\explorer.exe"
        )
        
        #Searching 
        ForEach($Item in $SearchIconsList)
        {
            If(Test-Path -Path "$Item")
            {   
                ## Icon found
                write-host "     * " -ForegroundColor Green -NoNewline
                write-host "found: " -NoNewline

                If($shortcut_chooseicon)
                {
                    ## Let user manually chose icon
                    write-host "$Item`n" -ForegroundColor Green
                    write-host "     + " -NoNewline -ForegroundColor Red
                    $SelectedIcon = Read-Host "Choose icon from list? (Y|N): "
                    If($SelectedIcon -imatch '(y|yes)')
                    {
                        $shortcut_iconLocation = "$Item"
                        write-host "     + " -NoNewline -ForegroundColor Green
                        write-host "Icon selected: " -NoNewline
                        write-host "$Item`n" -ForegroundColor Green
                        Start-Sleep -Seconds 2
                        break
                    }
                }
                Else
                {
                    ## Grab the first found application path
                    write-host "$Item`n" -ForegroundColor Green
                    $shortcut_iconLocation = "$Item"  # Assign the icon location
                    Start-Sleep -Seconds 2
                    break  # Exit loop after finding first valid icon
                }
            }
        }
    }

    # Set icon if found
    if (-not [string]::IsNullOrEmpty($shortcut_iconLocation)) {
        $shortcut.IconLocation = "$shortcut_iconLocation,0"
        if ($verbose) {
            Write-Host "Icon set to: $shortcut_iconLocation"
        }
    }

    # -- SET COMMAND --
    if ([string]::IsNullOrEmpty($shortcut_command)) {
        $shortcut_command = "calc.exe"  # Default command
        if ($verbose) {
            Write-Host "No command provided, using default: $shortcut_command"
        }
    }
    else {
        if ($verbose) {
            Write-Host "Using provided command: $shortcut_command"
        }
    }
    
    $shortcut.TargetPath = $Powershell_location
    $shortcut.Arguments = "-Command `"$shortcut_command`""

    # -- SET DESCRIPTION --
    if ([string]::IsNullOrEmpty($shortcut_description)) {
        $shortcut_description = "Windows Shortcut"  # Default description
        if ($verbose) {
            Write-Host "No description provided, using default: $shortcut_description"
        }
    }
    else {
        if ($verbose) {
            Write-Host "Using provided description: $shortcut_description"
        }
    }
    $shortcut.Description = $shortcut_description

    # -- SAVE SHORTCUT --
    $shortcut.Save()
    
    if ($verbose) {
        Write-Host "Shortcut created successfully at: $shortcut_savepath"
    }

    # -- RUN AS ADMINISTRATOR --
    
    if ($shortcut_runasadmin) {
        $bytes = [System.IO.File]::ReadAllBytes($shortcut_savepath)
        $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
        [System.IO.File]::WriteAllBytes($shortcut_savepath, $bytes)
        if ($verbose) {
            Write-Host "Shortcut set to run as administrator."
        }
    }


    # -- Hidden terminal window --
    # -- Add hidden window argument --
    if ($shortcut_runhidden) {
        $shortcut.Arguments += " -WindowStyle Hidden"
        if ($verbose) {
            Write-Host "Shortcut set to run in hidden terminal window."
        }
    }

    Write-Host "`n=== SHORTCUT CREATED SUCCESSFULLY ===" -ForegroundColor Green
    Write-Host "Location: $shortcut_savepath" -ForegroundColor Cyan
    Write-Host "Icon: $(if($shortcut_iconLocation) {$shortcut_iconLocation} else {'Default'})" -ForegroundColor Cyan
    Write-Host "Description: $shortcut_description" -ForegroundColor Cyan
    Write-Host "Command: $shortcut_command" -ForegroundColor Cyan
    Write-Host "Run as Admin: $shortcut_runasadmin" -ForegroundColor Cyan
    Write-Host "======================================`n" -ForegroundColor Green
}
menu