#!/usr/bin/env bash
# Fraud Detection — all eight query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="FraudDetection"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Fraud Ring Detection (Graph Traversal) ==="
echo "Find accounts connected to a flagged account through shared identifiers."
echo ""
query "cypher" "
MATCH (flagged:Account {id: 'acct-A'})
      -[:USES_DEVICE|HAS_PHONE|HAS_ADDRESS*1..4]-
      (connected:Account)
WHERE connected <> flagged
RETURN DISTINCT connected.id, connected.name
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Synthetic Identity Resolution (Full-Text) ==="
echo "Find accounts with matching SSN but fuzzy-similar names."
echo ""
query "sql" "
SELECT a.id, b.id AS b_id, a.full_name, b.full_name AS b_full_name
FROM Account AS a, Account AS b
WHERE a.ssn = b.ssn
  AND a.id < b.id
  AND a.full_name.similarity(b.full_name) BETWEEN 0.4 AND 0.9
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Circular Money Flow (Graph Cycles) ==="
echo "Detect circular transfer paths returning to origin within 30 days."
echo ""
query "cypher" "
MATCH path = (origin:Account)-[:TRANSFERRED_TO*3..6]->(origin)
WHERE all(t IN relationships(path)
  WHERE t.ts > datetime() - duration('P30D'))
RETURN origin.id, [n IN nodes(path) | n.id] AS chain
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Structuring Detection (Time-Series) ==="
echo "Flag accounts making 3+ deposits per day in the \$8,000–\$9,999 range."
echo ""
query "sql" "
SELECT time_bucket('1d', ts) AS day, account_id, count(*) AS deposit_count
FROM Deposit
WHERE amount BETWEEN 8000 AND 9999
GROUP BY day, account_id
HAVING deposit_count >= 3
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Behavioral Anomaly (Vector Distance) ==="
echo "Detect transactions whose behavioral embedding deviates from the customer profile."
echo ""
query "sql" "
SELECT t.id, t.amount, t.merchant,
       vectorDistance(t.behavior_embedding, c.profile_embedding) AS deviation
FROM Transaction t
JOIN Customer c ON t.account_id = c.id
WHERE vectorDistance(t.behavior_embedding, c.profile_embedding) > 0.7
ORDER BY deviation DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Velocity Attack Detection (Time-Series) ==="
echo "Detect accounts with abnormally high transaction rates in a 5-minute window."
echo ""
query "sql" "
SELECT account_id, count(*) AS txn_count, min(ts) AS first_txn, max(ts) AS last_txn
FROM Transaction
WHERE ts BETWEEN '2026-03-01T13:00:00Z' AND '2026-03-01T13:05:00Z'
GROUP BY account_id
HAVING txn_count > 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Correlated Account Activity (Time-Series) ==="
echo "Detect coordinated transfer amounts between two accounts."
echo ""
query "sql" "
SELECT a.account_id AS account_a, b.account_id AS account_b,
       avg(a.amount) AS avg_a, avg(b.amount) AS avg_b,
       count(*) AS matching_txns
FROM Transaction a, Transaction b
WHERE a.account_id = 'acct-A' AND b.account_id = 'acct-B'
  AND a.ts >= '2026-02-01T00:00:00Z'
  AND b.ts >= '2026-02-01T00:00:00Z'
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 8: Multi-Model Investigation (Combined) ==="
echo "Composite risk score blending graph connectivity, velocity, and behavioral deviation."
echo ""
query "sql" "
SELECT a.id, a.name,
       (SELECT count(*) FROM (
         MATCH {type: Account, where: (id = a.id)}
               .bothE('USES_DEVICE','HAS_PHONE','HAS_ADDRESS'){}
               .bothV(){where: (id != a.id), as: linked}
         RETURN linked
       )) AS shared_identifiers,
       (SELECT count(*) FROM Transaction WHERE account_id = a.id) AS txn_count,
       c.recent_behavior
FROM Account a
JOIN Customer c ON a.id = c.id
WHERE c.recent_behavior IN ['suspicious', 'anomalous']
ORDER BY shared_identifiers DESC
"
