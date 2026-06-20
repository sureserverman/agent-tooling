// Minimal valid OpenCode plugin: toast when the session goes idle.
export const Notify = async ({ client }) => {
  return {
    "session.idle": async () => {
      await client.tui.showToast({ body: { message: "session idle", variant: "info" } })
    },
  }
}
