#!/bin/bash
set -Eeuo pipefail

# Generate a daily dev log from journal entries and insights.
# Works standalone (writes to ~/.claude/devlogs/) or with a blog (writes to blog content dir).
# Usage: generate-devlog.sh [YYYY-MM-DD]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/read-settings.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Use provided date or yesterday's date (since this runs at midnight)
if [ -n "${1:-}" ]; then
    TARGET_DATE="$1"
else
    TARGET_DATE=$(date -v-1d '+%Y-%m-%d')
fi

log "Starting dev log generation for $TARGET_DATE (mode: $([ "$BLOG_MODE" = true ] && echo blog || echo standalone))"

# Step 1: Extract insights
log "Extracting insights..."
python3 "$SCRIPT_DIR/extract-insights.py" "$TARGET_DATE" --journal-dir "$JOURNAL_DIR" >> "$LOG_FILE" 2>&1 || true

JOURNAL_FILE="$JOURNAL_DIR/$TARGET_DATE.jsonl"
INSIGHTS_FILE="$JOURNAL_DIR/$TARGET_DATE-insights.jsonl"

# Check if we have anything to work with
HAS_JOURNAL=false
HAS_INSIGHTS=false

if [ -f "$JOURNAL_FILE" ] && [ -s "$JOURNAL_FILE" ]; then
    HAS_JOURNAL=true
fi

if [ -f "$INSIGHTS_FILE" ] && [ -s "$INSIGHTS_FILE" ]; then
    HAS_INSIGHTS=true
fi

if [ "$HAS_JOURNAL" = false ] && [ "$HAS_INSIGHTS" = false ]; then
    log "No journal entries or insights found for $TARGET_DATE. Skipping."
    exit 0
fi

# Step 2: Build insight format instructions based on settings
if [ "$INSIGHT_STYLE" = "div" ]; then
    if [ "$SHOW_INSIGHT_LABEL" = "true" ]; then
        INSIGHT_FORMAT='- Include ALL insights VERBATIM wrapped in HTML divs:
  <div class="insight">
  <strong>Insight</strong>

  [insight text here, verbatim]

  </div>'
    else
        INSIGHT_FORMAT='- Include ALL insights VERBATIM wrapped in HTML divs:
  <div class="insight">

  [insight text here, verbatim]

  </div>'
    fi
else
    INSIGHT_FORMAT="- Include ALL insights VERBATIM as blockquotes prefixed with '> **Insight:**'"
fi

# Step 3: Build the prompt for Claude
if [ "$BLOG_MODE" = true ]; then
    FRONTMATTER_RULE='- Start with Astro frontmatter (title, date, description, draft: true)'
else
    FRONTMATTER_RULE='- Start with YAML frontmatter: title, date'
fi

PROMPT="Generate a dev log for $TARGET_DATE.

Rules:
- Output ONLY the markdown file content, nothing else
$FRONTMATTER_RULE
- Title format: \"Dev Log: Month Day, Year\"
- Group content by project using ### headers
- For each project, include the strategic summary (if available) as a paragraph
$INSIGHT_FORMAT
- Separate project sections with horizontal rules (---)
- Keep the description field short: list the project names
- Do NOT paraphrase or modify the insight text in any way
- Do NOT use em-dashes

"

if [ "$HAS_JOURNAL" = true ]; then
    PROMPT+="Strategic summaries from the day:
\`\`\`
$(cat "$JOURNAL_FILE")
\`\`\`

"
fi

if [ "$HAS_INSIGHTS" = true ]; then
    PROMPT+="Verbatim insights (include these EXACTLY as written):
\`\`\`
$(cat "$INSIGHTS_FILE")
\`\`\`
"
fi

# Step 4: Determine output path and generate
if [ "$BLOG_MODE" = true ]; then
    OUTPUT_FILE="$BLOG_DIR/$CONTENT_PATH/devlog-$TARGET_DATE.md"
    cd "$BLOG_DIR"
else
    OUTPUT_FILE="$OUTPUT_DIR/devlog-$TARGET_DATE.md"
fi

log "Generating dev log with claude..."
echo "$PROMPT" | claude -p --no-session-persistence > "$OUTPUT_FILE" 2>> "$LOG_FILE"

if [ ! -f "$OUTPUT_FILE" ]; then
    log "ERROR: Dev log was not created"
    exit 1
fi

log "Dev log created at $OUTPUT_FILE"

# Step 5: Blog-specific post-processing
if [ "$BLOG_MODE" = true ]; then
    # Commit as draft
    cd "$BLOG_DIR"
    git add "$OUTPUT_FILE"

    if ! git diff --cached --quiet; then
        git commit -m "Add dev log draft for $TARGET_DATE" >> "$LOG_FILE" 2>&1
        log "Committed draft dev log for $TARGET_DATE"
    fi

    # Start dev server and open draft in browser
    SLUG="devlog-$TARGET_DATE"
    DEV_URL="http://localhost:4321/blog/$SLUG"

    if ! lsof -i :4321 -sTCP:LISTEN > /dev/null 2>&1; then
        log "Starting Astro dev server..."
        cd "$BLOG_DIR"
        npm run dev > /dev/null 2>&1 &
        DEV_PID=$!
        log "Dev server started (PID $DEV_PID)"
        for i in $(seq 1 30); do
            if curl -s -o /dev/null "$DEV_URL" 2>/dev/null; then
                break
            fi
            sleep 1
        done
    fi

    open "$DEV_URL"
    log "Opened draft at $DEV_URL"
    osascript -e "display notification \"Run: publish-devlog $TARGET_DATE\" with title \"Dev Log Ready\" subtitle \"Draft for $TARGET_DATE is ready for review\""
else
    # Standalone: just open the file
    open "$OUTPUT_FILE"
    osascript -e "display notification \"Dev log saved to $OUTPUT_FILE\" with title \"Dev Log Ready\" subtitle \"$TARGET_DATE\""
fi

log "Generation complete for $TARGET_DATE"
