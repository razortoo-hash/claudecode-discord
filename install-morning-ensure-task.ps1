# Registers DiscordV3-MorningEnsure: 06:10 daily, wake-to-run, ensures the V3 bot
# is up after overnight sleep + Discord-pings LINE_B_CODING. Re-runnable (-Force).
$ErrorActionPreference = 'Stop'
$ps1 = 'C:\Users\Admin\codebase\93_discord-bot-bidirectional\source\claudecode-discord\discord-v3-morning-ensure.ps1'
$arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $ps1 + '"'

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
$trigger   = New-ScheduledTaskTrigger -Daily -At 06:10
$principal = New-ScheduledTaskPrincipal -UserId 'Admin' -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName 'DiscordV3-MorningEnsure' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

$t = Get-ScheduledTask -TaskName 'DiscordV3-MorningEnsure'
Write-Output ("Registered: {0} | State={1}" -f $t.TaskName, $t.State)
$t.Triggers | Format-List StartBoundary,DaysInterval
$t.Settings | Format-List WakeToRun,StartWhenAvailable
