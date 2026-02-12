#!/usr/bin/env python3
"""Extract verbatim insight blocks from today's Claude Code conversation logs.

Scans all JSONL conversation files across ~/.claude/projects/*/,
finds assistant messages containing insight blocks, and writes
them to the daily journal directory.

Usage: extract-insights.py [YYYY-MM-DD] [--journal-dir DIR]
"""

import json
import os
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"

# Regex to extract text between backtick-wrapped insight delimiters
# Actual format in JSONL: `★ Insight ───...`\n<content>\n`───...`
INSIGHT_PATTERN = re.compile(
    r"`★ Insight ─+`\s*\n(.*?)\n`─+`",
    re.DOTALL,
)


def project_name_from_dir(dirname: str) -> str:
    """Convert directory name like '-Users-varunr-projects-cohouser' to 'cohouser'."""
    parts = dirname.split("-projects-")
    if len(parts) > 1:
        return parts[-1]
    return dirname


def extract_insights_from_file(filepath: Path, target_date: date) -> list[dict]:
    """Parse a JSONL file and extract insight blocks from target date."""
    insights = []

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                message = entry.get("message", {})
                if message.get("role") != "assistant":
                    continue

                timestamp_str = entry.get("timestamp", "")
                if not timestamp_str:
                    continue

                try:
                    ts = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
                    if ts.date() != target_date:
                        continue
                except (ValueError, TypeError):
                    continue

                content_blocks = message.get("content", [])
                for block in content_blocks:
                    if block.get("type") != "text":
                        continue

                    text = block.get("text", "")
                    if "★ Insight" not in text:
                        continue

                    for match in INSIGHT_PATTERN.finditer(text):
                        insight_text = match.group(1).strip()
                        if insight_text:
                            insights.append({
                                "timestamp": timestamp_str,
                                "insight": insight_text,
                            })

    except (OSError, UnicodeDecodeError):
        pass

    return insights


def main():
    target_date = date.today()
    journal_dir = Path.home() / ".claude" / "daily-journal"

    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg == "--journal-dir" and i + 1 < len(args):
            journal_dir = Path(args[i + 1]).expanduser()
        elif not arg.startswith("--"):
            target_date = date.fromisoformat(arg)

    journal_dir.mkdir(parents=True, exist_ok=True)
    output_file = journal_dir / f"{target_date.isoformat()}-insights.jsonl"

    all_insights = []

    if not PROJECTS_DIR.exists():
        print(f"Projects directory not found: {PROJECTS_DIR}")
        sys.exit(0)

    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue

        project_name = project_name_from_dir(project_dir.name)

        for jsonl_file in project_dir.glob("*.jsonl"):
            try:
                mtime = datetime.fromtimestamp(jsonl_file.stat().st_mtime)
                if mtime.date() < target_date:
                    continue
            except OSError:
                continue

            insights = extract_insights_from_file(jsonl_file, target_date)
            for insight in insights:
                insight["project"] = project_name
                all_insights.append(insight)

    if not all_insights:
        print(f"No insights found for {target_date}")
        sys.exit(0)

    all_insights.sort(key=lambda x: x.get("timestamp", ""))

    with open(output_file, "w", encoding="utf-8") as f:
        for entry in all_insights:
            f.write(json.dumps(entry) + "\n")

    print(f"Extracted {len(all_insights)} insights to {output_file}")


if __name__ == "__main__":
    main()
