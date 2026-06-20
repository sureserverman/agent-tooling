// Bad fixture: imports the DEPRECATED root barrel — the validator must warn.
import { definePluginEntry } from "openclaw/plugin-sdk";

export default definePluginEntry({
  register() {},
});
