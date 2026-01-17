# ===============================================================================

# Name: TelegramAdminBot (SAFE)
# Version: 2.0.0
# Description: PowerShell 5.1 compatible Telegram bot for Windows 
# Security-focused release with reduced attack surface
# Author: fsdevcom2000
# URL: https://github.com/fsdevcom2000/TelegramAdminBot

# ===============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

# ================= CONFIG ========================
$Token  = "YOUR-TELEGRAM-API-TOKEN"
$ChatId = "YOUR-TELEGRAM-CHAT-ID"

# ================= Allowed Path And Ext ==========
$AllowedDir = [Environment]::GetFolderPath("MyDocuments")
$AllowedExt = @(".ogg", ".mp4", ".mp3", ".avi", ".docx")

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

    } catch {

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

# ================= COMMAND DESCRIPTIONS =================
$CommandList = @(
    @{ Cmd = "sysinfo";                 Desc = "Show system information" },
    @{ Cmd = "disk";                    Desc = "Show disk usage" },
    @{ Cmd = "ping <host>";             Desc = "Ping a host and show if reachable" },
    @{ Cmd = "battery";                 Desc = "Get battery info (for laptops)" },
    @{ Cmd = "get <file>";              Desc = "Get File" },
    @{ Cmd = "open <file>";             Desc = "Open File With Associated Application" },
    @{ Cmd = "help";                    Desc = "Show this help message" }
)

# ================= COMMAND HANDLER =================
function Handle-Command($cmd) {

    switch -Regex ($cmd) {
        
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
        
        "^disk$" {
            $drives = Get-PSDrive -PSProvider 'FileSystem' | Select-Object Name, Used, Free, @{Name='Total';Expression={($_.Used + $_.Free)/1GB -as [int]}}
            $msg = ($drives | ForEach-Object { "$($_.Name): Free $([math]::Round($_.Free/1GB,1)) GB / Total $([math]::Round($_.Total,1)) GB" }) -join "`n"
            Tg-Send $msg
        }
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
        "^help$" {
            $msg = ($CommandList | ForEach-Object { "$($_.Cmd) : $($_.Desc)" }) -join "`n"
            Tg-Send $msg
        }
        "^get\s+(.+)$" {
            $filename = $matches[1]
            $file = Join-Path $AllowedDir $filename
            
            # Path traversal protection
            $full = [IO.Path]::GetFullPath($file)
            $base = [IO.Path]::GetFullPath($AllowedDir)

            if (-not $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
                Tg-Send "Not allowed"
                return
            }

            if (Test-Path $full -PathType Leaf) {
                Tg-Document $full
            }
            else {
                Tg-Send "File not found"
            }
        }
        "^open\s+(.+)$" {
            $name = $matches[1]
            $file = Join-Path $AllowedDir "$name"
            

            if (
                (Test-Path $file -PathType Leaf) -and
                ($AllowedExt -contains ([IO.Path]::GetExtension($file)))
            ) {
                Start-Process $file
                Tg-Send "Opened file: ${name}"
            }
            else {
                Tg-Send "Not allowed (see AllowedExt)"
            }
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
    }
    catch {
        # Handling of other errors
    }

    # Pause between requests
    Start-Sleep -Seconds $pollingDelaySeconds
}

