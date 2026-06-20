// Good fixture hook handler: default-export async handler.
export default async function handler(event: {
  type: string;
  action: string;
  sessionKey: string;
  timestamp: string;
  messages: unknown[];
  context: Record<string, unknown>;
}) {
  console.log(`[session-logger] ${event.type}:${event.action} @ ${event.timestamp}`);
}
