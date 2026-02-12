---
description: "Use when generating or publishing dev log posts, or when configuring the devlog plugin. Provides output directory, blog integration, and formatting preferences."
---

# Devlog Settings

Read settings from `~/.claude/devlog.local.md` YAML frontmatter before generating or publishing posts.

## Modes

The plugin works in two modes based on whether `blog_dir` is set:

- **Standalone** (default): Dev logs are saved as markdown files to `~/.claude/devlogs/`. No blog, git, or dev server required.
- **Blog**: Dev logs are written to a blog's content directory, committed as drafts, and opened in a dev server for review. Requires `blog_dir` to be set.

## Standalone Config (no blog needed)

```yaml
---
journal_dir: ~/.claude/daily-journal
output_dir: ~/.claude/devlogs
insight_style: div
show_insight_label: false
---
```

## Blog Config

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

## Fields

- **blog_dir** (optional): Path to the blog project. If set, enables blog mode.
- **blog_url** (optional): Live site URL, used by publish-devlog to print the live link.
- **content_path** (default: `src/content/blog`): Blog posts directory relative to blog_dir. Only used in blog mode.
- **output_dir** (default: `~/.claude/devlogs`): Where standalone dev logs are saved. Only used in standalone mode.
- **journal_dir** (default: `~/.claude/daily-journal`): Where daily journal entries and extracted insights are stored.
- **insight_style** (default: `div`): How insights are formatted. `div` wraps in `<div class="insight">`, `blockquote` uses `>` markdown blockquotes.
- **show_insight_label** (default: `false`): Whether to include a `<strong>Insight</strong>` label inside each insight block.
