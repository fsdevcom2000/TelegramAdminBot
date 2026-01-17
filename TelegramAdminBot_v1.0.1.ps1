# ===============================================================================

# Name: TelegramAdminBot
# Version: 1.0.1
# Description: PowerShell 5.1 compatible Telegram bot for remote administration 
# and monitoring of Windows machines. It supports full-screen screenshots,
# system info, process management, disk info, ping tests, and more.
# Author: fsdevcom2000
# URL: https://github.com/fsdevcom2000/TelegramAdminBot

# ===============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

# ================= CONFIG =================
$Token  = "YOUR-TELEGRAM-API-TOKEN"
$ChatId = "YOUR-TELEGRAM-CHAT-ID"

$BaseDir = "$env:LOCALAPPDATA\TelegramAdminBot"
$LogFile = "$BaseDir\service.log"
$TmpDir  = "$BaseDir\tmp"

New-Item $BaseDir -ItemType Directory -Force | Out-Null
New-Item $TmpDir  -ItemType Directory -Force | Out-Null


# ================= LOG =================
function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') :: $msg"
    Add-Content -Path $LogFile -Value $line
}

# ================= TELEGRAM TEXT =================
function Tg-Send($text) {
    try {
        Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$Token/sendMessage" `
            -Method Post `
            -Body @{
                chat_id = $ChatId
                text    = $text
            } | Out-Null
        Write-Log "Sent message: $text"
    } catch {
        Write-Log ("Send message error: " + $_.Exception.Message)
    }
}

# ================= TELEGRAM DOCUMENT =================
function Tg-Document {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string]$Caption = $null
    )

    try {
        if (-not (Test-Path $FilePath -PathType Leaf)) {
            throw "File not found: $FilePath"
        }

        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $mimeType = "application/octet-stream"  # Common MIME

        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

        $bodyLines = @(
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$ChatId$LF"
        )

        if ($Caption) {
            $bodyLines +=
                "--$boundary$LF" +
                "Content-Disposition: form-data; name=`"caption`"$LF$LF$Caption$LF"
        }

        $bodyLines +=
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"document`"; filename=`"$fileName`"$LF" +
            "Content-Type: $mimeType$LF$LF"

        $bodyFooter = "$LF--$boundary--$LF"

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(($bodyLines -join ""))
        $fileBytes   = [System.IO.File]::ReadAllBytes($FilePath)
        $footerBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyFooter)

        $body = New-Object byte[] ($headerBytes.Length + $fileBytes.Length + $footerBytes.Length)
        [Array]::Copy($headerBytes, 0, $body, 0, $headerBytes.Length)
        [Array]::Copy($fileBytes, 0, $body, $headerBytes.Length, $fileBytes.Length)
        [Array]::Copy($footerBytes, 0, $body, $headerBytes.Length + $fileBytes.Length, $footerBytes.Length)

        Invoke-WebRequest `
            -Uri "https://api.telegram.org/bot$Token/sendDocument" `
            -Method Post `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -Body $body `
            -UseBasicParsing | Out-Null

        Write-Log "Document sent: $FilePath"
    }
    catch {
        Write-Log "Telegram document send error: $($_.Exception.Message)"
        Tg-Send "Failed to send file: $fileName"
    }
}

# ================= SCREENSHOT (FULLSCREEN, MULTI-MONITOR, JPEG) =================
function Take-Screenshot {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $virtualBounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $bmp = New-Object System.Drawing.Bitmap $virtualBounds.Width, $virtualBounds.Height
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)

        $gfx.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::High
        $gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $gfx.CopyFromScreen(
            $virtualBounds.X,
            $virtualBounds.Y,
            0,
            0,
            $virtualBounds.Size,
            [System.Drawing.CopyPixelOperation]::SourceCopy
        )

        $file = "$TmpDir\screenshot.jpg"

        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
            Where-Object { $_.MimeType -eq "image/jpeg" }
        $encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
        $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter `
            ([System.Drawing.Imaging.Encoder]::Quality, 80)
        $bmp.Save($file, $jpegCodec, $encParams)

        $gfx.Dispose()
        $bmp.Dispose()

        Write-Log ("Screenshot saved: " + (Get-Item $file).Length + " bytes")
        Write-Log ("Resolution: {0}x{1}" -f $virtualBounds.Width, $virtualBounds.Height)

        Tg-Document $file
    } catch {
        Write-Log ("Screenshot error: " + $_.Exception.Message)
        Tg-Send "Screenshot error"
    }
}
# ================= WEBCAM ==========================
function Get-Ffmpeg {
    param (
        [string]$FfmpegDir = "$env:ProgramData\ffmpeg"
    )

    # 1. IF ffmpeg available, using
    $existing = Get-ChildItem -Path $FfmpegDir -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($existing) {
        return $existing.FullName
    }

    Write-Log "ffmpeg not found, downloading..."

    New-Item -ItemType Directory -Path $FfmpegDir -Force | Out-Null

    $zipPath = Join-Path $FfmpegDir "ffmpeg.zip"
    $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

    Expand-Archive -Path $zipPath -DestinationPath $FfmpegDir -Force

    Remove-Item $zipPath -Force

    # 2. After unpacking search again
    $existing = Get-ChildItem -Path $FfmpegDir -Recurse -Filter ffmpeg.exe |
        Select-Object -First 1

    if (-not $existing) {
        throw "ffmpeg.exe not found after download"
    }

    return $existing.FullName
}


function Get-WebcamList {
    param (
        [string]$FfmpegPath
    )

    $output = & $FfmpegPath -list_devices true -f dshow -i dummy 2>&1

    $devices = @()

    foreach ($line in $output) {
        if ($line -match '"(.+)"') {
            $devices += $Matches[1]
        }
    }

    return $devices | Select-Object -Unique
}

function Get-WebcamSnapshotFFmpeg {
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }

    $ffmpeg = Get-Ffmpeg
    $cameras = Get-WebcamList -FfmpegPath $ffmpeg

    if (-not $cameras -or $cameras.Count -eq 0) {
        throw "No webcams detected by ffmpeg"
    }

    $cameraName = $cameras[0]

    $fileName = "webcam_{0}.jpg" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    $filePath = Join-Path $OutputDirectory $fileName

    & $ffmpeg `
        -y `
        -f dshow `
        -i "video=$cameraName" `
        -frames:v 1 `
        $filePath `
        2>$null

    if (-not (Test-Path $filePath)) {
        throw "Snapshot failed"
    }

    return $filePath
}

function Invoke-WebcamSnapshot {
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    try {
        $photoPath = Get-WebcamSnapshotFFmpeg -OutputDirectory $OutputDirectory

        return [PSCustomObject]@{
            Success = $true
            Path    = $photoPath
            Error   = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Path    = $null
            Error   = $_.Exception.Message
        }
    }
}

# ================= OPEN URL ========================
function Open-Url {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Using default browser
        Start-Process -FilePath $Url
        Write-Log "Open browser with URL: $($Url)"
    }
    catch {
        Write-Log "Cannot open URL: $($_.Exception.Message)"
    }
}

# ================= SHUTDOWN ADAPTERS ====================
function Disable-NetworkAdaptersTemporarilyAsync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Minutes = 5  # Default 5 minutes
    )

    # Get all active network adapters (hardware)
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true }

    if ($adapters.Count -eq 0) {
        Write-Log "There are no active network adapters to disable."
        return
    }

    Write-Host "Disable network adapters..."
    foreach ($adapter in $adapters) {
        try {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false
            Write-Log "Disabled: $($adapter.Name)"
        }
        catch {
            Write-Log "Failed to disable $($adapter.Name): $_"
        }
    }

    # Run a background task to re-enable adapters
    Start-Job -ScriptBlock {
        param($adapterNames, $delayMinutes)

        Start-Sleep -Seconds ($delayMinutes * 60)

        foreach ($name in $adapterNames) {
            try {
                Enable-NetAdapter -Name $name -Confirm:$false
                Write-Log "Enabled: $name"
            }
            catch {
                Write-Log "Failed to enable ${name}: $_"
            }
        }
        Write-Log "All adapters have been enabled.."
    } -ArgumentList ($adapters.Name, $Minutes)

    Write-Log "Network adapters are disabled. They will be enabled in ${Minutes} min."
}

# ================= COMMAND DESCRIPTIONS =================
$CommandList = @(
    @{ Cmd = "shutdown";                Desc = "Shut down the PC immediately" },
    @{ Cmd = "restart";                 Desc = "Restart the PC immediately" },
    @{ Cmd = "lock";                    Desc = "Lock the workstation" },
    @{ Cmd = "screenshot";              Desc = "Take a screenshot" },
    @{ Cmd = "webcam";                  Desc = "Take a webcam snapshot" },
    @{ Cmd = "sysinfo";                 Desc = "Show system information" },
    @{ Cmd = "processes";               Desc = "Show top 10 CPU processes" },
    @{ Cmd = "url <link>";              Desc = "Open URL in default browser" },
    @{ Cmd = "kill <proc>";             Desc = "Terminate a process by name" },
    @{ Cmd = "disk";                    Desc = "Show disk usage" },
    @{ Cmd = "sleep";                   Desc = "Put the PC to sleep" },
    @{ Cmd = "hibernate";               Desc = "Hibernate the PC" },
    @{ Cmd = "ping <host>";             Desc = "Ping a host and show if reachable" },
    @{ Cmd = "status";                  Desc = "Show bot uptime" },
    @{ Cmd = "run <cmd>";               Desc = "Run a command in cmd.exe" },
    @{ Cmd = "openfolder <path>";       Desc = "Open folder in Explorer" },
    @{ Cmd = "openfile <filepath>";     Desc = "open file with assosiated app" },
    @{ Cmd = "battery";                 Desc = "Get battery info (for laptops)" },
    @{ Cmd = "services";                Desc = "Get first 20 services status" },
    @{ Cmd = "cleantemp";               Desc = "Clean C:\Users\%User%\AppData\Local\Temp folder" },
    @{ Cmd = "dir <path>";              Desc = "Show files and folders" },
    @{ Cmd = "get <filepath>";          Desc = "Get file" },
    @{ Cmd = "disconnect <min>";        Desc = "Disable ctive network adapters for <min>" },
    @{ Cmd = "help";                    Desc = "Show this help message" }
)

# ================= COMMAND HANDLER =================
function Handle-Command($cmd) {
    Write-Log "Received: $cmd"

    switch -Regex ($cmd) {
        "^shutdown$"   { shutdown /s /t 0 }
        "^restart$"    { shutdown /r /t 0 }
        "^lock$"       { rundll32 user32.dll,LockWorkStation }
        "^screenshot$" { Take-Screenshot }
        "^webcam$" {
            $result = Invoke-WebcamSnapshot -OutputDirectory $TmpDir

            if ($result.Success) {
                Write-Log "Saved to: $($result.Path)"
                Tg-Document $result.Path
                
            }
            else {
                Write-Log "Failed to take photo: $($result.Error)"
            }
        }
        "^disconnect\s+(.+)$" {
            $Minutes = $matches[1]
            Disable-NetworkAdaptersTemporarilyAsync -Minutes $Minutes
        }
        "^sysinfo$" {
            $comp = $env:COMPUTERNAME
            $user = $env:USERNAME
            $os   = (Get-CimInstance Win32_OperatingSystem).Caption
            $cpu  = (Get-CimInstance Win32_Processor).Name
            $ram  = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            $ip   = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -eq 'Dhcp' }).IPAddress
            $msg  = "PC: $comp`nUser: $user`nOS: $os`nCPU: $cpu`nRAM: ${ram}GB`nIP: $($ip -join ', ')"
            Tg-Send $msg
        }
        "^battery$" {
            $bat = Get-CimInstance Win32_Battery

            if ($bat) {
                $statusText = switch ($bat.BatteryStatus) {
                    1 { "Unplugged" }
                    2 { "Charging"}
                    3 { "Fully Charged" }
                    default { "Unknown" }
                }
                Tg-Send "Battery status: $statusText, Charge: $($bat.EstimatedChargeRemaining)%"
            } else {
                Tg-Send "No battery detected (desktop or AC only)"
            }
        }
        "^openfolder\s+(.+)$" {
            $path = $matches[1]
            if (Test-Path $path) {
                Start-Process explorer.exe $path
                Tg-Send "Opened folder: $path"
            } else {
                Tg-Send "Path not found: $path"
            }
        }
        "^openfile\s+(.+)$" {
            $filePath = $matches[1]

            if (Test-Path $filePath -PathType Leaf) {
                try {
                    Start-Process -FilePath $filePath
                    Tg-Send "Opened file: $filePath"
                } catch {
                    Tg-Send "Failed to open file: $($_.Exception.Message)"
                }
            } else {
                Tg-Send "File not found: $filePath"
            }
        }
        "^dir\s+(.+?)(?:\s+(\d+))?$" {
            $path  = $matches[1]
            $limit = if ($matches[2]) { [int]$matches[2] } else { 20 }

            if (-not (Test-Path $path)) {
                Tg-Send "Path not found: $path"
                return
            }

            try {
                $items = Get-ChildItem -Path $path -Force |
                         Sort-Object @{ Expression = 'PSIsContainer'; Descending = $true }, Name
                         Select-Object -First $limit

                if (-not $items) {
                    Tg-Send "Folder is empty: $path"
                    return
                }

                $msg = "Contents of $path (showing $($items.Count)):`n"
                $msg += ($items | ForEach-Object {
                    if ($_.PSIsContainer) {
                        "📁 $($_.Name)"
                    } else {
                        "📄 $($_.Name) ($([math]::Round($_.Length / 1KB,1)) KB)"
                    }
                }) -join "`n"

                Tg-Send $msg
            }
            catch {
                Tg-Send "Failed to list folder: $($_.Exception.Message)"
            }
        }
        "^get\s+(.+)$" {
            $GetFilePath = $matches[1]

            if (-not (Test-Path $GetFilePath -PathType Leaf)) {
                Tg-Send "File not found: $GetFilePath"
                return
            }

            try {
                $fileInfo = Get-Item $GetFilePath
                $fileSize = $fileInfo.Length
                $maxSize  = 50MB

                if ($fileSize -gt $maxSize) {
                    $sizeMB = [math]::Round($fileSize / 1MB, 2)
                    Tg-Send "File is too large: ${sizeMB} MB (Telegram limit is 50 MB)"
                    return
                }

                Tg-Document $GetFilePath
                Write-Log "File sent: $GetFilePath"
            }
            catch {
                Tg-Send "Failed to send file: $($_.Exception.Message)"
                Write-Log "Send file error: $_"
            }
        }
        "^processes$" {
            $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name,CPU
            $msg = ($procs | ForEach-Object { "$($_.Name) : $([math]::Round($_.CPU,2))s" }) -join "`n"
            Tg-Send $msg
        }
        "^services$" {
            $svc = Get-Service | Sort Status, Name | Select-Object -First 20 Name, Status
            $msg = ($svc | ForEach-Object { "$($_.Name) : $($_.Status)" }) -join "`n"
            Tg-Send $msg
        }
        "^url\s+(\S+)$" {
            $Url = $matches[1]
            Open-Url -Url $Url
            Tg-Send "Browser started with URL ${Url}"
        }
        "^kill\s+(\w+)$" {
            ${processName} = $matches[1]
            try {
                Stop-Process -Name $processName -Force
                Tg-Send "Process $processName terminated."
                Write-Log "Killed process: ${processName}"
            } catch {
                Tg-Send "Failed to terminate ${processName}: $_"
                Write-Log "Failed to kill process ${processName}: $_"
            }
        }
        "^disk$" {
            $drives = Get-PSDrive -PSProvider 'FileSystem' | Select-Object Name, Used, Free, @{Name='Total';Expression={($_.Used + $_.Free)/1GB -as [int]}}
            $msg = ($drives | ForEach-Object { "$($_.Name): Free $([math]::Round($_.Free/1GB,1)) GB / Total $([math]::Round($_.Total,1)) GB" }) -join "`n"
            Tg-Send $msg
        }
        "^sleep$" { rundll32.exe powrprof.dll,SetSuspendState 0,1,0 }
        "^hibernate$" { rundll32.exe powrprof.dll,SetSuspendState Hibernate }
        "^ping\s+(\S+)$" {
            $pingHost = $matches[1]
            try {
                $reachable = Test-Connection -ComputerName $pingHost -Count 2 -Quiet
                $status = if ($reachable) { "reachable" } else { "unreachable" }
                Tg-Send "Host ${pingHost} is ${status}"
            } catch {
                Tg-Send "Ping failed for ${pingHost}: $($_.Exception.Message)"
            }
        }
        "^status$" {
            $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            $days = $uptime.Days
            $hours = $uptime.Hours
            $minutes = $uptime.Minutes
            $seconds = $uptime.Seconds
            $msg = "Bot running. Uptime: ${days}d ${hours}h ${minutes}m ${seconds}s"
            Tg-Send $msg
        }
        "^run\s+(.+)$" {
            $appCmd = $matches[1]
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c $appCmd"
                Tg-Send "Executed: $appCmd"
            } catch {
                Tg-Send "Failed to execute ${appCmd}: $_"
            }
        }
        "^help$" {
            $msg = ($CommandList | ForEach-Object { "$($_.Cmd) : $($_.Desc)" }) -join "`n"
            Tg-Send $msg
        }
        "^cleantemp$" {
            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
            Tg-Send "Temporary files removed"
        }
        default { Tg-Send "Unknown command" }
    }
}

# ================= POLLING =================
$offset = 0
$timeoutSeconds = 20
$pollingDelaySeconds = 3

Tg-Send "Bot started"

# Main survey cycle
while ($true) {
    try {
        # Forming the request parameters
        $requestParams = @{
            Uri     = "https://api.telegram.org/bot$Token/getUpdates"
            Method  = 'Get'
            TimeoutSec = $timeoutSeconds
            Body    = @{
                offset  = $offset
                timeout = $timeoutSeconds
            }
        }

        # Request with HTTP error handling
        $resp = Invoke-RestMethod @requestParams -ErrorAction Stop

        # Check updates
        if ($resp.result -and $resp.result.Count -gt 0) {
            foreach ($update in $resp.result) {
                # Update offset for next request
                $offset = $update.update_id + 1
                
                # Processing the message.
                if ($update.message -and $update.message.text) {
                    Write-Log "Received message: $($update.message.text)"
                    
                    # Command processing (consider asynchronous call)
                    Handle-Command $update.message.text
                }
                # Add handling for other message types.
                elseif ($update.callback_query) {
                    # Handle-Callback $update.callback_query
                }
            }
        }
    }
    catch [System.Net.WebException] {
        # Handling network errors
        Write-Log "Network error: $($_.Exception.Message)"
        Write-Log "Will retry in $pollingDelaySeconds seconds..."
    }
    catch {
        # Handling of other errors
        Write-Log "Unexpected error: $($_.Exception.Message)"
        Write-Log "Stack trace: $($_.Exception.StackTrace)"
    }

    # Pause between requests
    Start-Sleep -Seconds $pollingDelaySeconds
}
