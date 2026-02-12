---
description: "Use when generating or publishing dev log posts, or when configuring the devlog plugin. Provides blog directory, URL, and formatting preferences."
---

# Devlog Settings

Read settings from `~/.claude/devlog.local.md` YAML frontmatter before generating or publishing posts.

## Settings File Format

The file `~/.claude/devlog.local.md` contains YAML frontmatter with these fields:

```yaml
---
blog_dir: ~/projects/bhavanaai
blog_url: https://me.bhavanaai.com
content_path: src/content/blog
journal_dir: ~/.claude/daily-journal
insight_style: div
show_insight_label: false
---
```

### Fields

- **blog_dir** (required): Path to the Astro blog project
- **blog_url** (required): Live site URL, used by publish-devlog to print the live link
- **content_path** (default: `src/content/blog`): Where blog posts live relative to blog_dir
- **journal_dir** (default: `~/.claude/daily-journal`): Where daily journal entries and extracted insights are stored
- **insight_style** (default: `div`): How insights are formatted in posts. `div` wraps each insight in `<div class="insight">`, `blockquote` uses `>` markdown blockquotes
- **show_insight_label** (default: `false`): Whether to include a `<strong>Insight</strong>` label inside each insight block

## Reading Settings

Use this bash snippet to read settings in scripts:

```bash
SETTINGS_FILE="$HOME/.claude/devlog.local.md"
if [ -f "$SETTINGS_FILE" ]; then
    BLOG_DIR=$(sed -n 's/^blog_dir: *//p' "$SETTINGS_FILE" | sed "s|~|$HOME|")
    BLOG_URL=$(sed -n 's/^blog_url: *//p' "$SETTINGS_FILE")
    CONTENT_PATH=$(sed -n 's/^content_path: *//p' "$SETTINGS_FILE")
    JOURNAL_DIR=$(sed -n 's/^journal_dir: *//p' "$SETTINGS_FILE" | sed "s|~|$HOME|")
    INSIGHT_STYLE=$(sed -n 's/^insight_style: *//p' "$SETTINGS_FILE")
    SHOW_INSIGHT_LABEL=$(sed -n 's/^show_insight_label: *//p' "$SETTINGS_FILE")
fi

# Defaults
BLOG_DIR="${BLOG_DIR:-$HOME/projects/bhavanaai}"
BLOG_URL="${BLOG_URL:-https://me.bhavanaai.com}"
CONTENT_PATH="${CONTENT_PATH:-src/content/blog}"
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/.claude/daily-journal}"
INSIGHT_STYLE="${INSIGHT_STYLE:-div}"
SHOW_INSIGHT_LABEL="${SHOW_INSIGHT_LABEL:-false}"
```
