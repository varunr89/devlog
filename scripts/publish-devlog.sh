#!/bin/bash
set -Eeuo pipefail

# Publish a draft dev log by flipping draft: true -> false, committing, and pushing.
# Usage: publish-devlog [YYYY-MM-DD]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/read-settings.sh"

if [ "$BLOG_MODE" = false ]; then
    echo "Publish requires blog mode. Set blog_dir in ~/.claude/devlog.local.md"
    exit 1
fi

POSTS_DIR="$BLOG_DIR/$CONTENT_PATH"

if [ -n "${1:-}" ]; then
    TARGET_DATE="$1"
    POST_FILE="$POSTS_DIR/devlog-$TARGET_DATE.md"
else
    # Find the most recent draft devlog
    POST_FILE=$(grep -rl "^draft: true" "$POSTS_DIR/devlog-"*.md 2>/dev/null | sort | tail -1)
    if [ -z "$POST_FILE" ]; then
        echo "No draft dev logs found."
        exit 1
    fi
    TARGET_DATE=$(basename "$POST_FILE" .md | sed 's/devlog-//')
fi

if [ ! -f "$POST_FILE" ]; then
    echo "No dev log found for $TARGET_DATE"
    exit 1
fi

if ! grep -q "^draft: true" "$POST_FILE"; then
    echo "Dev log for $TARGET_DATE is already published."
    exit 0
fi

# Flip draft to false
sed -i '' 's/^draft: true/draft: false/' "$POST_FILE"

# Commit and push
cd "$BLOG_DIR"
git add "$POST_FILE"
git commit -m "Publish dev log for $TARGET_DATE"
git push

echo "Published dev log for $TARGET_DATE"
if [ -n "$BLOG_URL" ]; then
    echo "Live at: $BLOG_URL/devlog/devlog-$TARGET_DATE"
fi
