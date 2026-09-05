# Paths for files
$basePath     = "$env:ProgramData\Autostart_Monitor"
$stateFile    = Join-Path $basePath "autostart_state.json"
$whiteFile    = Join-Path $basePath "whitelist.json"
$logFile      = Join-Path $basePath "autostart_log.csv"
$settingsFile = Join-Path $basePath "settings.json"

New-Item -ItemType Directory -Force -Path $basePath | Out-Null

# Load saved settings or show GUI if not present
if (Test-Path $settingsFile) {
    $autoRemove = (Get-Content $settingsFile | ConvertFrom-Json).AutoRemove
} else {
    Add-Type -AssemblyName System.Windows.Forms
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Autostart Monitor Settings"
    $form.Size = New-Object System.Drawing.Size(350,150)
    $form.StartPosition = "CenterScreen"

    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = "Enable automatic removal of new registry entries"
    $checkbox.AutoSize = $true
    $checkbox.Location = New-Object System.Drawing.Point(20,20)
    $form.Controls.Add($checkbox)

    $button = New-Object System.Windows.Forms.Button
    $button.Text = "Start Monitoring"
    $button.Location = New-Object System.Drawing.Point(20,60)
    $button.Add_Click({ $form.Close() })
    $form.Controls.Add($button)

    $form.ShowDialog() | Out-Null
    $autoRemove = $checkbox.Checked

    # Save choice to JSON
    @{ AutoRemove = $autoRemove } | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
}

# Function: Get registry autostart entries
function Get-RegistryAutostart {
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    $entries = @()
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Get-ItemProperty -Path $path | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                    $entries += [PSCustomObject]@{
                        Source  = $path
                        Name    = $_.Name
                        Command = $_.Value
                        Type    = "Registry"
                    }
                }
            }
        }
    }
    return $entries
}

# Function: Get startup folder entries
function Get-StartupFolder {
    $folders = @(
        [Environment]::GetFolderPath('Startup'),
        [Environment]::GetFolderPath('CommonStartup')
    )
    $entries = @()
    foreach ($folder in $folders) {
        if ($folder -and (Test-Path $folder)) {
            Get-ChildItem -Path $folder -File -ErrorAction SilentlyContinue | ForEach-Object {
                $entries += [PSCustomObject]@{
                    Source  = $folder
                    Name    = $_.Name
                    Command = $_.FullName
                    Type    = "Startup Folder"
                }
            }
        }
    }
    return $entries
}



# Function: Get scheduled tasks with autostart triggers
function Get-ScheduledTasksAutostart {
    $entries = @()
    try {
        $tasks = Get-ScheduledTask | Where-Object { $_.Triggers -ne $null }
        foreach ($task in $tasks) {
            foreach ($trigger in $task.Triggers) {
                if ($trigger.TriggerType -in @("AtStartup","AtLogOn","Boot")) {
                    foreach ($action in $task.Actions) {
                        $cmd = if ($action.Arguments) {
                            "$($action.Execute) $($action.Arguments)"
                        } else {
                            $action.Execute
                        }

                        $entries += [PSCustomObject]@{
                            Source   = "Task Scheduler"
                            Name     = $task.TaskName
                            Path     = $task.TaskPath
                            Command  = $cmd
                            Type     = "Scheduled Task"
                            User     = $task.Principal.UserId
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "No permission to read some scheduled tasks: $_"
    }
    return $entries
}



# Load whitelist
$whitelist = @()
if (Test-Path $whiteFile) {
    $whitelist = Get-Content $whiteFile | ConvertFrom-Json
}

# Collect all entries
$registryEntries = Get-RegistryAutostart
$folderEntries   = Get-StartupFolder
$taskEntries     = Get-ScheduledTasksAutostart
$allEntries      = $registryEntries + $folderEntries + $taskEntries

# Compare with previous state
if (Test-Path $stateFile) {
    $previous = Get-Content $stateFile | ConvertFrom-Json
    $newEntries = Compare-Object -ReferenceObject $previous -DifferenceObject $allEntries `
        -Property Name,Command,Type,Source -PassThru | Where-Object { $_.SideIndicator -eq "=>" }

    if ($newEntries) {
        foreach ($entry in $newEntries) {
            # Check whitelist
            $isWhitelisted = $false
            if ($whitelist) {
                $isWhitelisted = $whitelist | Where-Object {
                    $_.Name -eq $entry.Name -and $_.Command -eq $entry.Command
                }
            }

            if (-not $isWhitelisted) {
                # Ensure EventLog source exists
                if (-not [System.Diagnostics.EventLog]::SourceExists("AutostartMonitor")) {
                    New-EventLog -LogName Application -Source "AutostartMonitor"
                }

                # Add timestamp and log to CSV
                $entryWithTime = $entry | Select-Object Name,Command,Source,Type
                $entryWithTime | Add-Member -NotePropertyName Timestamp -NotePropertyValue (Get-Date) -Force
                $entryWithTime | Export-Csv -Path $logFile -Append -NoTypeInformation -Encoding UTF8

                # Log to Event Log
                Write-EventLog -LogName Application -Source "AutostartMonitor" -EventId 1001 -EntryType Warning `
                    -Message "New autostart entry detected: $($entry.Name) [$($entry.Command)]"

                # Auto-remove mode
                if ($autoRemove -and $entry.Type -eq "Registry") {
                    try {
                        Remove-ItemProperty -Path $entry.Source -Name $entry.Name -ErrorAction Stop
                        [System.Windows.Forms.MessageBox]::Show("Entry $($entry.Name) was automatically removed.", "Autostart Monitor")
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to remove entry $($entry.Name).", "Autostart Monitor")
                    }
                } else {
                    # Interactive prompt
                    $msg = "New autostart entry detected:`n`nName: $($entry.Name)`nPath: $($entry.Command)`nSource: $($entry.Source)`n`nDo you want to remove it?"
                    $result = [System.Windows.Forms.MessageBox]::Show($msg, "Autostart Monitor", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

                    if ($result -eq [System.Windows.Forms.DialogResult]::Yes -and $entry.Type -eq "Registry") {
                        try {
                            Remove-ItemProperty -Path $entry.Source -Name $entry.Name -ErrorAction Stop
                            [System.Windows.Forms.MessageBox]::Show("Entry $($entry.Name) has been removed.", "Autostart Monitor")
                        } catch {
                            [System.Windows.Forms.MessageBox]::Show("Failed to remove entry $($entry.Name).", "Autostart Monitor")
                        }
                    }
                }
            }
        }
    } else {
        Write-Host "No new entries detected."
    }
} else {
    Write-Host "No previous state found - creating a new state file."
}

# Save current state
$allEntries | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding UTF8