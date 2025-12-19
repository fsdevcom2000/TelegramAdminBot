# Telegram Admin Bot for Windows

**PowerShell 5.1 compatible** Telegram bot for remote administration and monitoring of Windows machines.

It supports full-screen screenshots, system info, process management, disk info, ping tests, and more.

This script is for educational and cybersecurity lab use only.
Do NOT use on systems you do not own or have permission to test.

---

## Features

- Remote commands via Telegram:
    
    - `shutdown` — shut down PC immediately
        
    - `restart` — restart PC immediately
        
    - `lock` — lock workstation
        
    - `screenshot` — full-screen screenshot (multi-monitor, DPI aware, JPEG)
        
    - `sysinfo` — PC name, username, OS, CPU, RAM, IP addresses
        
    - `processes` — top 10 CPU processes
        
    - `kill <process>` — terminate a process by name
        
    - `disk` — free and total space for all drives
        
    - `sleep` — put PC to sleep
        
    - `hibernate` — put PC into hibernation
        
    - `ping <host>` — check network connectivity
        
    - `status` — bot uptime and OS uptime
        
    - `run <app> [args]` — run applications with parameters
        
- Logs all actions to `%LOCALAPPDATA%\WinTgService\service.log`
    
- Temporary screenshot storage in `%LOCALAPPDATA%\WinTgService\tmp`
    
- Fully compatible with PowerShell 5.1
    

---

## Requirements

- Windows 7 / 8 / 10 / 11
    
- PowerShell **5.1** (default on Windows 10/11)
    
- Internet connection for Telegram API
    
- TLS 1.2 enabled
    
- .NET Framework (required for `System.Drawing` and `System.Windows.Forms`)
    
- Telegram Bot token and chat ID
    

---

## Installation

1. Clone or download this repository.
    
2. Edit the script and replace:
    

`$Token  = "YOUR_BOT_TOKEN_HERE" $ChatId = "YOUR_CHAT_ID_HERE"`

3. Save the script as `TelegramAdminBot.ps1`.
    
4. Run the script in **PowerShell 5.1**:
    

`powershell.exe -ExecutionPolicy Bypass -File .\TelegramAdminBot.ps1`

---

## Notes

- **Execution Policy:** If your system blocks the script, run PowerShell as Administrator and set:
    

`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

- **Antivirus / Defender:** Some antivirus programs may block scripts that control the system or take screenshots. Add the script folder to **exclusions** or temporarily disable antivirus to allow execution.
    
- **Permissions:** Some commands (`shutdown`, `restart`, `kill`, `sleep`) may require administrative privileges.
    
- **Screenshots:** Saved as JPEG in `%LOCALAPPDATA%\WinTgService\tmp` and sent as Telegram documents.
    
- **Logs:** All actions and errors are logged in `%LOCALAPPDATA%\WinTgService\service.log`.
    

---

## Example Usage

1. Send `screenshot` → bot sends a full-screen screenshot.
    
2. Send `sysinfo` → bot replies with system information.
    
3. Send `kill notepad` → terminates all Notepad processes.
    
4. Send `run calc` → launches Calculator, or `run "C:\Program Files\VideoLAN\VLC\vlc.exe"` (Additional launch parameters can be used in quotation marks.)
    

---

## Troubleshooting

- **Bot does not send messages:**
    
    - Check network connection and bot token.
        
    - Verify chat ID.
        
    - Make sure TLS 1.2 is enabled.
        
- **Screenshot not sent:**
    
    - Ensure script has access to `%LOCALAPPDATA%`.
        
    - Antivirus may block screen capture or file upload.
        
- **Commands fail:**
    
    - Some commands require admin rights (`shutdown`, `restart`, `kill`, etc.).
        

---

# Telegram Admin Bot для Windows

**Совместимо с PowerShell 5.1**. Telegram-бот для удалённого администрирования и мониторинга Windows.

Поддерживает полноэкранные скриншоты, информацию о системе, управление процессами, дисками, проверку сети и запуск приложений.

⚠️ Этот проект предназначен исключительно для образовательных целей и использования в лабораториях кибербезопасности.
ЗАПРЕЩАЕТСЯ использовать его на системах, которые вам не принадлежат или для тестирования которых у вас нет разрешения.
---

## Возможности

- Удалённое управление через Telegram:
    
    - `shutdown` — немедленное выключение ПК
        
    - `restart` — перезагрузка ПК
        
    - `lock` — блокировка рабочего стола
        
    - `screenshot` — полноэкранный скриншот (мульти-монитор, DPI aware, JPEG)
        
    - `sysinfo` — имя ПК, пользователь, ОС, процессор, RAM, IP-адреса
        
    - `processes` — топ-10 процессов по загрузке CPU
        
    - `kill <process>` — завершение процесса по имени
        
    - `disk` — свободное и общее место на всех дисках
        
    - `sleep` — перевод ПК в спящий режим
        
    - `hibernate` — перевод ПК в гибернацию
        
    - `ping <host>` — проверка доступности хоста
        
    - `status` — время работы бота и uptime ОС
        
    - `run <app> [args]` — запуск приложений с параметрами
        
- Логирование всех действий в `%LOCALAPPDATA%\WinTgService\service.log`
    
- Временные скриншоты сохраняются в `%LOCALAPPDATA%\WinTgService\tmp`
    
- Полная совместимость с PowerShell 5.1
    

---

## Требования

- Windows 7 / 8 / 10 / 11
    
- PowerShell **5.1**
    
- Интернет для доступа к Telegram API
    
- TLS 1.2 включён (для подключения к Telegram API)
    
- .NET Framework (для `System.Drawing` и `System.Windows.Forms`)
    
- Telegram Bot Token и Chat ID
    

---

## Установка

1. Склонируйте или скачайте репозиторий.
    
2. Отредактируйте скрипт и замените:
    

`$Token  = "ВАШ_BOT_TOKEN" $ChatId = "ВАШ_CHAT_ID"`

3. Сохраните скрипт как `TelegramAdminBot.ps1`.
    
4. Запустите скрипт в PowerShell 5.1:
    

`powershell.exe -ExecutionPolicy Bypass -File .\TelegramAdminBot.ps1`

---

## Важные моменты

- **Политика выполнения:** Если система блокирует скрипт, запустите PowerShell от имени администратора и установите:
    

`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

- **Антивирус / Windows Defender:** Некоторые антивирусы могут блокировать скрипты, управляющие системой или делающие скриншоты. Добавьте папку скрипта в **исключения** или временно отключите защиту.
    
- **Права:** Некоторые команды (`shutdown`, `restart`, `kill`, `sleep`) могут требовать прав администратора.
    
- **Скриншоты:** Сохраняются как JPEG в `%LOCALAPPDATA%\WinTgService\tmp` и отправляются как документы Telegram.
    
- **Логи:** Все действия и ошибки фиксируются в `%LOCALAPPDATA%\WinTgService\service.log`.
    

---

## Примеры использования

1. Отправьте `screenshot` → бот присылает полноэкранный скриншот.
    
2. Отправьте `sysinfo` → бот отвечает с информацией о системе.
    
3. Отправьте `kill notepad` → завершает все процессы Notepad.
    
4. Отправьте `run calc` → запускает Калькулятор, или `run "C:\Program Files\VideoLAN\VLC\vlc.exe"` (можно использовать дополнительные параметры в кавычках)
    

---

## Устранение неполадок

- **Бот не отправляет сообщения:**
    
    - Проверьте интернет и правильность токена бота.
        
    - Проверьте правильность Chat ID.
        
    - Убедитесь, что TLS 1.2 включён.
        
- **Скриншот не отправляется:**
    
    - Скрипт должен иметь доступ к `%LOCALAPPDATA%`.
        
    - Антивирус может блокировать создание скриншотов или отправку файлов.
        
- **Команды не выполняются:**
    
    - Некоторые команды требуют прав администратора (`shutdown`, `restart`, `kill`).
