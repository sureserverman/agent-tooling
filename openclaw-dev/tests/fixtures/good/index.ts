// Good fixture: focused SDK subpath (NOT the deprecated root barrel).
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  register(api: any) {
    api.registerTool({
      name: "weather_lookup",
      description: "Look up current weather for a city.",
      parameters: { type: "object", properties: { city: { type: "string" } } },
      async execute(_id: string, params: { city: string }) {
        return { content: [{ type: "text", text: `Weather for ${params.city}` }] };
      },
    });
  },
});
