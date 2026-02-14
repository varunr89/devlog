#!/bin/bash
set -Eeuo pipefail

# Batch-generate devlogs for all historical dates with conversation activity.
# Extracts insights first, then generates devlog posts one by one.
# Usage: batch-generate-devlogs.sh [--dry-run]
#
# Skips dates that already have a devlog file in the blog content dir.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/read-settings.sh"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

POSTS_DIR="$BLOG_DIR/$CONTENT_PATH"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Step 1: Find all dates with conversation activity from Dec 2025 onward.
log "Finding dates with conversation activity..."

DATES=$(python3 -c "
import json, os
from datetime import date, datetime
from pathlib import Path

projects_dir = Path.home() / '.claude' / 'projects'
cutoff = date(2025, 12, 1)
today = date.today()
dates_seen = set()

for project_dir in projects_dir.iterdir():
    if not project_dir.is_dir():
        continue
    for jsonl_file in project_dir.glob('*.jsonl'):
        try:
            with open(jsonl_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        ts_str = entry.get('timestamp', '')
                        if ts_str:
                            ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                            d = ts.date()
                            if d >= cutoff and d < today:
                                dates_seen.add(d.isoformat())
                    except (json.JSONDecodeError, ValueError):
                        continue
        except (OSError, UnicodeDecodeError):
            continue

for d in sorted(dates_seen):
    print(d)
")

TOTAL=$(echo "$DATES" | wc -l | tr -d ' ')
log "Found $TOTAL dates with activity"

# Step 2: Filter out dates that already have devlog files.
PENDING_DATES=()
for d in $DATES; do
    if [ -f "$POSTS_DIR/devlog-$d.md" ]; then
        log "  SKIP $d (already exists)"
    else
        PENDING_DATES+=("$d")
    fi
done

log "${#PENDING_DATES[@]} dates need devlogs"

if [ "$DRY_RUN" = true ]; then
    log "DRY RUN -- would generate devlogs for:"
    for d in "${PENDING_DATES[@]}"; do
        echo "  $d"
    done
    exit 0
fi

# Step 3: Extract insights for all pending dates.
log "Extracting insights for all pending dates..."
DATES_WITH_INSIGHTS=()

for d in "${PENDING_DATES[@]}"; do
    python3 "$SCRIPT_DIR/extract-insights.py" "$d" --journal-dir "$JOURNAL_DIR" 2>&1 | tee -a "$LOG_FILE" || true

    INSIGHTS_FILE="$JOURNAL_DIR/$d-insights.jsonl"
    if [ -f "$INSIGHTS_FILE" ] && [ -s "$INSIGHTS_FILE" ]; then
        COUNT=$(wc -l < "$INSIGHTS_FILE" | tr -d ' ')
        DATES_WITH_INSIGHTS+=("$d")
        log "  $d: $COUNT insights"
    else
        log "  $d: no insights found, skipping"
    fi
done

log "${#DATES_WITH_INSIGHTS[@]} dates have insights to generate devlogs"

# Step 4: Generate devlog for each date with insights.
GENERATED=0
FAILED=0

for d in "${DATES_WITH_INSIGHTS[@]}"; do
    log "Generating devlog for $d (${GENERATED}/${#DATES_WITH_INSIGHTS[@]} done)..."

    INSIGHTS_FILE="$JOURNAL_DIR/$d-insights.jsonl"
    OUTPUT_FILE="$POSTS_DIR/devlog-$d.md"

    # Build the prompt (same logic as generate-devlog.sh)
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

    PROMPT="Generate a dev log for $d.

Rules:
- Output ONLY the markdown file content, nothing else
- Start with Astro frontmatter (title, date, description, draft: true)
- Title format: \"Dev Log: Month Day, Year\"
- Group content by project using ### headers
- For each project, include the strategic summary (if available) as a paragraph
$INSIGHT_FORMAT
- Separate project sections with horizontal rules (---)
- Keep the description field short: list the project names
- Do NOT paraphrase or modify the insight text in any way
- Do NOT use em-dashes

Verbatim insights (include these EXACTLY as written):
\`\`\`
$(cat "$INSIGHTS_FILE")
\`\`\`"

    cd "$BLOG_DIR"
    # Write to temp file first, then move atomically to prevent Astro seeing empty files
    TEMP_FILE=$(mktemp)
    # Run claude -p in background with 5-minute watchdog to prevent hangs
    # Unset CLAUDECODE to allow running inside another Claude Code session
    echo "$PROMPT" | env -u CLAUDECODE claude -p --no-session-persistence > "$TEMP_FILE" 2>> "$LOG_FILE" &
    CLAUDE_PID=$!

    # Wait up to 300 seconds
    WAITED=0
    while kill -0 "$CLAUDE_PID" 2>/dev/null && [ "$WAITED" -lt 300 ]; do
        sleep 5
        WAITED=$((WAITED + 5))
    done

    if kill -0 "$CLAUDE_PID" 2>/dev/null; then
        # Still running after timeout -- kill it
        kill "$CLAUDE_PID" 2>/dev/null || true
        sleep 2
        kill -9 "$CLAUDE_PID" 2>/dev/null || true
        wait "$CLAUDE_PID" 2>/dev/null || true

        if [ -s "$TEMP_FILE" ]; then
            mv "$TEMP_FILE" "$OUTPUT_FILE"
            GENERATED=$((GENERATED + 1))
            log "  Created $OUTPUT_FILE (timed out but file has content)"
        else
            FAILED=$((FAILED + 1))
            log "  ERROR: Timed out for $d"
            rm -f "$TEMP_FILE"
        fi
    else
        wait "$CLAUDE_PID"
        EXIT_CODE=$?
        if [ -s "$TEMP_FILE" ]; then
            mv "$TEMP_FILE" "$OUTPUT_FILE"
            GENERATED=$((GENERATED + 1))
            log "  Created $OUTPUT_FILE"
        else
            FAILED=$((FAILED + 1))
            log "  ERROR: claude failed for $d (exit $EXIT_CODE)"
            rm -f "$TEMP_FILE"
        fi
    fi
done

# Step 5: Commit all generated devlogs.
log "Generation complete: $GENERATED succeeded, $FAILED failed"

if [ "$GENERATED" -gt 0 ]; then
    cd "$BLOG_DIR"
    git add "$POSTS_DIR"/devlog-*.md
    if ! git diff --cached --quiet; then
        git commit -m "Add $GENERATED historical dev log drafts (Dec 2025 - Feb 2026)"
        log "Committed $GENERATED draft devlogs"
    fi
fi

log "Batch generation complete"
