# GH52 V3 gateway receipt deployed and healthy

2026-09-16 Asia/Singapore. Deployed the reviewed receipt-writer bundle and
verified actual gateway heartbeat evidence after one exact-process restart.

Before restart, all four stored Discord sessions were idle and the verified V3
Node had zero child processes. Rebuilt into an isolated candidate directory;
reviewed the complete bundle diff: receipt writer/hook plus bundler variable
renaming only. Existing atomic single-instance guard was already in the deployed
bundle and remains unchanged. Pre-existing package.json/src/index.ts edits were
not committed or overwritten.

Old bundle SHA256:05863007cc568cb57897a8a950fbe2e95fe67f3acf26cd6ac5579caee5602210.
New bundle SHA256:35bcdbf9037b344957273e168e46462b0fb20073ab29722dba74227a9bb5b728.
Backup and deployment receipt:
tmp_worktrees/gh52-v3-receipt-deploy-20260916T073653/{index.js.before,receipt.json}.
Deployment helper retained at tmp_worktrees/gh52-deploy-v3-receipt.py; it pins
both hashes, rechecks idle/identity, bounds health acceptance to120seconds and
restores previous bytes on failure. It is a one-off deployment, not a scheduler.

One pinned Windows handle terminated oldNode28808. Existing launcher29144
restarted Node24984. Both creation-time/lock/entrypoint chains were checked.
New receipt boot d4edb386-9d1f-4dec-9322-a672a5d8d99a reached healthy with one
ready shard and an acknowledged heartbeat (latency281ms). The strict reader
accepted the receipt at07:37:59; process-start estimate matched live creation.
The initial not-yet-ready samples did not cause repeated restarts. No rollback
was needed and no test message was sent.

Verification: successful candidate build, complete targeted bundle diff review,
earlier39Python and3Node tests, live idle checks, exact termination/relaunch
receipt and live strict gateway health readback. No end-to-end user command was
sent, so this proves gateway connectivity, not a provider response or delivery.

Remaining: both legacy recovery owners still run; MorningEnsure remains WTS.
This deployment does NOT remove their broad-kill risk or migrate V3 to SYSTEM.
Integrate serialized recovery budget and DB ownership, fence both legacy repair
paths, then prove service-profile/no-login operation and update the full #52
acceptance. Do not close #52 from this deployment alone.
