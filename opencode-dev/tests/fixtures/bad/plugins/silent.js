// A plugin module with no module-level exposure — OpenCode silently never loads it.
const Plugin = async () => {
  return {
    "session.idle": async () => {},
  }
}
