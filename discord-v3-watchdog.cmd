@echo off
REM Discord Bot V3 (Gary V3 Pilot) self-healing watchdog loop.
REM Launched hidden on logon by discord-v3-watchdog.vbs in the Startup folder.
REM Auto-logon keeps Admin logged in -> this runs in the interactive session
REM so the spawned `claude` subprocess can see Gary's Pro/Max OAuth creds.
REM No elevation / no password needed. Restarts node within 5s on any exit.
title DiscordBotV3-Watchdog
cd /d "C:\Users\Admin\codebase\93_discord-bot-bidirectional\source\claudecode-discord"
:loop
REM Rotate (not truncate) so post-mortem evidence survives a restart. 2026-06-22:
REM the old `> bot-watchdog.log` wiped the "Shard 0 reconnecting" gateway-death
REM logs on restart, so the root cause was unrecoverable. Keep last log as .1.
for %%A in (bot-watchdog.log) do if %%~zA GTR 5000000 move /y bot-watchdog.log bot-watchdog.log.1 >nul 2>&1
echo [%date% %time%] starting node dist\index.js >> bot-watchdog.log
node dist\index.js >> bot-watchdog.log 2>&1
echo [%date% %time%] node exited (code %errorlevel%), restarting in 5s >> bot-watchdog.log
timeout /t 5 /nobreak >nul
goto loop
