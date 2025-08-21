#global vars
$global:main_menu = $true
$global:main_menu_banner = $true
$global:payload = $null
$global:imagePath = $null
$global:output_imagepath = $null
$global:encryption_algorithm = "RSA"
Add-Type -AssemblyName System.Drawing

# Enhanced validation functions
function Validate-Payload {
    param (
        [string]$payload
    )
    $errors = @()
    
    if ([string]::IsNullOrWhiteSpace($payload)) {
        $errors += "Payload is required. Please set it using option [1]."
    } elseif ($payload.Length -gt 65535) {
        $errors += "Payload too large (max 65535 bytes supported)."
    }
    
    return $errors
}

function Validate-InputImagePath {
    param (
        [string]$imagePath
    )
    $errors = @()
    
    if ([string]::IsNullOrWhiteSpace($imagePath)) {
        $errors += "Image path is required. Please set it using option [2]."
    } elseif (-not (Test-Path $imagePath)) {
        $errors += "Image file does not exist: $imagePath"
    } elseif ($imagePath -notmatch '\.(png|jpg|jpeg|bmp|gif)$') {
        $errors += "Invalid image format. Supported formats: png, jpg, jpeg, bmp, gif"
    }
    
    return $errors
}

function Validate-OutputImagePath {
    param (
        [string]$outputImagePath
    )
    $errors = @()
    
    if ([string]::IsNullOrWhiteSpace($outputImagePath)) {
        $errors += "Output image path is required. Please set it using option [3]."
    } elseif ($outputImagePath -notmatch '\.(png|jpg|jpeg|bmp|gif)$') {
        $errors += "Invalid output image format. Supported formats: png, jpg, jpeg, bmp, gif"
    }
    
    return $errors
}

function Validate-AllInputs {
    param (
        [string]$payload = $global:payload,
        [string]$imagePath = $global:imagePath,
        [string]$outputImagePath = $global:output_imagepath,
        [switch]$SkipPayload
    )
    
    $allErrors = @()
    
    if (-not $SkipPayload) {
        $allErrors += Validate-Payload -payload $payload
    }
    $allErrors += Validate-InputImagePath -imagePath $imagePath
    $allErrors += Validate-OutputImagePath -outputImagePath $outputImagePath
    
    return $allErrors
}

function Show-ValidationErrors {
    param (
        [string[]]$errors
    )
    
    if ($errors.Count -gt 0) {
        Write-Host "Validation errors:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Yellow }
        return $true
    }
    return $false
}

# Encryption Algorithm Interface
class EncryptionAlgorithm {
    [string] $Name
    [string] $Description
    
    EncryptionAlgorithm([string]$name, [string]$description) {
        $this.Name = $name
        $this.Description = $description
    }
    
    [hashtable] GenerateKeys() {
        throw "GenerateKeys method must be implemented"
    }
    
    [string] Encrypt([string]$plainText, [hashtable]$keys) {
        throw "Encrypt method must be implemented"
    }
    
    [string] Decrypt([string]$cipherText, [hashtable]$keys) {
        throw "Decrypt method must be implemented"
    }
    
    [hashtable] EmbedEncrypted([string]$imagePath, [string]$plainSection, [string]$secretSection, [string]$outputImagePath) {
        throw "EmbedEncrypted method must be implemented"
    }
    
    [hashtable] ExtractAndDecrypt([string]$imagePath, [hashtable]$keys) {
        throw "ExtractAndDecrypt method must be implemented"
    }
}

# RSA Implementation
class RSAEncryption : EncryptionAlgorithm {
    RSAEncryption() : base("RSA", "RSA 2048-bit encryption") {}
    
    [hashtable] GenerateKeys() {
        $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new(2048)
        return @{
            PublicKey = $rsa.ToXmlString($false)
            PrivateKey = $rsa.ToXmlString($true)
        }
    }
    
    [string] Encrypt([string]$plainText, [hashtable]$keys) {
        $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new()
        $rsa.FromXmlString($keys.PublicKey)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($plainText)
        $encBytes = $rsa.Encrypt($bytes, $true)
        return [Convert]::ToBase64String($encBytes)
    }
    
    [string] Decrypt([string]$cipherText, [hashtable]$keys) {
        $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new()
        $rsa.FromXmlString($keys.PrivateKey)
        $encBytes = [Convert]::FromBase64String($cipherText)
        $plainBytes = $rsa.Decrypt($encBytes, $true)
        return [System.Text.Encoding]::UTF8.GetString($plainBytes)
    }
    
    [hashtable] EmbedEncrypted([string]$imagePath, [string]$plainSection, [string]$secretSection, [string]$outputImagePath) {
        Write-Host "Creating RSA-encrypted PowerShell payload..." -ForegroundColor Yellow
        
        $keys = $this.GenerateKeys()
        $encryptedBase64 = $this.Encrypt($secretSection, $keys)
        $payload = $plainSection + "`n#RSA_ENC_START`n" + $encryptedBase64 + "`n#RSA_ENC_END"
        
        # Use existing embedding function
        Embed_PowerShellCodeInImagev2 -ImagePath $imagePath -PayloadBase64 $payload -OutputImagePath $outputImagePath
        
        # Save keys
        $publicKeyFile = "rsa_public_key.xml"
        $privateKeyFile = "rsa_private_key.xml"
        $keys.PublicKey | Out-File -FilePath $publicKeyFile -Encoding UTF8
        $keys.PrivateKey | Out-File -FilePath $privateKeyFile -Encoding UTF8
        
        Write-Host "RSA keys saved to $publicKeyFile and $privateKeyFile" -ForegroundColor Cyan
        
        return @{
            OutputPath = $outputImagePath
            Keys = $keys
            PublicKeyFile = $publicKeyFile
            PrivateKeyFile = $privateKeyFile
        }
    }
    
    [hashtable] ExtractAndDecrypt([string]$imagePath, [hashtable]$keys) {
        $extractedPayload = Extract_PowerShellCodeFromImagev2 -ImagePath $imagePath
        
        if ($extractedPayload -match '(?s)#RSA_ENC_START\s*(.*?)\s*#RSA_ENC_END') {
            $encSection = $matches[1].Trim()
            $plainSection = $extractedPayload -split '#RSA_ENC_START' | Select-Object -First 1
            $decryptedSection = $this.Decrypt($encSection, $keys)
            
            return @{
                PlainSection = $plainSection
                DecryptedSection = $decryptedSection
                CompleteCode = $plainSection + $decryptedSection
            }
        } else {
            throw "No RSA encrypted section found in payload."
        }
    }
}

# Encryption Registry
$global:EncryptionAlgorithms = @{
    "RSA" = [RSAEncryption]::new()
}

function Get-AvailableAlgorithms {
    return $global:EncryptionAlgorithms.Keys
}

function Get-EncryptionAlgorithm {
    param([string]$name)
    return $global:EncryptionAlgorithms[$name]
}

function menu {
    while ($global:main_menu) {
        if ($global:main_menu_banner) {
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
        Write-Host "Current encryption algorithm: $global:encryption_algorithm" -ForegroundColor Magenta
        
        Write-Host "[1] Enter payload/command"
        Write-Host "[2] Enter input image path"
        Write-Host "[3] Enter output image path"
        Write-Host "[4] Display current settings"
        Write-Host "[5] Select encryption algorithm"
        Write-Host "[c] Embed PowerShell code in image"
        Write-Host "[e] Extract PowerShell code from image"
        Write-Host "[encrypt] Embed $global:encryption_algorithm encrypted PowerShell code in image"
        Write-Host "[decrypt] Decrypt $global:encryption_algorithm payload from image"
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
            3 {
                $global:output_imagepath = Read-Host "Enter output image path"
                Write-Host "Output image path set to: $global:output_imagepath" -ForegroundColor Green
            }
            4 {
                Write-Host "Current settings:" -ForegroundColor Cyan
                Write-Host "Payload: $global:payload" -ForegroundColor Cyan
                Write-Host "Image Path: $global:imagePath" -ForegroundColor Cyan
                Write-Host "Output Image Path: $global:output_imagepath" -ForegroundColor Cyan
                Write-Host "Encryption Algorithm: $global:encryption_algorithm" -ForegroundColor Cyan
            }
            5 {
                Write-Host "Available encryption algorithms:" -ForegroundColor Cyan
                $algorithms = @(Get-AvailableAlgorithms)
                
                if ($algorithms.Count -eq 0) {
                    Write-Host "No encryption algorithms available!" -ForegroundColor Red
                    continue
                }
                
                for ($i = 0; $i -lt $algorithms.Count; $i++) {
                    $algoName = $algorithms[$i]                    
                    try {
                        $algo = Get-EncryptionAlgorithm $algoName
                        if ($null -ne $algo) {
                            Write-Host "[$i] $($algo.Name) - $($algo.Description)" -ForegroundColor Yellow
                        } else {
                            Write-Host "[$i] $algoName - (Algorithm object is null)" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "[$i] $algoName - (Error: $($_.Exception.Message))" -ForegroundColor Red
                    }
                }
                
                $selection = Read-Host "Select algorithm index"
                if ($selection -match '^\d+$' -and [int]$selection -lt $algorithms.Count -and [int]$selection -ge 0) {
                    $selectedAlgo = $algorithms[[int]$selection]
                    $global:encryption_algorithm = $selectedAlgo
                    Write-Host "Encryption algorithm set to: $global:encryption_algorithm" -ForegroundColor Green
                } else {
                    Write-Host "Invalid selection. Please enter a number between 0 and $($algorithms.Count - 1)" -ForegroundColor Red
                }
            }

            "c" {
                $errors = Validate-AllInputs
                if (-not (Show-ValidationErrors $errors)) {
                    try {
                        Embed_PowerShellCodeInImagev2 -ImagePath $global:imagePath -PayloadBase64 $global:payload -OutputImagePath $global:output_imagepath
                        Write-Host "Embedding completed successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error during embedding: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "encrypt" {
                $errors = Validate-AllInputs -SkipPayload
                if (-not (Show-ValidationErrors $errors)) {
                    Write-Host "Enter PowerShell code sections for $global:encryption_algorithm encryption:" -ForegroundColor Cyan
                    $plainSection = Read-Host "Enter plain/visible PowerShell code"
                    $secretSection = Read-Host "Enter secret PowerShell code (will be encrypted)"
                    
                    try {
                        $algorithm = Get-EncryptionAlgorithm $global:encryption_algorithm
                        $result = $algorithm.EmbedEncrypted($global:imagePath, $plainSection, $secretSection, $global:output_imagepath)
                        Write-Host "$global:encryption_algorithm embedding completed successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error during $global:encryption_algorithm embedding: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "e" {
                $errors = Validate-InputImagePath -imagePath $global:imagePath
                if (-not (Show-ValidationErrors $errors)) {
                    try {
                        $extractedData = Extract_PowerShellCodeFromImagev2 -ImagePath $global:imagePath
                        Write-Host "Extracted data:" -ForegroundColor Green
                        Write-Host $extractedData
                    } catch {
                        Write-Host "Error during extraction: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "decrypt" {
                $errors = Validate-InputImagePath -imagePath $global:imagePath
                if (-not (Show-ValidationErrors $errors)) {
                    $keyFile = Read-Host "Enter path to private key file"
                    if (Test-Path $keyFile) {
                        try {
                            $algorithm = Get-EncryptionAlgorithm $global:encryption_algorithm
                            $privateKey = Get-Content $keyFile -Raw
                            $keys = @{ PrivateKey = $privateKey }
                            $result = $algorithm.ExtractAndDecrypt($global:imagePath, $keys)
                            
                            Write-Host "Plain Section:" -ForegroundColor Green
                            Write-Host $result.PlainSection
                            Write-Host "`nDecrypted Secret Section:" -ForegroundColor Green
                            Write-Host $result.DecryptedSection
                            Write-Host "`nComplete Reconstructed Code:" -ForegroundColor Cyan
                            Write-Host $result.CompleteCode
                            
                        } catch {
                            Write-Host "Error during $global:encryption_algorithm decryption: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "Private key file not found: $keyFile" -ForegroundColor Red
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


#Core functions
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




menu




