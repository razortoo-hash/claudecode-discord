# Gateway-health probe for Discord Bot V3 (Gary V3 Pilot).
#
# Why this exists (2026-06-22): the relaunch watchdog (discord-v3-watchdog.cmd)
# only restarts node when the PROCESS EXITS. discord.js can get stuck in an
# infinite "Shard 0 reconnecting..." loop WITHOUT exiting -> the bot is offline
# to Discord (receives no messages) but the watchdog thinks it's alive. That is
# a silent fail (Gary spoke in KC, no response; node had been "reconnecting" for
# hours). This probe detects that state from the bot log and kills node; the
# .cmd loop then relaunches it with a fresh gateway connection.
#
# Safety: this probe NEVER starts node itself. The proven .cmd loop is the only
# thing that (re)launches the bot, so a bug here cannot leave the bot dead --
# worst case it kills node and the .cmd relaunches it. Detection is delta-based
# (reconnect spam still GROWING), so a brief/normal reconnect is not killed.

$ErrorActionPreference = 'Continue'
$dir       = 'C:\Users\Admin\codebase\93_discord-bot-bidirectional\source\claudecode-discord'
$log       = Join-Path $dir 'bot-watchdog.log'
$healthLog = Join-Path $dir 'gateway-health.log'
$intervalSec    = 60
$stuckThreshold = 2     # consecutive 60s intervals of growing reconnect spam before kill
$growthMin      = 3     # +N "reconnecting" lines within an interval = still failing

function Write-HealthLog([string]$msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg" | Add-Content -Path $healthLog -Encoding UTF8
}

# Count both reconnect attempts AND successful recoveries. A flapping-but-working
# gateway (reconnecting -> "resumed"/"logged in" -> reconnecting) must NOT be
# killed; only a TRULY stuck one (reconnecting grows with ZERO recovery) is dead.
function Get-Counts {
    if (-not (Test-Path $log)) { return @{ reconnect = 0; recover = 0 } }
    try {
        $lines = Get-Content -Path $log -ErrorAction Stop
        $rc = @($lines | Select-String -Pattern 'reconnecting' -SimpleMatch).Count
        $ok = @($lines | Select-String -Pattern 'resumed','logged in','Registered','Bot is running' -SimpleMatch).Count
        return @{ reconnect = $rc; recover = $ok }
    } catch {
        return @{ reconnect = -1; recover = -1 }   # log locked/mid-rotate; skip tick
    }
}

Write-HealthLog "probe started (interval=${intervalSec}s threshold=${stuckThreshold} growthMin=${growthMin})"
$p     = Get-Counts
$prev  = $p.reconnect
$prevOk = $p.recover
$stuck = 0

while ($true) {
    Start-Sleep -Seconds $intervalSec
    $c = Get-Counts
    $cur = $c.reconnect; $curOk = $c.recover
    if ($cur -lt 0) { continue }                      # read failed this tick
    if ($cur -lt $prev) {                              # log rotated/shrank -> rebaseline
        Write-HealthLog "log rotated/shrank ($prev -> $cur); rebaselined"
        $stuck = 0; $prev = $cur; $prevOk = $curOk; continue
    }

    $reconnGrew = $cur -ge ($prev + $growthMin)
    $recovered  = $curOk -gt $prevOk
    if ($reconnGrew -and -not $recovered) {
        # reconnect spam growing AND zero successful resume/login this interval = stuck
        $stuck++
        Write-HealthLog "STUCK signal: reconnect $prev->$cur, recover $prevOk->$curOk (no recovery); stuck=$stuck/$stuckThreshold"
        if ($stuck -ge $stuckThreshold) {
            $node = @(Get-CimInstance Win32_Process -Filter "name='node.exe'" -ErrorAction SilentlyContinue |
                      Where-Object { $_.CommandLine -like '*dist*index.js*' })
            if ($node.Count -gt 0) {
                $ids = ($node.ProcessId -join ',')
                $node | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                Write-HealthLog "KILLED stuck node (PID $ids) -> .cmd loop will relaunch with fresh gateway"
            } else {
                Write-HealthLog "stuck detected but no node dist/index.js process found (cmd may be mid-relaunch)"
            }
            $stuck = 0
            Start-Sleep -Seconds 20                     # let .cmd relaunch + new node settle
            $b = Get-Counts; $prev = [Math]::Max(0,$b.reconnect); $prevOk = [Math]::Max(0,$b.recover)
            continue
        }
    } else {
        if ($stuck -gt 0) {
            $why = if ($recovered) { "recovered (resume/login seen)" } else { "reconnect spam stopped growing" }
            Write-HealthLog "healthy: $why (reconnect $prev->$cur, recover $prevOk->$curOk); reset"
        }
        $stuck = 0
    }
    $prev = $cur; $prevOk = $curOk
}
