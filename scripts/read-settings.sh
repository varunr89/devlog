#!/bin/bash
# Shared settings reader for devlog scripts.
# Source this file: . "$(dirname "$0")/read-settings.sh"

SETTINGS_FILE="$HOME/.claude/devlog.local.md"

BLOG_DIR=""
BLOG_URL=""
CONTENT_PATH=""

if [ -f "$SETTINGS_FILE" ]; then
    BLOG_DIR=$(sed -n 's/^blog_dir: *//p' "$SETTINGS_FILE" | sed "s|~|$HOME|")
    BLOG_URL=$(sed -n 's/^blog_url: *//p' "$SETTINGS_FILE")
    CONTENT_PATH=$(sed -n 's/^content_path: *//p' "$SETTINGS_FILE")
    JOURNAL_DIR=$(sed -n 's/^journal_dir: *//p' "$SETTINGS_FILE" | sed "s|~|$HOME|")
    INSIGHT_STYLE=$(sed -n 's/^insight_style: *//p' "$SETTINGS_FILE")
    SHOW_INSIGHT_LABEL=$(sed -n 's/^show_insight_label: *//p' "$SETTINGS_FILE")
    OUTPUT_DIR=$(sed -n 's/^output_dir: *//p' "$SETTINGS_FILE" | sed "s|~|$HOME|")
fi

# Defaults
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/.claude/daily-journal}"
INSIGHT_STYLE="${INSIGHT_STYLE:-div}"
SHOW_INSIGHT_LABEL="${SHOW_INSIGHT_LABEL:-false}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.claude/devlogs}"
LOG_FILE="$HOME/.claude/devlog-generation.log"

# Blog mode is active when blog_dir is configured
if [ -n "$BLOG_DIR" ]; then
    BLOG_MODE=true
    CONTENT_PATH="${CONTENT_PATH:-src/content/blog}"
else
    BLOG_MODE=false
fi

mkdir -p "$JOURNAL_DIR" "$OUTPUT_DIR"
