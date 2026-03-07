#!/usr/bin/env bash
# IAM — all seven query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="IAM"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Permission Resolution ==="
echo "Discover all resources alice@company.com can access through any chain."
echo ""
query "sql" "
SELECT resource, action, via_role, via_group
FROM (
  MATCH {type: Identity, where: (email = 'alice@company.com'), as: u}
        .out('MEMBER_OF'){while: (\$depth < 3), as: g}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){as: p}
        .out('APPLIES_TO'){as: res}
  RETURN res.name AS resource, p.action AS action,
         r.name AS via_role, g.name AS via_group
)
ORDER BY resource, action
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Shadow Admin Detection ==="
echo "Find contractors/service accounts with admin on critical resources."
echo ""
query "sql" "
SELECT identity, identity_type, critical_resource, via_role
FROM (
  MATCH {type: Identity, where: (identityType IN ['contractor', 'service_account']), as: u}
        .out('MEMBER_OF'){while: (\$depth < 5)}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){where: (action = 'admin')}
        .out('APPLIES_TO'){as: res, where: (classification = 'critical')}
  RETURN u.email AS identity, u.identityType AS identity_type,
         res.name AS critical_resource, r.name AS via_role
)
ORDER BY identity
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: SOX Compliance Audit ==="
echo "Track access to SOX-governed resources with policy lineage."
echo ""

echo "--- SOX-governed resources ---"
SOX_RESULT=$(query "sql" "
SELECT resource, policy
FROM (
  MATCH {type: Resource, as: res}
        .out('GOVERNED_BY'){as: pol, where: (name = 'SOX-Compliance')}
  RETURN res.name AS resource, pol.name AS policy
)
")
echo "$SOX_RESULT"

RESOURCE_LIST=$(echo "$SOX_RESULT" | jq -r '[.[].resource] | map("'"'"'" + . + "'"'"'") | join(", ")')

echo ""
echo "--- Access logs for SOX-scoped resources ---"
query "sql" "
SELECT identityEmail, action, resourceName, recordedAt, source_ip
FROM AccessLog
WHERE resourceName IN [${RESOURCE_LIST}]
  AND recordedAt > '2025-12-01 00:00:00'
ORDER BY recordedAt DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Separation of Duties Violation ==="
echo "Find users who can both approve AND execute on the same resource."
echo ""

echo "--- Identities with approve permission ---"
APPROVERS=$(query "sql" "
SELECT identity, resource, role
FROM (
  MATCH {type: Identity, as: u}
        .out('MEMBER_OF'){while: (\$depth < 3)}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){where: (action = 'approve')}
        .out('APPLIES_TO'){as: res}
  RETURN u.email AS identity, res.name AS resource, r.name AS role
)
")
echo "$APPROVERS"

echo ""
echo "--- Identities with execute permission ---"
EXECUTORS=$(query "sql" "
SELECT identity, resource, role
FROM (
  MATCH {type: Identity, as: u}
        .out('MEMBER_OF'){while: (\$depth < 3)}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){where: (action = 'execute')}
        .out('APPLIES_TO'){as: res}
  RETURN u.email AS identity, res.name AS resource, r.name AS role
)
")
echo "$EXECUTORS"

echo ""
echo "--- SoD violations (approve AND execute on same resource) ---"
jq -n --argjson a "$APPROVERS" --argjson e "$EXECUTORS" '
  [$a[] | {key: (.identity + "|" + .resource), value: .}] | from_entries as $am
  | [$e[] | select($am[.identity + "|" + .resource])
     | "VIOLATION: \(.identity) on \(.resource) | approve via: \($am[.identity + "|" + .resource].role) | execute via: \(.role)"]
  | .[]' -r

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Dormant Access Detection ==="
echo "Find identities with permissions but no access in the last 90 days."
echo ""

echo "--- Step 1: Identities with granted permissions ---"
GRANTED=$(query "sql" "
SELECT DISTINCT identity, resource
FROM (
  MATCH {type: Identity, as: u}
        .out('MEMBER_OF'){while: (\$depth < 3)}
        .out('HAS_ROLE'){}
        .out('GRANTS'){}
        .out('APPLIES_TO'){as: res}
  RETURN u.email AS identity, res.name AS resource
)
ORDER BY identity
")
echo "$GRANTED"

echo ""
echo "--- Step 2: Identities with recent access (last 90 days) ---"
RECENT=$(query "sql" "
SELECT DISTINCT identityEmail
FROM AccessLog
WHERE recordedAt > '2025-12-06 00:00:00'
ORDER BY identityEmail
")
echo "$RECENT"

echo ""
echo "--- Dormant identities (have permissions but no recent access) ---"
jq -n --argjson g "$GRANTED" --argjson r "$RECENT" '
  ([$g[].identity] | unique) as $granted
  | ([$r[].identityEmail] | unique) as $recent
  | ($granted - $recent) | .[]' -r

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Behavioral Anomaly Detection ==="
echo "Rank employees by how similar their access pattern is to a 'normal' session."
echo ""
query "sql" "
SELECT email, department, identityType
FROM Identity
WHERE identityType = 'employee'
ORDER BY vectorNeighbors('Identity[access_pattern_vec]', [0.5, 0.5, 0.3, 0.1, 0.2, 0.1, 0.1, 0.1], 10) DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Impact Analysis (What-If) ==="
echo "What happens if we remove the Platform-Admins group?"
echo ""

echo "--- Permissions granted through Platform-Admins ---"
query "sql" "
SELECT role, action, resource
FROM (
  MATCH {type: \`Group\`, where: (name = 'Platform-Admins'), as: target}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){as: p}
        .out('APPLIES_TO'){as: res}
  RETURN r.name AS role, p.action AS action, res.name AS resource
)
ORDER BY resource
"

echo ""
echo "--- Identities affected (members of Platform-Admins, direct or transitive) ---"
query "sql" "
SELECT DISTINCT identity
FROM (
  MATCH {type: \`Group\`, where: (name = 'Platform-Admins')}
        .in('MEMBER_OF'){as: member, while: (\$depth < 3)}
  RETURN member.email AS identity
)
WHERE identity IS NOT NULL
ORDER BY identity
"
