---
name: broken-meta
description: Bad fixture skill — metadata written as a nested YAML block instead of single-line JSON.
metadata:
  openclaw:
    emoji: 🦞
    requires:
      bins: [ffmpeg]
---

# broken-meta

This metadata block is valid YAML but OpenClaw requires single-line JSON — the validator must flag openclaw-skill-metadata-json.
