#global vars
$global:main_menu = $true
$global:main_menu_banner = $true
$global:payload = $null
$global:imagePath = $null
$global:output_imagepath =$null
Add-Type -AssemblyName System.Drawing

function menu{
    while ($global:main_menu){
        if ($global:main_menu_banner){
            write-host "
        @@@@@@@@@@@@@@@@@@%###%%%%%%@@@@@%%@@@@@@@@@@@@@@@
        @@@@@@@@@@@@@@@@@%#**#####*+====++#@@@@@@@@@@@@@@@
        @@@@@@@@@@@@@@@@%***#%#####=:-*###@@@@@@@@@@@@@@@@
        @@@@@@@@@@@@@@%#*##%%@@@@@%%*+###%@@@@@@@@@@@@@@@@
        @@@@@@@@%#*+=---#%@%@@@%%#%*==++*#%%@@@@@@@@@@@@@@
        @@@@@@@%*+***+=+%%%%%@@#%##%#+==*#%%%@@@@@@@@@@@@@
        @@@@@@@@@@%######%###%@#%%###++*#*%%%%@@@@@@@@@@@@
        @@@@@@@@@@@%%#########%##%##*####*%%%%@@@@@@@@@@@@
        @@@@@@@@@@@%@****###*#%%%%*####**#%#%%@@@@@@@@@@@@
        @@@@@@@@@@@%%%*****##%%@@@@@%#***#%%@@@@@@@@@@@@@@
        @@@@@@@@@@@@@%%###**%%@@@@@%####%%@@@@@@@@@@@@@@@@
        @@@@@@@@@@@@@@%%#%##%#%@@@%+*%%%@@@@@@@#---=*##*+*
        @@@@@@@@@@@@@@@@%%%%%#%#=+=+*#%%@@@@@@@@%*=-======
        @@@@@@@@@@@@@@@@%%##%###*****#%@@@@@@@@@@%######%@
        @@@@@@@@@@@@@@%%%%%%%%%%%%%%%%@%%@@@@@@%%%%%%%@@@@
        @@@@@@@@@@%#**##@%%%%%%%%#%%%%%%%#%@#%%#*##%@@@@@@
        @@@@@@@@%=::::-=*%#***#%@%=#%@%@@@%**--=++*@@@@@@@
        @@@@@@@*-:::-------=**%@@#==*%@@@@@#=-:+%%%@@@@@@@
        @@@@@%*-::::::::---:=*%@@*=-=#%%@@%*=-:-%%*+%@@@@@
        @@@@@#-:-::::::--:::::-*+:::-+==+*=::-::+#=-=%@@@@
        @@@@@%=:::-::-+=--::::----::--:--=-::::::+-:-#@@@@
        @@@@@@#=::---+@@%**#*****++++**++===-:::::::-#@@@@
        @@@@@@%+::----+@@@%#=+*####**###%%%%-:::::::=%@@@@
        @@@@@@@*-:------*%%#*****+=--+=+#%%@*:::::::=%@@@@
        @@@@@@@#=:::-::=%%#+=-=*++=::+*++#@@@+::::::=%@@@@
        @@@@@@@#+-:::::+*=::::+***:::-**++%@@%=:::::-%@@@@
        @@@@@@@#-::::::-:::::::::::::::--=%@@%+:::::-#@@@@
        @@@@@@@#-::::-+-:---:-++:::::--=--#@@%---::::*@@@@
        @@@@#=*#-::-:=-=---=++***-:::---=-=%@*=-:::::+@@@@
        @@@@#:+*-:--=--=+###*+****+-:-======@=---:---+@@@@
        @@@@+-*#-:-+==*%%%%%%#+=+=***++==+=-*===-::--*@@@@
        @@@%-=%#=:-+=#%%%%%@@@*:-**********+=-==---==#@@@@
        @@@%--##=---*%%%@@@@@@@-:=*****#%%%%*+=-=-:-*@@@@@
        @@@@*:-+==-:+%%@@@@@@@@-:-***#%%%%%%%+----:=%@@@@@
        @@@@@#=+=---=*#%%%%%%%#---+*#%%%%%%%%%+----*@@@@@@
        @@@@@@@%+---=++-=*###%%#**#%%%%%%%%%%@@#-=+#@@@@@@
        @@@@@@@%#=--==+=+%@@@@@@@@@@%%%%%%%%%%@@@*-*@@@@@@
        .............................:-+-.................
        ........................:+##-:+:..................
        ...................:-#%%+:+#:-:......:=:..........
        ...............:+%%%#--##-=+....:#*%%=:=++........
        ...........:+%%%%%%#:.-#%-:-....:#+%-%::#=#.......
        .........:=*###*=::-+#%%#*=:.....:+%+%::%:#*......
        .::::.:+:=#%%%%%%%%%%%%%%%%%%%%%*-+%%..##:%%%%-:::
        .::::.+%%*=-::-=+#%%%%%%%%%%%%%%%#=:.=%*:#++#:....
        ...:*%*.-%%%%%%%%%*=::::....::::.:-%%%:**-#:.:::::
        ::=%--#%#%*-##*--=+*%%%%%%%*+*#%%#+:=#-:::::::::::
        --.+%%-:+%-#*:#%-::%%%:%%%%%+:..:=-:::::::::::::::
        -#%%#-::-%%=-+%#=#%%-#%%*.::::::::::::::::::::::::
        ::::+%%%%##%%%%%%%+-%*.%%%::::::::::::::::::::::::
        ::::*=::-=+%%+::#%%++%%*:*%%*:::::::::::::::::::::
        :::::::*%%%%%*+%-*%%#-+:*%=:#%%#::::::::::::::::::
        :::::::-*=:%%#-%%-+%%%:+:::=**=-+#%#+=::::::::::::
        ::::::::*#:#%#-%*%+-%%%+--:::::::::::::::--:::::::
        ::::::::=%.#%#-%-:%#:%%%%-::::::::::::#%%##%%%::::
        :::::::::%.#%*=%:::=%:*%#%%-:::::::::#%:-#%#:%%-::
        :::::::::#:%%-**:::::**-%#%%%=:::::::#=-%-:*%*%+::
        :::::::::#:%%:#-:::::::*==%*%%%*::::::*-=:::%%%-::
        ::::::::-+-%*-*::::::::::-:+%+%%%%*=:::::-*%%%::::
        ::::::::-:#%:#:::::::::::::::*%+%%#%%%%%%%#-::::::
        :::::::::-%-+::::::::::::::::::*%+#%+:::::::--::::
        :::::::::%+::::::::::::::::::::::+%*-%%*::--:=%-::
        ::::::::++::::::::::::::::::::::::::#%=-*#%%*:%=::
        :::::::--:::::::::::::::::::::::::::::-+%%%%%%-:::
            "
        }
        Write-Host "Embed PS code in images, by JOB ( Joshua O' Brien )"
        
        Write-Host "[1] Enter payload/command"
        Write-Host "[2] Enter image path"
        Write-Host "[3] Enter output image path"
        Write-Host "[4] Display current settings"
        Write-Host "[c] Embed PowerShell code in image"
        Write-Host "[r] Embed RSA-encrypted PowerShell code in image"
        Write-Host "[e] Extract PowerShell code from image (remember to set input image path again)" 
        Write-Host "[d] Decrypt RSA payload from image (requires private key)"
        Write-Host "[q] Quit"
        $global:main_menu_banner = $false
        $choice = Read-Host "Select an option"
        switch ($choice) {
            1 {
                $global:payload = Read-Host "Enter payload/command"
                Write-Host "Payload set to: $global:payload" -ForegroundColor Green
            }
            2 {
                $global:imagePath = Read-Host "Enter image path"
                Write-Host "Image path set to: $global:imagePath" -ForegroundColor Green
            }
            3{
                $global:output_imagepath = Read-Host "Enter output image path"
                Write-Host "Output image path set to: $global:output_imagepath" -ForegroundColor Green
            }
            4 {
                Write-Host "Current settings:" -ForegroundColor Cyan
                Write-Host "Payload: $global:payload" -ForegroundColor Cyan
                Write-Host "Image Path: $global:imagePath" -ForegroundColor Cyan
                Write-Host "Output Image Path: $global:output_imagepath" -ForegroundColor Cyan
            }
            "c"{
                $validationErrors = @()
                
                if ([string]::IsNullOrWhiteSpace($global:payload)) {
                    $validationErrors += "Payload is required. Please set it using option [1]."
                }
                
                if ([string]::IsNullOrWhiteSpace($global:imagePath)) {
                    $validationErrors += "Image path is required. Please set it using option [2]."
                } elseif (-not (Test-Path $global:imagePath)) {
                    $validationErrors += "Image file does not exist: $global:imagePath"
                } elseif ($global:imagePath -notmatch '\.(png|jpg|jpeg|bmp|gif)$') {
                    $validationErrors += "Invalid image format. Supported formats: png, jpg, jpeg, bmp, gif"
                }
                
                if ([string]::IsNullOrWhiteSpace($global:output_imagepath)) {
                    $validationErrors += "Output image path is required. Please set it using option [3]."
                } elseif ($global:output_imagepath -notmatch '\.(png|jpg|jpeg|bmp|gif)$') {
                    $validationErrors += "Invalid output image format. Supported formats: png, jpg, jpeg, bmp, gif"
                }
                
                if ($global:payload.Length -gt 65535) {
                    $validationErrors += "Payload too large (max 65535 bytes supported)."
                }
                
                if ($validationErrors.Count -gt 0) {
                    Write-Host "Validation errors:" -ForegroundColor Red
                    $validationErrors | ForEach-Object { Write-Host "- $_" -ForegroundColor Yellow }
                } else {
                    try {
                        Embed_PowerShellCodeInImagev2 -ImagePath $global:imagePath -PayloadBase64 $global:payload -OutputImagePath $global:output_imagepath
                        Write-Host "Embedding completed successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error during embedding: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "r" {
                $validationErrors = @()
                
                if ([string]::IsNullOrWhiteSpace($global:imagePath)) {
                    $validationErrors += "Image path is required. Please set it using option [2]."
                } elseif (-not (Test-Path $global:imagePath)) {
                    $validationErrors += "Image file does not exist: $global:imagePath"
                } elseif ($global:imagePath -notmatch '\.(png|jpg|jpeg|bmp|gif)$') {
                    $validationErrors += "Invalid image format. Supported formats: png, jpg, jpeg, bmp, gif"
                }
                
                if ([string]::IsNullOrWhiteSpace($global:output_imagepath)) {
                    $validationErrors += "Output image path is required. Please set it using option [3]."
                } elseif ($global:output_imagepath -notmatch '\.(png|jpg|jpeg|bmp|gif)$') {
                    $validationErrors += "Invalid output image format. Supported formats: png, jpg, jpeg, bmp, gif"
                }
                
                if ($validationErrors.Count -gt 0) {
                    Write-Host "Validation errors:" -ForegroundColor Red
                    $validationErrors | ForEach-Object { Write-Host "- $_" -ForegroundColor Yellow }
                } else {
                    Write-Host "Enter PowerShell code sections for RSA encryption:" -ForegroundColor Cyan
                    $plainSection = Read-Host "Enter plain/visible PowerShell code"
                    $secretSection = Read-Host "Enter secret PowerShell code (will be encrypted)"
                    
                    try {
                        $result = Embed_RSA_PowerShellCodeInImage -ImagePath $global:imagePath -PlainSection $plainSection -SecretSection $secretSection -OutputImagePath $global:output_imagepath
                        Write-Host "RSA embedding completed successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error during RSA embedding: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "e"{
                if ([string]::IsNullOrWhiteSpace($global:imagePath)) {
                    Write-Host "Image path is required for extraction. Please set it using option [2]." -ForegroundColor Red
                } elseif (-not (Test-Path $global:imagePath)) {
                    Write-Host "Image file does not exist: $global:imagePath" -ForegroundColor Red
                } else {
                    try {
                        $extractedData = Extract_PowerShellCodeFromImagev2 -ImagePath $global:imagePath
                        Write-Host "Extracted data:" -ForegroundColor Green
                        Write-Host $extractedData
                    } catch {
                        Write-Host "Error during extraction: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "d" {
                if ([string]::IsNullOrWhiteSpace($global:imagePath)) {
                    Write-Host "Image path is required for RSA decryption. Please set it using option [2]." -ForegroundColor Red
                } elseif (-not (Test-Path $global:imagePath)) {
                    Write-Host "Image file does not exist: $global:imagePath" -ForegroundColor Red
                } else {

                    $privateKey = $null
                    $keyFile = Read-Host "Enter path to private key file"
                    if (Test-Path $keyFile) {
                        $privateKey = Get-Content $keyFile -Raw
                    } else {
                        Write-Host "Private key file not found: $keyFile" -ForegroundColor Red
                        continue
                    }
                    if ($privateKey) {
                        try {
                            $result = Extract_And_Decrypt_RSAPayload -ImagePath $global:imagePath -PrivateKeyXml $privateKey
                            Write-Host "RSA decryption completed successfully!" -ForegroundColor Green
                        } catch {
                            Write-Host "Error during RSA decryption: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
            "q" {
                $global:main_menu = $false
                Write-Host "Goodbye!" -ForegroundColor Green
            }
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
            }
        }
    }
}

function Inflate_ImageIfNeeded {
    param (
        [string]$ImagePath,
        [int]$MinPixels,           
        [string]$OutputImagePath 
    )

    $Bitmap = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($ImagePath)
    $currentPixels = $Bitmap.Width * $Bitmap.Height

    if ($currentPixels -ge $MinPixels) {
        $Bitmap.Save($OutputImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
        $Bitmap.Dispose()
        return
    }

    $aspect = $Bitmap.Width / $Bitmap.Height
    $newHeight = [math]::Ceiling([math]::Sqrt($MinPixels / $aspect))
    $newWidth = [math]::Ceiling($newHeight * $aspect)
    $newBitmap = New-Object System.Drawing.Bitmap $newWidth, $newHeight
    $graphics = [System.Drawing.Graphics]::FromImage($newBitmap)
    $graphics.DrawImage($Bitmap, 0, 0, $newWidth, $newHeight)
    $newBitmap.Save($OutputImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $Bitmap.Dispose()
    $newBitmap.Dispose()
}
function Embed_PowerShellCodeInImagev2{
    param (
        [string]$ImagePath,         
        [string]$PayloadBase64,     
        [string]$OutputImagePath    
    )
    Write-Host "Embedding payload of length: $($PayloadBase64.Length) bytes" -ForegroundColor Yellow
    $payloadLength = $PayloadBase64.Length
    if ($payloadLength -gt 65535) {
        throw "Payload too large (max 65535 bytes supported)."
    }

    # Convert length to two bytes (MSB, LSB)
    $lenMSB = [math]::Floor($payloadLength / 256)
    $lenLSB = $payloadLength % 256

    # Calculate required pixels: +1 for length pixel, 3 chars per pixel for the rest
    $numDataPixels = [math]::Ceiling($payloadLength / 3)
    $totalPixelsNeeded = 1 + $numDataPixels

    $Bitmap = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($ImagePath)
    if ($Bitmap.Width * $Bitmap.Height -lt $totalPixelsNeeded) {
        Write-Host "Inflating image to accommodate payload..." -ForegroundColor Yellow
        $Bitmap.Dispose()
        Inflate-ImageIfNeeded -ImagePath $ImagePath -MinPixels $totalPixelsNeeded -OutputImagePath $OutputImagePath
        $Bitmap = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($OutputImagePath)
    }

    $Rect = New-Object System.Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)
    $BitmapData = $Bitmap.LockBits($Rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $Bitmap.PixelFormat)
    $Scan0 = $BitmapData.Scan0
    $Stride = $BitmapData.Stride

    # Write length to first pixel (0,0)
    $PixelAddress = [System.IntPtr]::Add($Scan0, 0)
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 0, 0)        # B (unused)
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 1, $lenLSB)   # G
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 2, $lenMSB)   # R
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 3, 255)       # A

    # Embed payload from pixel (0,1) onwards
    $PayloadIndex = 0
    $pixelNum = 1
    $height = $Bitmap.Height
    $width = $Bitmap.Width

    for ($i = 1; $i -le $numDataPixels; $i++) {
        $y = [math]::Floor($pixelNum / $width)
        $x = $pixelNum % $width
        $PixelAddress = [System.IntPtr]::Add($Scan0, ($y * $Stride) + ($x * 4))
        $R = 0; $G = 0; $B = 0
        if ($PayloadIndex -lt $payloadLength) { $R = [int][char]$PayloadBase64[$PayloadIndex]; $PayloadIndex++ }
        if ($PayloadIndex -lt $payloadLength) { $G = [int][char]$PayloadBase64[$PayloadIndex]; $PayloadIndex++ }
        if ($PayloadIndex -lt $payloadLength) { $B = [int][char]$PayloadBase64[$PayloadIndex]; $PayloadIndex++ }
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 0, $B)
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 1, $G)
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 2, $R)
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 3, 255)
        $pixelNum++
    }

    $Bitmap.UnlockBits($BitmapData)
    $Bitmap.Save($OutputImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "[JOB] Payload embedded and saved to $OutputImagePath"
    $Bitmap.Dispose()

}

function Extract_PowerShellCodeFromImagev2 {
    param (
        [string]$ImagePath
    )

    Write-Host "Extracting data from $ImagePath" -ForegroundColor Yellow
    $Bitmap = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($ImagePath)
    $Rect = New-Object System.Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)
    $BitmapData = $Bitmap.LockBits($Rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $Bitmap.PixelFormat)
    $Scan0 = $BitmapData.Scan0
    $Stride = $BitmapData.Stride

    # Read length from first pixel (0,0)
    $PixelAddress = [System.IntPtr]::Add($Scan0, 0)
    $lenLSB = [System.Runtime.InteropServices.Marshal]::ReadByte($PixelAddress, 1)
    $lenMSB = [System.Runtime.InteropServices.Marshal]::ReadByte($PixelAddress, 2)
    $payloadLength = ($lenMSB * 256) + $lenLSB

    # Extract payload from pixel (0,1) onwards
    $ExtractedChars = New-Object System.Collections.Generic.List[char]
    $pixelNum = 1
    $width = $Bitmap.Width
    $height = $Bitmap.Height

    while ($ExtractedChars.Count -lt $payloadLength) {
        $y = [math]::Floor($pixelNum / $width)
        $x = $pixelNum % $width
        $PixelAddress = [System.IntPtr]::Add($Scan0, ($y * $Stride) + ($x * 4))
        $R = [System.Runtime.InteropServices.Marshal]::ReadByte($PixelAddress, 2)
        $G = [System.Runtime.InteropServices.Marshal]::ReadByte($PixelAddress, 1)
        $B = [System.Runtime.InteropServices.Marshal]::ReadByte($PixelAddress, 0)
        if ($ExtractedChars.Count -lt $payloadLength) { $ExtractedChars.Add([char]$R) }
        if ($ExtractedChars.Count -lt $payloadLength) { $ExtractedChars.Add([char]$G) }
        if ($ExtractedChars.Count -lt $payloadLength) { $ExtractedChars.Add([char]$B) }
        $pixelNum++
    }

    $Bitmap.UnlockBits($BitmapData)
    $Bitmap.Dispose()
    $ExtractedBase64 = [string]::Join("", ($ExtractedChars.ToArray() | Select-Object -First $payloadLength))
    Write-Host "Data from image extracted successfully." -ForegroundColor Green
    return $ExtractedBase64
}


function Embed_RSA_PowerShellCodeInImage {
    param (
        [string]$ImagePath,         
        [string]$PlainSection,      # Visible PowerShell code
        [string]$SecretSection,     # Secret PowerShell code to encrypt
        [string]$OutputImagePath    
    )
    
    Write-Host "Creating RSA-encrypted PowerShell payload..." -ForegroundColor Yellow
    
    # Generate RSA key pair
    $keys = New_RSAKeyPairv2
    Write-Host "RSA Key Pair Generated!" -ForegroundColor Green
    
    # Encrypt the secret section
    $encryptedBase64 = Encrypt_SectionWithRSAv2 -PlainText $SecretSection -PublicKeyXml $keys.PublicKey
    Write-Host "Secret section encrypted successfully." -ForegroundColor Green
    
    # Build the complete payload
    $payload = $PlainSection + "`n#RSA_ENC_START`n" + $encryptedBase64 + "`n#RSA_ENC_END"
    
    Write-Host "Complete payload created. Length: $($payload.Length) bytes" -ForegroundColor Cyan
    
    # Validate payload size
    if ($payload.Length -gt 65535) {
        throw "Combined payload too large (max 65535 bytes supported). Consider shortening the code sections."
    }
    
    # Calculate required pixels
    $payloadLength = $payload.Length
    $lenMSB = [math]::Floor($payloadLength / 256)
    $lenLSB = $payloadLength % 256
    $numDataPixels = [math]::Ceiling($payloadLength / 3)
    $totalPixelsNeeded = 1 + $numDataPixels
    
    # Load and prepare image
    $Bitmap = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($ImagePath)
    if ($Bitmap.Width * $Bitmap.Height -lt $totalPixelsNeeded) {
        Write-Host "Inflating image to accommodate RSA payload..." -ForegroundColor Yellow
        $Bitmap.Dispose()
        Inflate_ImageIfNeeded -ImagePath $ImagePath -MinPixels $totalPixelsNeeded -OutputImagePath $OutputImagePath
        $Bitmap = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($OutputImagePath)
    }
    
    # Lock bitmap for direct memory access
    $Rect = New-Object System.Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)
    $BitmapData = $Bitmap.LockBits($Rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $Bitmap.PixelFormat)
    $Scan0 = $BitmapData.Scan0
    $Stride = $BitmapData.Stride
    
    # Write payload length to first pixel (0,0)
    $PixelAddress = [System.IntPtr]::Add($Scan0, 0)
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 0, 0)        # B (unused)
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 1, $lenLSB)   # G (LSB)
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 2, $lenMSB)   # R (MSB)
    [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 3, 255)       # A (alpha)
    
    # Embed RSA payload starting from pixel (0,1)
    $PayloadIndex = 0
    $pixelNum = 1
    $height = $Bitmap.Height
    $width = $Bitmap.Width
    
    Write-Host "Embedding RSA payload into image pixels..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le $numDataPixels; $i++) {
        $y = [math]::Floor($pixelNum / $width)
        $x = $pixelNum % $width
        $PixelAddress = [System.IntPtr]::Add($Scan0, ($y * $Stride) + ($x * 4))
        
        $R = 0; $G = 0; $B = 0
        if ($PayloadIndex -lt $payloadLength) { $R = [int][char]$payload[$PayloadIndex]; $PayloadIndex++ }
        if ($PayloadIndex -lt $payloadLength) { $G = [int][char]$payload[$PayloadIndex]; $PayloadIndex++ }
        if ($PayloadIndex -lt $payloadLength) { $B = [int][char]$payload[$PayloadIndex]; $PayloadIndex++ }
        
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 0, $B)
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 1, $G)
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 2, $R)
        [System.Runtime.InteropServices.Marshal]::WriteByte($PixelAddress, 3, 255)
        $pixelNum++
    }
    
    # Save the image
    $Bitmap.UnlockBits($BitmapData)
    $Bitmap.Save($OutputImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
    
    Write-Host "[JOB] RSA-encrypted payload embedded successfully!" -ForegroundColor Green
    Write-Host "Image saved to: $OutputImagePath" -ForegroundColor Green
    
    
    
    # Save keys to files for convenience
    $keyDir = Split-Path $OutputImagePath -Parent
    $publicKeyFile = "rsa_public_key.xml"
    $privateKeyFile = "rsa_private_key.xml"
    
    $keys.PublicKey | Out-File -FilePath $publicKeyFile -Encoding UTF8
    $keys.PrivateKey | Out-File -FilePath $privateKeyFile -Encoding UTF8
    
    Write-Host "Keys also saved to:" -ForegroundColor Cyan
    Write-Host "Public Key: $publicKeyFile" -ForegroundColor Cyan
    Write-Host "Private Key: $privateKeyFile" -ForegroundColor Cyan
    
    return @{
        OutputPath = $OutputImagePath
        PublicKey = $keys.PublicKey
        PrivateKey = $keys.PrivateKey
        PublicKeyFile = $publicKeyFile
        PrivateKeyFile = $privateKeyFile
    }
}

function New_RSAKeyPairv2 {
    $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new(2048)
    return @{
        PublicKey = $rsa.ToXmlString($false)
        PrivateKey = $rsa.ToXmlString($true)
    }
}
function Encrypt_SectionWithRSAv2 {
    param (
        [string]$PlainText,
        [string]$PublicKeyXml
    )
    $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new()
    $rsa.FromXmlString($PublicKeyXml)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $encBytes = $rsa.Encrypt($bytes, $true)
    return [Convert]::ToBase64String($encBytes)
}

function Decrypt_SectionWithRSAv2 {
    param (
        [string]$Base64Cipher,
        [string]$PrivateKeyXml
    )
    $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new()
    $rsa.FromXmlString($PrivateKeyXml)
    $encBytes = [Convert]::FromBase64String($Base64Cipher)
    $plainBytes = $rsa.Decrypt($encBytes, $true)
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
}

function Parse_RSAPayloadv2 {
    param (
        [string]$Payload
    )
    if ($Payload -match '(?s)#RSA_ENC_START\s*(.*?)\s*#RSA_ENC_END') {
        $encSection = $matches[1].Trim()
        $plainSection = $Payload -split '#RSA_ENC_START' | Select-Object -First 1
        return @{
            PlainSection = $plainSection
            EncryptedSectionBase64 = $encSection
        }
    } else {
        throw "No RSA encrypted section found in payload."
    }
}

function Extract_And_Decrypt_RSAPayload {
    param (
        [string]$ImagePath,
        [string]$PrivateKeyXml
    )
    try {
        $extractedPayload = Extract_PowerShellCodeFromImagev2 -ImagePath $ImagePath
        $parsed = Parse_RSAPayloadv2 -Payload $extractedPayload
        $decryptedSection = Decrypt_SectionWithRSAv2 -Base64Cipher $parsed.EncryptedSectionBase64 -PrivateKeyXml $PrivateKeyXml
        
        Write-Host "Plain Section:" -ForegroundColor Green
        Write-Host $parsed.PlainSection
        Write-Host "`nDecrypted Secret Section:" -ForegroundColor Green
        Write-Host $decryptedSection
        Write-Host "`nComplete Reconstructed Code:" -ForegroundColor Cyan
        Write-Host ($parsed.PlainSection + $decryptedSection)
        
        return @{
            PlainSection = $parsed.PlainSection
            DecryptedSection = $decryptedSection
            CompleteCode = $parsed.PlainSection + $decryptedSection
        }
    } catch {
        Write-Host "Error extracting/decrypting RSA payload: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}


menu




