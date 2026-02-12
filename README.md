# devlog

A Claude Code plugin that auto-generates daily dev log blog posts from your coding sessions.

## What it does

1. **Captures strategic summaries** via a PreCompact hook when Claude compresses conversation context
2. **Extracts verbatim insights** from conversation logs (the `★ Insight` blocks)
3. **Generates a draft blog post** grouped by project, with summaries and insights
4. **Opens the draft** in your browser for review
5. **Publishes** with a single command

## Setup

### 1. Install the plugin

```bash
claude --plugin-dir ~/projects/devlog
```

Or add to your settings to load permanently.

### 2. Configure your blog

Create `~/.claude/devlog.local.md`:

```yaml
---
blog_dir: ~/projects/my-blog
blog_url: https://myblog.com
content_path: src/content/blog
journal_dir: ~/.claude/daily-journal
insight_style: div
show_insight_label: false
---
```

### 3. Add insight styling to your blog

Add this CSS to your blog's post template (works with Tailwind Typography's `.prose`):

```css
.prose .insight {
  background: color-mix(in srgb, var(--link) 8%, transparent);
  border-left: 3px solid var(--link);
  border-radius: 0 0.375rem 0.375rem 0;
  padding: 0.75rem 1rem;
  margin: 1rem 0;
  font-size: 0.9rem;
  line-height: 1.6;
}

.prose .insight p {
  margin: 0;
}

.prose .insight code {
  font-size: 0.85em;
}
```

### 4. Schedule nightly generation (macOS)

Create `~/Library/LaunchAgents/com.devlog.generate.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.devlog.generate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/path/to/devlog/scripts/generate-devlog.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>0</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
```

Then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.devlog.generate.plist
```

## Usage

### Commands

- `/generate-devlog [YYYY-MM-DD]` - Generate a dev log post (defaults to yesterday)
- `/publish-devlog [YYYY-MM-DD]` - Publish the most recent draft (or a specific date)

### Shell aliases (optional)

```bash
alias generate-devlog='bash ~/projects/devlog/scripts/generate-devlog.sh'
alias publish-devlog='bash ~/projects/devlog/scripts/publish-devlog.sh'
```

## Settings

| Field | Default | Description |
|-------|---------|-------------|
| `blog_dir` | `~/projects/bhavanaai` | Path to your blog project |
| `blog_url` | - | Live site URL |
| `content_path` | `src/content/blog` | Blog posts directory relative to blog_dir |
| `journal_dir` | `~/.claude/daily-journal` | Where journal/insight files are stored |
| `insight_style` | `div` | `div` for styled HTML blocks, `blockquote` for markdown |
| `show_insight_label` | `false` | Show "Insight" label in each block |
