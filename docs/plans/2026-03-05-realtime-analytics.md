# Realtime Analytics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the realtime-analytics use case demonstrating ArcadeDB's native time-series engine combined with graph traversal for unified operational analytics.

**Architecture:** Two time-series types (SensorReading, ServiceMetrics) store IoT and service metrics. A graph topology (Building→Floor→Sensor, Server←Service→Service) connects to time-series via shared IDs. Six queries demonstrate time bucketing, rate of change, interpolation, graph+time-series correlation, Cypher impact analysis, and continuous aggregates.

**Tech Stack:** ArcadeDB 26.3.1, Docker Compose, curl/jq, Java 21, Maven, arcadedb-network HTTP API

**Design doc:** `docs/plans/2026-03-05-realtime-analytics-design.md`

---

### Task 1: Docker Compose

**Files:**
- Create: `realtime-analytics/docker-compose.yml`

**Step 1: Create docker-compose.yml**

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.3.1
    ports:
      - "2480:2480"
    environment:
      JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:2480/api/v1/ready"]
      interval: 5s
      timeout: 3s
      retries: 20
      start_period: 10s
```

**Step 2: Verify it starts**

Run:
```bash
cd realtime-analytics
docker compose up -d
docker compose ps   # should show healthy after ~15s
curl -sf -u root:arcadedb http://localhost:2480/api/v1/ready
docker compose down
```
Expected: healthy container, ready endpoint returns 200.

**Step 3: Commit**

```bash
git add realtime-analytics/docker-compose.yml
git commit -m "feat(realtime-analytics): add docker-compose.yml"
```

---

### Task 2: Schema SQL

**Files:**
- Create: `realtime-analytics/sql/01-schema.sql`

**Step 1: Write 01-schema.sql**

Two time-series types, five vertex types, four edge types. One statement per line.

```sql
CREATE TIMESERIES TYPE SensorReading TIMESTAMP ts PRECISION NANOSECOND TAGS (sensor_id STRING, location STRING, floor STRING) FIELDS (temperature DOUBLE, humidity DOUBLE, pressure DOUBLE) SHARDS 16 RETENTION 90 DAYS COMPACTION INTERVAL 30s
CREATE TIMESERIES TYPE ServiceMetrics TIMESTAMP ts PRECISION NANOSECOND TAGS (service_id STRING, server_id STRING) FIELDS (request_count LONG, error_count LONG, latency_ms DOUBLE) SHARDS 8 RETENTION 30 DAYS
CREATE VERTEX TYPE Building IF NOT EXISTS
CREATE PROPERTY Building.name IF NOT EXISTS STRING
CREATE VERTEX TYPE Floor IF NOT EXISTS
CREATE PROPERTY Floor.name IF NOT EXISTS STRING
CREATE PROPERTY Floor.level IF NOT EXISTS INTEGER
CREATE VERTEX TYPE Sensor IF NOT EXISTS
CREATE PROPERTY Sensor.name IF NOT EXISTS STRING
CREATE PROPERTY Sensor.sensor_id IF NOT EXISTS STRING
CREATE INDEX IF NOT EXISTS ON Sensor (sensor_id) UNIQUE
CREATE VERTEX TYPE Server IF NOT EXISTS
CREATE PROPERTY Server.name IF NOT EXISTS STRING
CREATE PROPERTY Server.server_id IF NOT EXISTS STRING
CREATE INDEX IF NOT EXISTS ON Server (server_id) UNIQUE
CREATE VERTEX TYPE Service IF NOT EXISTS
CREATE PROPERTY Service.name IF NOT EXISTS STRING
CREATE PROPERTY Service.service_id IF NOT EXISTS STRING
CREATE INDEX IF NOT EXISTS ON Service (service_id) UNIQUE
CREATE EDGE TYPE HAS_FLOOR IF NOT EXISTS
CREATE EDGE TYPE INSTALLED_IN IF NOT EXISTS
CREATE EDGE TYPE RUNS_ON IF NOT EXISTS
CREATE EDGE TYPE DEPENDS_ON IF NOT EXISTS
```

Note: `CREATE TIMESERIES TYPE` may not support `IF NOT EXISTS` — if setup.sh fails on re-run, the `|| true` on database creation handles idempotency at the DB level instead.

**Step 2: Commit**

```bash
git add realtime-analytics/sql/01-schema.sql
git commit -m "feat(realtime-analytics): add schema SQL"
```

---

### Task 3: Sample Data SQL

**Files:**
- Create: `realtime-analytics/sql/02-data.sql`

**Step 1: Write 02-data.sql**

Graph topology first, then time-series inserts. All timestamps use a fixed 2-hour window: `2026-02-20T10:00:00Z` to `2026-02-20T12:00:00Z`.

```sql
-- Buildings
INSERT INTO Building SET name = 'HQ'
INSERT INTO Building SET name = 'Data Center'
-- Floors
INSERT INTO Floor SET name = 'HQ-1', level = 1
INSERT INTO Floor SET name = 'HQ-2', level = 2
INSERT INTO Floor SET name = 'DC-1', level = 1
INSERT INTO Floor SET name = 'DC-2', level = 2
-- Sensors
INSERT INTO Sensor SET name = 'Temp Sensor A', sensor_id = 's-A'
INSERT INTO Sensor SET name = 'Temp Sensor B', sensor_id = 's-B'
INSERT INTO Sensor SET name = 'Temp Sensor C', sensor_id = 's-C'
INSERT INTO Sensor SET name = 'Temp Sensor D', sensor_id = 's-D'
INSERT INTO Sensor SET name = 'Temp Sensor E', sensor_id = 's-E'
INSERT INTO Sensor SET name = 'Temp Sensor F', sensor_id = 's-F'
-- Servers
INSERT INTO Server SET name = 'Web Server 1', server_id = 'srv-1'
INSERT INTO Server SET name = 'App Server 2', server_id = 'srv-2'
INSERT INTO Server SET name = 'DB Server 3', server_id = 'srv-3'
-- Services
INSERT INTO Service SET name = 'api-gateway', service_id = 'api-gateway'
INSERT INTO Service SET name = 'auth-service', service_id = 'auth-service'
INSERT INTO Service SET name = 'user-service', service_id = 'user-service'
INSERT INTO Service SET name = 'payment-service', service_id = 'payment-service'
INSERT INTO Service SET name = 'notification-service', service_id = 'notification-service'
-- HAS_FLOOR edges (Building -> Floor)
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'HQ') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'HQ') TO (SELECT FROM Floor WHERE name = 'HQ-2')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'Data Center') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'Data Center') TO (SELECT FROM Floor WHERE name = 'DC-2')
-- INSTALLED_IN edges (Sensor -> Floor)
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-A') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-B') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-C') TO (SELECT FROM Floor WHERE name = 'HQ-2')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-D') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-E') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-F') TO (SELECT FROM Floor WHERE name = 'DC-2')
-- RUNS_ON edges (Service -> Server)
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Server WHERE server_id = 'srv-1')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'auth-service') TO (SELECT FROM Server WHERE server_id = 'srv-1')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'user-service') TO (SELECT FROM Server WHERE server_id = 'srv-2')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'payment-service') TO (SELECT FROM Server WHERE server_id = 'srv-2')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'notification-service') TO (SELECT FROM Server WHERE server_id = 'srv-3')
-- DEPENDS_ON edges (Service -> Service)
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Service WHERE service_id = 'auth-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Service WHERE service_id = 'user-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'user-service') TO (SELECT FROM Service WHERE service_id = 'payment-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'payment-service') TO (SELECT FROM Service WHERE service_id = 'notification-service')
-- SensorReading time-series data (2-hour window, 10-15 min intervals)
-- s-A (HQ-1): regular readings
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-A', 'hq', 22.1, 55.0, 1013.2)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:15:00Z', 's-A', 'hq', 22.3, 55.2, 1013.1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:30:00Z', 's-A', 'hq', 22.5, 55.5, 1013.0)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:45:00Z', 's-A', 'hq', 23.0, 56.0, 1012.9)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-A', 'hq', 23.2, 56.3, 1012.8)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:15:00Z', 's-A', 'hq', 23.8, 57.0, 1012.7)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:30:00Z', 's-A', 'hq', 24.1, 57.5, 1012.6)
-- s-B (HQ-1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-B', 'hq', 21.8, 54.0, 1013.3)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:30:00Z', 's-B', 'hq', 22.0, 54.5, 1013.1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-B', 'hq', 22.5, 55.0, 1012.9)
-- s-C (HQ-2): deliberate gap between 10:15 and 11:00 for interpolation query
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-C', 'hq', 23.0, 58.0, 1013.0)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:15:00Z', 's-C', 'hq', 23.2, 58.2, 1012.9)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-C', 'hq', 25.0, 60.0, 1012.5)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:30:00Z', 's-C', 'hq', 25.5, 61.0, 1012.3)
-- s-D (DC-1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-D', 'dc', 19.0, 45.0, 1014.0)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:30:00Z', 's-D', 'dc', 19.2, 45.5, 1013.9)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-D', 'dc', 19.5, 46.0, 1013.8)
-- s-E (DC-1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-E', 'dc', 18.5, 44.0, 1014.1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-E', 'dc', 18.8, 44.5, 1014.0)
-- s-F (DC-2)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-F', 'dc', 20.0, 48.0, 1013.5)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-F', 'dc', 20.5, 48.5, 1013.3)
-- ServiceMetrics time-series data (same 2-hour window)
-- api-gateway on srv-1: high traffic
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'api-gateway', 'srv-1', 15000, 12, 45.2)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'api-gateway', 'srv-1', 15500, 8, 42.1)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:10:00Z', 'api-gateway', 'srv-1', 16200, 15, 48.7)
-- auth-service on srv-1
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'auth-service', 'srv-1', 8000, 3, 22.0)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'auth-service', 'srv-1', 8200, 2, 21.5)
-- user-service on srv-2
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'user-service', 'srv-2', 5000, 5, 35.0)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'user-service', 'srv-2', 5200, 4, 33.8)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:10:00Z', 'user-service', 'srv-2', 5100, 6, 36.5)
-- payment-service on srv-2: some errors
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'payment-service', 'srv-2', 2000, 25, 120.5)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'payment-service', 'srv-2', 2100, 30, 135.2)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:10:00Z', 'payment-service', 'srv-2', 1800, 45, 180.0)
-- notification-service on srv-3
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'notification-service', 'srv-3', 3000, 1, 15.0)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'notification-service', 'srv-3', 3100, 0, 14.5)
```

**Step 2: Commit**

```bash
git add realtime-analytics/sql/02-data.sql
git commit -m "feat(realtime-analytics): add sample data SQL"
```

---

### Task 4: Continuous Aggregate SQL

**Files:**
- Create: `realtime-analytics/sql/03-aggregates.sql`

**Step 1: Write 03-aggregates.sql**

```sql
CREATE CONTINUOUS AGGREGATE hourly_sensor_temps AS SELECT time_bucket('1 hour', ts) AS hour, sensor_id, avg(temperature) AS avg_temp, max(temperature) AS max_temp, min(temperature) AS min_temp FROM SensorReading GROUP BY hour, sensor_id
```

**Step 2: Commit**

```bash
git add realtime-analytics/sql/03-aggregates.sql
git commit -m "feat(realtime-analytics): add continuous aggregate SQL"
```

---

### Task 5: setup.sh

**Files:**
- Create: `realtime-analytics/setup.sh`

**Step 1: Write setup.sh**

Follow the exact pattern from `recommendation-engine/setup.sh`. The only differences: `DB_NAME=RealtimeAnalytics` and an additional `apply_file "sql/03-aggregates.sql"` at the end.

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="RealtimeAnalytics"

# ── Wait for ArcadeDB ─────────────────────────────────────────────────────────
echo "Waiting for ArcadeDB at ${ARCADEDB_URL}..."
until curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
    "${ARCADEDB_URL}/api/v1/ready" > /dev/null 2>&1; do
  sleep 2
done
echo "ArcadeDB is ready."

# ── Create database ───────────────────────────────────────────────────────────
echo "Creating database ${DB_NAME}..."
curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
  -X POST "${ARCADEDB_URL}/api/v1/server" \
  -H "Content-Type: application/json" \
  -d "{\"command\": \"create database ${DB_NAME}\"}" > /dev/null || true
echo "Database ready."

# ── Helper: send one SQL statement ───────────────────────────────────────────
send_sql() {
  local stmt="$1"
  jq -cn --arg cmd "$stmt" '{"language":"sql","command":$cmd}' \
    | curl -sf -u "${ARCADEDB_USER}:${ARCADEDB_PASS}" \
        -X POST "${ARCADEDB_URL}/api/v1/command/${DB_NAME}" \
        -H "Content-Type: application/json" \
        -d @- > /dev/null
}

# ── Apply a SQL file (one statement per line) ─────────────────────────────────
apply_file() {
  local file="$1"
  echo "Applying ${file}..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip blank lines and SQL comments
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*-- ]] && continue
    send_sql "${line%%;}"
  done < "$file"
  echo "Done: ${file}"
}

apply_file "sql/01-schema.sql"
apply_file "sql/02-data.sql"
apply_file "sql/03-aggregates.sql"

echo ""
echo "Setup complete. ${DB_NAME} is ready."
```

**Step 2: Make executable**

Run: `chmod +x realtime-analytics/setup.sh`

**Step 3: Test end-to-end (Docker + setup)**

Run:
```bash
cd realtime-analytics
docker compose up -d
./setup.sh
```
Expected: "Setup complete. RealtimeAnalytics is ready." with no errors.

If `CREATE TIMESERIES TYPE` fails via the line-by-line `send_sql` approach, the statement may need to be sent as a single line (which it already is in `01-schema.sql`). If the HTTP API requires a different endpoint or content type for time-series DDL, adjust `send_sql` accordingly — check the error message.

**Step 4: Commit**

```bash
git add realtime-analytics/setup.sh
git commit -m "feat(realtime-analytics): add setup.sh"
```

---

### Task 6: queries.sh

**Files:**
- Create: `realtime-analytics/queries/queries.sh`

**Step 1: Write queries.sh**

```bash
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
```

**Step 2: Make executable**

Run: `chmod +x realtime-analytics/queries/queries.sh`

**Step 3: Test queries**

Run:
```bash
cd realtime-analytics
./queries/queries.sh
```
Expected: all 6 queries return non-empty JSON result arrays.

If any query fails, read the error carefully:
- Time-series SQL functions may have slightly different syntax in 26.3.1 than the marketing page shows. Adjust function names/signatures based on error messages.
- The `TIMESERIES ... AS` join syntax in Query 4 is the most novel — if it fails, try an alternative approach: separate the graph traversal and time-series query, or use a subquery.
- The Cypher `ts.rate()` / `ts.last()` functions in Query 5 may need adjustment — if Cypher doesn't support these, convert to SQL with a `MATCH` block instead.

**Step 4: Commit**

```bash
git add realtime-analytics/queries/queries.sh
git commit -m "feat(realtime-analytics): add queries.sh"
```

---

### Task 7: Java — pom.xml

**Files:**
- Create: `realtime-analytics/java/pom.xml`

**Step 1: Write pom.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.arcadedb.examples</groupId>
  <artifactId>realtime-analytics</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <arcadedb.version>26.3.1</arcadedb.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>com.arcadedb</groupId>
      <artifactId>arcadedb-network</artifactId>
      <version>${arcadedb.version}</version>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-assembly-plugin</artifactId>
        <version>3.8.0</version>
        <configuration>
          <archive>
            <manifest>
              <mainClass>com.arcadedb.examples.RealtimeAnalytics</mainClass>
            </manifest>
          </archive>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <finalName>realtime-analytics</finalName>
          <appendAssemblyId>false</appendAssemblyId>
        </configuration>
        <executions>
          <execution>
            <id>make-assembly</id>
            <phase>package</phase>
            <goals>
              <goal>single</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
```

**Step 2: Commit**

```bash
git add realtime-analytics/java/pom.xml
git commit -m "feat(realtime-analytics): add pom.xml"
```

---

### Task 8: Java — RealtimeAnalytics.java

**Files:**
- Create: `realtime-analytics/java/src/main/java/com/arcadedb/examples/RealtimeAnalytics.java`

**Step 1: Write RealtimeAnalytics.java**

Follow the exact pattern from `RecommendationEngine.java`: `tryRun()` wrapper, `printHeader()`, `RemoteDatabase`, all 6 queries.

```java
package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class RealtimeAnalytics {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "RealtimeAnalytics";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1HourlyBucketing(db), "Query 1");
      tryRun(() -> runQuery2ServiceRate(db), "Query 2");
      tryRun(() -> runQuery3Interpolation(db), "Query 3");
      tryRun(() -> runQuery4GraphTimeSeries(db), "Query 4");
      tryRun(() -> runQuery5ImpactAnalysis(db), "Query 5");
      tryRun(() -> runQuery6ContinuousAggregate(db), "Query 6");
    }
    System.out.println("\nAll queries complete.");
  }

  private static void tryRun(Runnable r, String name) {
    try {
      r.run();
    } catch (Exception e) {
      System.err.println("[" + name + " FAILED] " + e.getMessage());
    }
  }

  // Query 1: Hourly Temperature Bucketing
  private static void runQuery1HourlyBucketing(RemoteDatabase db) {
    printHeader("Query 1: Hourly Temperature Bucketing",
        "Aggregate sensor s-A readings into 1-hour buckets.");

    String sql = """
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
        ORDER BY hour""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | sensor: %s | avg: %.1f | max: %.1f | p99: %s | samples: %s%n",
            r.getProperty("hour"),
            r.getProperty("sensor_id"),
            ((Number) r.getProperty("avg_temp")).doubleValue(),
            ((Number) r.getProperty("max_temp")).doubleValue(),
            r.getProperty("p99_temp"),
            r.getProperty("samples"));
      }
    }
  }

  // Query 2: Service Request Rate & Latency
  private static void runQuery2ServiceRate(RemoteDatabase db) {
    printHeader("Query 2: Service Request Rate & Latency",
        "5-minute windowed rate and p99 latency per service.");

    String sql = """
        SELECT
          time_bucket('5m', ts) AS window,
          service_id,
          rate(request_count) AS requests_per_sec,
          percentile(latency_ms, 0.99) AS p99_latency
        FROM ServiceMetrics
        WHERE ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
        GROUP BY window, service_id""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | %-25s | rps: %s | p99: %s ms%n",
            r.getProperty("window"),
            r.getProperty("service_id"),
            r.getProperty("requests_per_sec"),
            r.getProperty("p99_latency"));
      }
    }
  }

  // Query 3: Gap Filling with Interpolation
  private static void runQuery3Interpolation(RemoteDatabase db) {
    printHeader("Query 3: Gap Filling with Interpolation",
        "Fill missing temperature readings for sensor s-C.");

    String sql = """
        SELECT
          time_bucket('1m', ts) AS minute,
          interpolate(temperature, 'linear', ts) AS temp_filled
        FROM SensorReading
        WHERE sensor_id = 's-C'
          AND ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T11:30:00Z'
        GROUP BY minute""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | temp: %s%n",
            r.getProperty("minute"),
            r.getProperty("temp_filled"));
      }
    }
  }

  // Query 4: Graph + Time-Series Correlation
  private static void runQuery4GraphTimeSeries(RemoteDatabase db) {
    printHeader("Query 4: Graph + Time-Series Correlation",
        "Traverse HQ building topology, join sensors to their readings.");

    String sql = """
        SELECT
          sensor.name,
          avg(ts.temperature) AS avg_temp,
          max(ts.temperature) AS max_temp,
          count(*) AS samples
        FROM (
          TRAVERSE out('HAS_FLOOR').out('INSTALLED_IN')
          FROM (SELECT FROM Building WHERE name = 'HQ')
          WHILE $depth <= 2
        ) AS sensor
        WHERE sensor.@type = 'Sensor'
          AND ts.ts BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
        TIMESERIES sensor -> SensorReading AS ts
        GROUP BY sensor.name""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | avg: %.1f | max: %.1f | samples: %s%n",
            r.getProperty("sensor.name"),
            ((Number) r.getProperty("avg_temp")).doubleValue(),
            ((Number) r.getProperty("max_temp")).doubleValue(),
            r.getProperty("samples"));
      }
    }
  }

  // Query 5: Service Impact Analysis (Cypher)
  private static void runQuery5ImpactAnalysis(RemoteDatabase db) {
    printHeader("Query 5: Service Impact Analysis (Cypher)",
        "Find services affected by srv-1 failure with live metrics.");

    String cypher = """
        MATCH (failing:Server {server_id: 'srv-1'})
          <-[:RUNS_ON]-(svc:Service)
        RETURN svc.name,
          ts.rate(svc, 'ServiceMetrics', 'request_count',
            datetime('2026-02-20T09:50:00Z'), datetime('2026-02-20T10:10:00Z')) AS current_rps,
          ts.last(svc, 'ServiceMetrics', 'error_count') AS errors""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | rps: %s | errors: %s%n",
            r.getProperty("svc.name"),
            r.getProperty("current_rps"),
            r.getProperty("errors"));
      }
    }
  }

  // Query 6: Continuous Aggregate
  private static void runQuery6ContinuousAggregate(RemoteDatabase db) {
    printHeader("Query 6: Continuous Aggregate",
        "Query pre-computed hourly temperature rollup.");

    String sql = """
        SELECT *
        FROM hourly_sensor_temps
        WHERE hour BETWEEN '2026-02-20T10:00:00Z' AND '2026-02-20T12:00:00Z'
        ORDER BY hour, sensor_id""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | %-5s | avg: %s | max: %s | min: %s%n",
            r.getProperty("hour"),
            r.getProperty("sensor_id"),
            r.getProperty("avg_temp"),
            r.getProperty("max_temp"),
            r.getProperty("min_temp"));
      }
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }
}
```

**Step 2: Verify it compiles**

Run:
```bash
cd realtime-analytics/java
mvn package --no-transfer-progress
```
Expected: BUILD SUCCESS, `target/realtime-analytics.jar` produced.

**Step 3: Test end-to-end**

Run (with ArcadeDB + setup already done from Task 5):
```bash
java -jar target/realtime-analytics.jar
```
Expected: all 6 queries print headers and results. Same caveats as Task 6 Step 3 apply — adjust query syntax if needed.

**Step 4: Commit**

```bash
git add realtime-analytics/java/src/main/java/com/arcadedb/examples/RealtimeAnalytics.java
git commit -m "feat(realtime-analytics): add Java program"
```

---

### Task 9: README

**Files:**
- Create: `realtime-analytics/README.md`

**Step 1: Write README.md**

Follow the same structure as `recommendation-engine/README.md`.

```markdown
# Realtime Analytics

Demonstrates ArcadeDB's native time-series engine combined with graph traversal,
showing how a single database replaces a fragmented stack of specialized tools
for unified operational analytics.

- **Time-series analytics** — time bucketing, rate of change, percentiles, interpolation
- **Graph traversal** — building topology and service dependency analysis
- **Multi-model correlation** — graph + time-series joins in a single query

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demo)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `RealtimeAnalytics` database, applies the schema, inserts
sample data, and creates continuous aggregates.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/realtime-analytics.jar
```

## Schema

### Time-Series Types

| Type | Tags | Fields |
|------|------|--------|
| `SensorReading` | `sensor_id`, `location`, `floor` | `temperature`, `humidity`, `pressure` |
| `ServiceMetrics` | `service_id`, `server_id` | `request_count`, `error_count`, `latency_ms` |

### Graph Types

| Type | Kind | Key properties |
|------|------|----------------|
| `Building` | Vertex | `name` |
| `Floor` | Vertex | `name`, `level` |
| `Sensor` | Vertex | `name`, `sensor_id` |
| `Server` | Vertex | `name`, `server_id` |
| `Service` | Vertex | `name`, `service_id` |
| `HAS_FLOOR` | Edge | Building -> Floor |
| `INSTALLED_IN` | Edge | Sensor -> Floor |
| `RUNS_ON` | Edge | Service -> Server |
| `DEPENDS_ON` | Edge | Service -> Service |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Hourly Temperature Bucketing | SQL | Time-series |
| 2 | Service Request Rate & Latency | SQL | Time-series |
| 3 | Gap Filling with Interpolation | SQL | Time-series |
| 4 | Graph + Time-Series Correlation | SQL | Graph + Time-series |
| 5 | Service Impact Analysis | Cypher | Graph + Time-series |
| 6 | Continuous Aggregate Query | SQL | Time-series (materialized) |

## Sample Data

- 2 buildings (HQ, Data Center) with 4 floors
- 6 sensors across both buildings
- 3 servers and 5 services with dependency chain
- ~20 sensor readings over a 2-hour window (sensor s-C has a deliberate gap)
- ~15 service metrics with varying load and error rates

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.1**. Time-series queries use native
`time_bucket()`, `rate()`, `percentile()`, and `interpolate()` functions.
Graph and time-series data are correlated via the `TIMESERIES ... AS` join syntax.

## Reference

[ArcadeDB Realtime Analytics use case](https://arcadedb.com/realtime-analytics.html)
```

**Step 2: Commit**

```bash
git add realtime-analytics/README.md
git commit -m "docs(realtime-analytics): add README"
```

---

### Task 10: CI Workflow

**Files:**
- Create: `.github/workflows/realtime-analytics.yml`

**Step 1: Write the workflow**

Copy from `recommendation-engine.yml`, change 5 values: name, paths, cache key hash path, working-directory references, and JAR filename.

```yaml
name: Realtime Analytics CI

on:
  push:
    paths:
      - realtime-analytics/**
      - .github/workflows/realtime-analytics.yml
  pull_request:
    paths:
      - realtime-analytics/**
      - .github/workflows/realtime-analytics.yml

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    strategy:
      fail-fast: false
      matrix:
        runner: [curl, java]

    env:
      ARCADEDB_URL: http://localhost:2480
      ARCADEDB_USER: root
      ARCADEDB_PASS: arcadedb

    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 1

      - name: Set up Java
        if: matrix.runner == 'java'
        uses: actions/setup-java@be666c2fcd27ec809703dec50e508c2fdc7f6654 # v5.2.0
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache Maven repository
        if: matrix.runner == 'java'
        uses: actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('realtime-analytics/java/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2-

      - name: Start ArcadeDB
        working-directory: realtime-analytics
        run: docker compose up -d

      - name: Setup database
        working-directory: realtime-analytics
        run: ./setup.sh

      - name: Run curl queries
        if: matrix.runner == 'curl'
        working-directory: realtime-analytics
        run: ./queries/queries.sh

      - name: Build and run Java
        if: matrix.runner == 'java'
        working-directory: realtime-analytics/java
        run: |
          mvn package --no-transfer-progress
          java -jar target/realtime-analytics.jar

      - name: Teardown
        if: always()
        working-directory: realtime-analytics
        run: docker compose down
```

**Step 2: Commit**

```bash
git add .github/workflows/realtime-analytics.yml
git commit -m "ci: add realtime-analytics workflow"
```

---

### Task 11: Update Root README

**Files:**
- Modify: `README.md` (root)

**Step 1: Add realtime-analytics row to the use cases table**

Add after the fraud-detection row:

```markdown
| [realtime-analytics](./realtime-analytics/) | Unified IoT and service monitoring platform | Time-series, Graph traversal, Cypher |
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add realtime-analytics to root README"
```

---

### Task 12: Update dependabot.yml

**Files:**
- Modify: `.github/dependabot.yml`

**Step 1: Add realtime-analytics Maven and Docker entries**

Check the existing file for the pattern used by other use cases and add equivalent entries for `realtime-analytics/java` (maven) and `realtime-analytics` (docker).

**Step 2: Commit**

```bash
git add .github/dependabot.yml
git commit -m "chore: add realtime-analytics to dependabot"
```

---

### Task 13: End-to-End Verification

**Step 1: Clean start**

```bash
cd realtime-analytics
docker compose down -v 2>/dev/null || true
docker compose up -d
./setup.sh
```

**Step 2: Run curl queries**

```bash
./queries/queries.sh
```
Expected: all 6 queries return non-empty results.

**Step 3: Run Java**

```bash
cd java
mvn package -q
java -jar target/realtime-analytics.jar
```
Expected: all 6 queries print headers and results, ending with "All queries complete."

**Step 4: Teardown**

```bash
cd ..
docker compose down
```

**Step 5: Final commit (if any fixes were needed)**

```bash
git add -A
git commit -m "fix(realtime-analytics): adjustments from end-to-end testing"
```
