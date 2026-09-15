export function sampleGateway(client: unknown, now?: number): {
  healthy: boolean; ready: boolean; shards: unknown[];
};
export function attachGatewayReceipt(client: unknown, output: string): () => void;
