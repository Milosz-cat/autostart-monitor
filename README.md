# Autostart Monitor

A PowerShell script for monitoring and protecting Windows autostart entry points. It detects new entries in the registry, startup folders, and Task Scheduler, logs them, and can optionally remove unauthorized entries automatically.

## Features

- **Registry** – monitors `Run` and `RunOnce` keys under both `HKLM` and `HKCU`
- **Startup folders** – tracks the user's Startup folder and the common (All Users) one
- **Task Scheduler** – detects tasks with `AtStartup`, `AtLogOn`, or `Boot` triggers
- **Change detection** – compares the current state against the previous scan
- **Whitelist** – lets you mark trusted entries so they no longer trigger alerts
- **Logging** – writes events to a CSV file and to the Windows Event Log
- **Interactive or automatic mode** – on first run, a GUI asks whether new entries should be removed automatically or whether you'll be prompted each time

## Requirements

- Windows 10/11 or Windows Server
- PowerShell 5.1 or newer
- Administrator privileges (recommended, for full access to `HKLM` and Task Scheduler)

## Installation

1. Download `AutostartMonitor.ps1` from this repository.
2. Open PowerShell **as Administrator**.
3. If needed, allow local script execution:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Run the script:
   ```powershell
   .\AutostartMonitor.ps1
   ```

## First run

On first launch, a window will appear with the option:

> **Enable automatic removal of new registry entries**

- **Checked** – new registry entries will be removed automatically without prompting
- **Unchecked** – every new entry will trigger a Yes/No confirmation dialog

Your choice is saved to `settings.json` and won't be asked again on subsequent runs.

## Data files

All working data is stored under:

```
%ProgramData%\Autostart_Monitor\
├── settings.json          # saved configuration (auto-remove mode)
├── autostart_state.json   # last known state of all autostart entries
├── whitelist.json          # list of trusted entries (see below)
└── autostart_log.csv       # log of detected/new entries with timestamps
```

## Whitelist (whitelist.json)

To mark an entry as trusted and skip it in future scans, add it to `whitelist.json` in this format:

```json
[
  { "Name": "OneDrive", "Command": "\"C:\\Program Files\\Microsoft OneDrive\\OneDrive.exe\" /background" }
]
```

## Automation (optional)

To run the script on a schedule, you can add a Task Scheduler task, e.g. every hour:

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\Path\AutostartMonitor.ps1`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "AutostartMonitor" -Action $action -Trigger $trigger -RunLevel Highest
```

## Limitations

- Automatic removal is currently supported only for **Registry**-type entries. Startup folder and Task Scheduler entries are reported only, not removed.
- Reading some scheduled tasks may require administrator privileges — otherwise the script will print a warning and skip those entries.

## License

MIT — use, modify, and distribute freely.

## Disclaimer

This script modifies the Windows registry. Before using automatic removal mode, it's recommended to:
- back up the registry,
- test in interactive mode first (without auto-remove),
- add known, trusted startup programs to the whitelist.
