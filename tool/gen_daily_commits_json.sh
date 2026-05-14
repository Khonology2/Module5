#!/usr/bin/env bash
# Regenerate assets/data/daily-commits.json using the same rules as CI version labels.
# Run from repo root (or any cwd — script cds to repo root).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TODAY=$(date -u +"%Y-%m-%d")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

COMMITS_JSON=$(git log --since="${TODAY}T00:00:00Z" --pretty=format:'%an|%s|%aI' --no-merges | \
  jq -R -s '
    split("\n") |
    map(select(length > 0)) |
    map(split("|") | {author: .[0], message: .[1], timestamp: .[2]})
  ')

COMMIT_COUNT=$(git log --since="${TODAY}T00:00:00Z" --oneline --no-merges | wc -l)
COMMIT_COUNT=$(echo "$COMMIT_COUNT" | tr -d ' ')

if [ "$COMMIT_COUNT" -eq 0 ]; then
  COMMITS_JSON="[]"
  COMMIT_COUNT=0
fi

YEAR=$(date -u +"%Y")
MONTH=$(date -u +"%m")
DAY=$(date -u +"%d")

WEEK_OF_MONTH=$(( (10#$DAY - 1) / 7 + 1 ))
WEEK_LETTER=$(echo "ABCD" | cut -c$(( (WEEK_OF_MONTH - 1) % 4 + 1 )))

VERSION="${YEAR}.${MONTH}.${WEEK_LETTER}B${COMMIT_COUNT}.SIT"

mkdir -p assets/data

jq -n \
  --arg version "$VERSION" \
  --arg generated_at "$TIMESTAMP" \
  --argjson commits "$COMMITS_JSON" \
  --arg total_commits "$COMMIT_COUNT" \
  --arg date_range "$TODAY" \
  '{
    version: $version,
    generated_at: $generated_at,
    commits: $commits,
    total_commits: ($total_commits | tonumber),
    date_range: $date_range
  }' > assets/data/daily-commits.json

echo "gen_daily_commits_json: wrote assets/data/daily-commits.json version=${VERSION} (commits_today_utc=${COMMIT_COUNT})"
