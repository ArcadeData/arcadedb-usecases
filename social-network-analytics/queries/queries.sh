#!/usr/bin/env bash
# Social Network Analytics — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="SocialNetwork"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"
COMMAND_URL="${ARCADEDB_URL}/api/v1/command/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

command() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$COMMAND_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Trending Content Dashboard (Materialized View — PERIODIC) ==="
echo "Read pre-computed trending scores from the TrendingPosts materialized view."
echo ""
query "sql" "
SELECT postRid, totalLikes, totalShares, totalComments, score
FROM TrendingPosts
ORDER BY score DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Engagement Time-Series ==="
echo "Drill into the viral post's engagement growth over time."
echo ""
query "sql" "
SELECT recordedAt, likes, shares, comments
FROM EngagementMetric
WHERE postRid = 'ai-trends-2026'
ORDER BY recordedAt
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Influence Leaderboard (Materialized View — MANUAL) ==="
echo "Refresh and query the InfluenceScores view for top users by follower count."
echo ""
command "sql" "REFRESH MATERIALIZED VIEW InfluenceScores"
echo "InfluenceScores refreshed."
echo ""
query "sql" "
SELECT userName, handle, followers
FROM InfluenceScores
ORDER BY followers DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Viral Spread Chain (OpenCypher — Graph Traversal) ==="
echo "Trace how the AI Trends post spread: author -> sharers -> their followers."
echo ""
query "opencypher" "
MATCH (author:User)-[:CREATED]->(p:Post)<-[:SHARED]-(sharer:User)<-[:FOLLOWS]-(audience:User)
WHERE p.title = 'AI Trends in 2026'
RETURN author.name AS author, sharer.name AS sharer, collect(DISTINCT audience.name) AS reachedAudience
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Community Overlap (OpenCypher — Graph Traversal) ==="
echo "Find users in the same group who also follow each other."
echo ""
query "opencypher" "
MATCH (a:User)-[:MEMBER_OF]->(g:Group)<-[:MEMBER_OF]-(b:User)
WHERE (a)-[:FOLLOWS]->(b) AND id(a) < id(b)
RETURN g.name AS group, a.name AS user1, b.name AS user2
ORDER BY g.name
"
