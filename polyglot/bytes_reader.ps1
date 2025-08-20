#global vars
$global:filepath 
$global:main = $True
$global:stayonfile = $True

function menu{
    #Banner
    Write-Host "
    .............................:=+-.................
    ........................:+##--+:..................
    ...................:=%%%=:+#:-:......:=-..........
    ...............:+%%%#--##:=+....:#*#%=:==*........
    ...........:+%%%%%%#:.-#%-:-....:#=%-%::#-%:......
    .........:=*###*=::-+#%%#*=:.....:+%+%:.%:#*......
    .::::.:+:=#%%%%%%%%%%%%%%%%%%%%#*-+%%:.##:%%%%=:::
    ::::.:*%%*=-::-=+#%%%%%%%%%%%%%%%#=:.=%*:#++%:....
    ...:#%+.-%%%%%%%%%*=::::....::::.:-%%%:*#-#:::::::
    ::+%--#%#%*-#%*--=+*%%%%%%%*+*%%%#=:=#=:::::::::::
    =-.+%%-:+%:#*:#%-::%%%:%%%%%+:..:=:.::::::::::::::
    -#%%#-::-%%=:+%#=%%%:#%%*:::::::::::::::::::::::::
    ::::+%%%%%*%%%%%%%*-%*.%%%::::::::::::::::::::::::
    ::::#+::-+*%%+::#%%++%%*:*%%*:::::::::::::::::::::
    :::::::*%%%%%*+%:*%%#-+:*%=:%%%#::::::::::::::::::
    :::::::=*=:%%#-%%-+%%%:+:::=**=-+#%%+=::::::::::::
    ::::::::*#:%%#-%*%+-%%%+:-::::::::::::::::::::::::
    ::::::::=%:#%#-%-:%#:%%%%-::::::::::::*%%##%%%-:::
    :::::::::%:#%*=%:::=%:#%#%%::::::::::#%:-#%#:%%-::
    :::::::::#:%%-**:::::**-%#%%%=:::::::#=-%-:*%*%*::
    :::::::::#:%%:#-:::::::*==%*%%%*::::::*-=:::%%%-::
    ::::::::-==%*-*::::::::::-:*%+%%%%*=:::::-*%%%::::
    ::::::::-:%%:#:::::::::::::::*%+%%#%%%%%%%%=::::::
    :::::::::=%-+::::::::::::::::::*%+#%+:::::::--::::
    :::::::::%+::::::::::::::::::::::+%*=%%+::---=%-::
    ::::::::++:::::::::::::::::::::::::-#%=-*%%%*:%=::
    :::::::--:::::::::::::::::::::::::::::-*%%%#%%=:::
    "
    Write-Host "

                )              (                (           (     
    (    ( /(   *   )      )\ )       (     )\ )        )\ )  
    ( )\   )\())` )  /( (   (()/( (     )\   (()/(   (   (()/(  
    )((_) ((_)\  ( )(_)))\   /(_)))\ ((((_)(  /(_))  )\   /(_)) 
    ((_)_ __ ((_)(_(_())((_) (_)) ((_) )\ _ )\(_))_  ((_) (_))   
    | _ )\ \ / /|_   _|| __|| _ \| __|(_)_\(_)|   \ | __|| _ \  
    | _ \ \ V /   | |  | _| |   /| _|  / _ \  | |) || _| |   /  
    |___/  |_|    |_|  |___||_|_\|___|/_/ \_\ |___/ |___||_|_\  
                                                             
    "
    Write-Host "Bytes Reader `nBy JOB (Joshua O' Brien)`nRead bytes from a file and display them in hex format."

}


function display_bytes{
    while ($global:main) {

        
        #Display banner
        menu
        $global:filepath = Read-Host "Enter the file path to read"
        #Input validation
        if (-not (Test-Path $global:filepath)) {
            Write-Host "File not found: $global:filepath"
            return
        }
        while ($global:stayonfile) {
            $choice = Read-Host "Read how many bytes? ( 'A' - all , 'N' - exit 'NF' - new file)" 
            if ($choice -eq 'A') {
                $bytes = [System.IO.File]::ReadAllBytes($global:filepath)
            } elseif ($choice -eq 'NF') {
                $filePath = Read-Host "Enter the file path to read"
                continue
            } elseif ($choice -eq 'N') {
                Write-Host "Exiting Bytes Reader."
                $global:main = $False
                return
            } else {
                try{
                    $bytes = [System.IO.File]::ReadAllBytes($global:filepath)[0..($choice - 1)]
                }
                catch {
                    Write-Host "Invalid number of bytes specified. Please try again."
                    continue
                }
                $bytes | Format-Hex
                $onfilechoice = Read-Host "Do you want to read more bytes from the same file? (Y/N)"
                if ($onfilechoice -eq 'N') {
                    $global:stayonfile = $False
                } elseif ($onfilechoice -eq 'Y') {
                    $global:stayonfile = $True
                } else {
                    Write-Host "Invalid choice. Exiting."
                    $global:main = $False
                    return
                }
            }
        }

        
    }
}

display_bytes