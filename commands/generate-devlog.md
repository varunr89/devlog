---
description: "Generate a dev log blog post from today's insights and journal entries"
argument-hint: "[YYYY-MM-DD]"
allowed-tools:
  - Bash
  - Read
---

Generate a daily dev log blog post. Run the generation script from the devlog plugin:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-devlog.sh $ARGUMENTS
```

If no date argument is provided, the script uses yesterday's date (designed for midnight runs). Pass a specific date like `2026-02-11` to generate for that day.

After running, report what was generated: how many insights were found, which projects were included, and where the draft was saved.
