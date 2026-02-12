---
description: "Publish a draft dev log (flip draft to false, commit, and push)"
argument-hint: "[YYYY-MM-DD]"
allowed-tools:
  - Bash
---

Publish a draft dev log. Run the publish script from the devlog plugin:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/publish-devlog.sh $ARGUMENTS
```

If no date is provided, publishes the most recent draft dev log. Report the result and the live URL.
