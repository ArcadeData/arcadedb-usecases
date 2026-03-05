#!/usr/bin/env bash
# Realtime Analytics — all six query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="RealtimeAnalytics"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Hourly Temperature Bucketing ==="
echo "Aggregate sensor s-A readings into 1-hour buckets."
echo ""
query "sql" "
SELECT
  time_bucket('1h', ts) AS hour,
  sensor_id,
  avg(temperature) AS avg_temp,
  max(temperature) AS max_temp,
  percentile(temperature, 0.99) AS p99_temp,
  count(*) AS samples
FROM SensorReading
WHERE ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
  AND sensor_id = 's-A'
GROUP BY hour, sensor_id
ORDER BY hour
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Service Request Rate & Latency ==="
echo "5-minute windowed rate and p99 latency per service."
echo ""
query "sql" "
SELECT
  time_bucket('5m', ts) AS window,
  service_id,
  rate(request_count) AS requests_per_sec,
  percentile(latency_ms, 0.99) AS p99_latency
FROM ServiceMetrics
WHERE ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
GROUP BY window, service_id
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Gap Filling with Interpolation ==="
echo "Fill missing temperature readings for sensor s-C using linear interpolation."
echo ""
query "sql" "
SELECT
  time_bucket('1m', ts) AS minute,
  interpolate(temperature, 'linear', ts) AS temp_filled
FROM SensorReading
WHERE sensor_id = 's-C'
  AND ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T11:30:00Z'
GROUP BY minute
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Graph + Time-Series Correlation ==="
echo "Traverse HQ building topology, join sensors to their readings."
echo ""
query "sql" "
SELECT
  sensor.name,
  avg(ts.temperature) AS avg_temp,
  max(ts.temperature) AS max_temp,
  count(*) AS samples
FROM (
  TRAVERSE out('HAS_FLOOR').out('INSTALLED_IN')
  FROM (SELECT FROM Building WHERE name = 'HQ')
  WHILE \$depth <= 2
) AS sensor
WHERE sensor.@type = 'Sensor'
  AND ts.ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
TIMESERIES sensor -> SensorReading AS ts
GROUP BY sensor.name
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Service Impact Analysis (Cypher) ==="
echo "Find services affected by srv-1 failure with live metrics."
echo ""
query "cypher" "
MATCH (failing:Server {server_id: 'srv-1'})
  <-[:RUNS_ON]-(svc:Service)
RETURN svc.name,
  ts.rate(svc, 'ServiceMetrics', 'request_count',
    datetime('2026-02-20T09:50:00Z'), datetime('2026-02-20T10:10:00Z')) AS current_rps,
  ts.last(svc, 'ServiceMetrics', 'error_count') AS errors
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 6: Continuous Aggregate ==="
echo "Query pre-computed hourly temperature rollup."
echo ""
query "sql" "
SELECT *
FROM hourly_sensor_temps
WHERE hour BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
ORDER BY hour, sensor_id
"
