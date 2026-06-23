# Morning ensure for Discord Bot V3 (Gary V3 Pilot).
#
# Chosen approach "B" (2026-06-23, until end-of-month departure): keep the host's
# night sleep (00:00 NightSleepEnable) and rely on per-service recovery. The
# overnight sleep kills the bot's Discord gateway; the gateway-health probe
# auto-recovers intra-day, but to GUARANTEE the bot is up each morning + let Gary
# SEE it, this runs at 06:10 (after 06:00 DaySleepDisable), wake-to-run:
#   - healthy    -> report OK
#   - down/stuck -> kill node (the .cmd loop relaunches a fresh gateway), reverify
#   - then Discord-ping LINE_B_CODING so Gary knows the morning status.
# ASCII-only source (PS 5.1 cp1252 trap); Discord text kept ASCII too.

$ErrorActionPreference = 'Continue'
$dir         = 'C:\Users\Admin\codebase\93_discord-bot-bidirectional\source\claudecode-discord'
$log         = Join-Path $dir 'bot-watchdog.log'
$ensureLog   = Join-Path $dir 'morning-ensure.log'
$python      = 'C:\Python313\python.exe'
$sendDiscord = 'C:\Users\Admin\claude_code\scripts\send_discord.py'

function Note([string]$m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $m" | Add-Content -Path $ensureLog -Encoding UTF8 }

function Get-Node {
    @(Get-CimInstance Win32_Process -Filter "name='node.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -like '*dist*index.js*' })
}

function Test-Healthy {
    $node = Get-Node
    if ($node.Count -eq 0) { return $false }
    if (-not (Test-Path $log)) { return $true }
    $tail    = Get-Content $log -Tail 20 -ErrorAction SilentlyContinue
    $reconn  = @($tail | Select-String 'reconnecting' -SimpleMatch).Count
    $recover = @($tail | Select-String 'resumed','logged in','Registered','Bot is running' -SimpleMatch).Count
    return ($reconn -lt 8) -or ($recover -gt 0)
}

function Send-Ping([string]$msg) {
    try { & $python $sendDiscord --mode event --channel LINE_B_CODING --username coding_lead --message "[coding_lead] V3 bot morning check: $msg" | Out-Null }
    catch { Note "discord ping failed: $_" }
}

Note "=== morning ensure start ==="

if (Test-Healthy) {
    Note "healthy (already up)"
    Send-Ping "online and healthy (OK)"
    exit 0
}

Note "UNHEALTHY -> killing node for fresh relaunch"
Get-Node | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 18

if (Test-Healthy) {
    Note "restarted OK"
    Send-Ping "was down overnight, RESTARTED and logged in (OK)"
    exit 0
} else {
    Note "RESTART FAILED - node not healthy after relaunch"
    Send-Ping "RESTART FAILED - needs manual attention"
    exit 1
}
