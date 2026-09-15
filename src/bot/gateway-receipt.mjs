// In-process evidence only: no extra Discord requests, tokens or message data.
import { writeFileSync, renameSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

export function sampleGateway(client, now = Date.now()) {
  const shards = [...client.ws.shards.values()].map(shard => ({
    id: shard.id, status: shard.status, ping_ms: shard.ping,
    // discord.js sets lastPingTimestamp only on HeartbeatComplete (ACK).
    ack_at_ms: shard.lastPingTimestamp > 0 && shard.ping >= 0
      ? shard.lastPingTimestamp + shard.ping : null,
  }));
  const healthy = client.isReady() && shards.length > 0 && shards.every(shard =>
    shard.status === 0 && Number.isFinite(shard.ack_at_ms) &&
    Number.isFinite(shard.ping_ms) && shard.ping_ms >= 0 &&
    now - shard.ack_at_ms >= 0 && now - shard.ack_at_ms <= 90000);
  return { healthy: Boolean(healthy), ready: client.isReady(), shards };
}

export function attachGatewayReceipt(client, output, options = {}) {
  const now = options.now ?? Date.now;
  const write = options.write ?? ((receipt) => {
    const temporary = `${output}.${process.pid}.tmp`;
    writeFileSync(temporary, JSON.stringify(receipt), { encoding: 'utf8', mode: 0o600 });
    renameSync(temporary, output);
  });
  const boot = randomUUID();
  const started = now() - process.uptime() * 1000;
  const tick = () => {
    try {
      const observed = now();
      write({ schema: 1, pid: process.pid, boot_id: boot,
        process_started_at_ms: started, observed_at_ms: observed,
        ...sampleGateway(client, observed) });
    } catch {
      // A stale/missing receipt must fail the reader's freshness gate.
      // Never throw into the bot or disclose arbitrary error/config contents.
      (options.warn ?? console.warn)('V3 gateway receipt write failed');
    }
  };
  tick();
  const timer = (options.schedule ?? setInterval)(tick, 30000);
  timer.unref?.();
  return () => (options.cancel ?? clearInterval)(timer);
}
