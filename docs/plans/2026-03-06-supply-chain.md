# Supply Chain Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a fully self-contained `supply-chain/` directory demonstrating ArcadeDB's multi-model capabilities for supply chain management (graph traversal with variable-length paths, vector similarity, time-series aggregation) via five query patterns, runnable with `curl`, a Java program, and a JavaScript program (PostgreSQL wire protocol).

**Architecture:** Self-contained directory per the design doc. Docker Compose brings up ArcadeDB 26.3.1 with HTTP + PostgreSQL protocol. A `setup.sh` creates the database and applies SQL files. Five queries are demonstrated via `queries/queries.sh` (curl), `java/` (Maven fat JAR using `arcadedb-network`), and `js/` (Node.js using `pg` driver).

**Tech Stack:** ArcadeDB 26.3.1, Docker Compose, Maven 3.x, Java 21, `com.arcadedb:arcadedb-network:26.3.1`, Node.js, `pg` (node-postgres), `jq` (for setup script)

---

### Task 1: Scaffold the directory structure

**Files:**
- Create: `supply-chain/` and all subdirectories

**Step 1: Create all directories**

```bash
mkdir -p supply-chain/sql
mkdir -p supply-chain/queries
mkdir -p supply-chain/java/src/main/java/com/arcadedb/examples
mkdir -p supply-chain/js
```

**Step 2: Verify**

```bash
find supply-chain -type d
```

---

### Task 2: Write docker-compose.yml

**Files:**
- Create: `supply-chain/docker-compose.yml`

**Step 1: Write the file**

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.3.1
    ports:
      - "2480:2480"
      - "5432:5432"
    environment:
      JAVA_OPTS: >-
        -Darcadedb.server.rootPassword=arcadedb
        -Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:2480/api/v1/ready"]
      interval: 5s
      timeout: 3s
      retries: 20
      start_period: 10s
```

**Step 2: Verify the container starts**

```bash
cd supply-chain
docker compose up -d
docker compose ps   # wait for healthy
```

**Step 3: Verify both HTTP and PostgreSQL ports**

```bash
curl -sf -u root:arcadedb http://localhost:2480/api/v1/ready
```

---

### Task 3: Write the SQL schema

**Files:**
- Create: `supply-chain/sql/01-schema.sql`

**Step 1: Write the schema file**

One statement per line. Seven vertex types, seven edge types, one document type, two indexes.

```sql
-- Vertex types
CREATE VERTEX TYPE Supplier IF NOT EXISTS;
CREATE PROPERTY Supplier.name IF NOT EXISTS STRING;
CREATE PROPERTY Supplier.country IF NOT EXISTS STRING;
CREATE PROPERTY Supplier.risk_score IF NOT EXISTS FLOAT;
CREATE PROPERTY Supplier.lead_time_avg IF NOT EXISTS INTEGER;
CREATE PROPERTY Supplier.quality_score IF NOT EXISTS FLOAT;
CREATE PROPERTY Supplier.certifications IF NOT EXISTS STRING;
CREATE PROPERTY Supplier.status IF NOT EXISTS STRING;
CREATE PROPERTY Supplier.capability_vec IF NOT EXISTS LIST;
CREATE INDEX IF NOT EXISTS ON Supplier (name) UNIQUE;
CREATE VERTEX TYPE Component IF NOT EXISTS;
CREATE PROPERTY Component.name IF NOT EXISTS STRING;
CREATE INDEX IF NOT EXISTS ON Component (name) UNIQUE;
CREATE VERTEX TYPE Product IF NOT EXISTS;
CREATE PROPERTY Product.sku IF NOT EXISTS STRING;
CREATE PROPERTY Product.name IF NOT EXISTS STRING;
CREATE PROPERTY Product.revenue_annual IF NOT EXISTS FLOAT;
CREATE PROPERTY Product.batch IF NOT EXISTS STRING;
CREATE INDEX IF NOT EXISTS ON Product (sku) UNIQUE;
CREATE VERTEX TYPE Warehouse IF NOT EXISTS;
CREATE PROPERTY Warehouse.name IF NOT EXISTS STRING;
CREATE PROPERTY Warehouse.stock_weeks IF NOT EXISTS INTEGER;
CREATE VERTEX TYPE Customer IF NOT EXISTS;
CREATE PROPERTY Customer.customerId IF NOT EXISTS STRING;
CREATE PROPERTY Customer.contact_email IF NOT EXISTS STRING;
CREATE INDEX IF NOT EXISTS ON Customer (customerId) UNIQUE;
CREATE VERTEX TYPE ShippingRoute IF NOT EXISTS;
CREATE PROPERTY ShippingRoute.name IF NOT EXISTS STRING;
CREATE PROPERTY ShippingRoute.transit_days IF NOT EXISTS INTEGER;
CREATE PROPERTY ShippingRoute.cost IF NOT EXISTS FLOAT;
CREATE VERTEX TYPE RawMaterial IF NOT EXISTS;
CREATE PROPERTY RawMaterial.name IF NOT EXISTS STRING;
CREATE PROPERTY RawMaterial.origin IF NOT EXISTS STRING;
CREATE PROPERTY RawMaterial.certification IF NOT EXISTS STRING;
CREATE PROPERTY RawMaterial.lot IF NOT EXISTS STRING;
-- Edge types
CREATE EDGE TYPE SUPPLIES IF NOT EXISTS;
CREATE EDGE TYPE CONTAINS IF NOT EXISTS;
CREATE EDGE TYPE STORED_AT IF NOT EXISTS;
CREATE EDGE TYPE SHIPS_VIA IF NOT EXISTS;
CREATE EDGE TYPE SHIPPED_TO IF NOT EXISTS;
CREATE EDGE TYPE ALTERNATIVE_FOR IF NOT EXISTS;
CREATE EDGE TYPE ASSEMBLED_FROM IF NOT EXISTS;
-- Document type for time-series delivery metrics
CREATE DOCUMENT TYPE DeliveryMetric IF NOT EXISTS;
CREATE PROPERTY DeliveryMetric.supplierId IF NOT EXISTS STRING;
CREATE PROPERTY DeliveryMetric.lead_time_hrs IF NOT EXISTS FLOAT;
CREATE PROPERTY DeliveryMetric.on_time IF NOT EXISTS BOOLEAN;
CREATE PROPERTY DeliveryMetric.delayed IF NOT EXISTS BOOLEAN;
CREATE PROPERTY DeliveryMetric.quantity IF NOT EXISTS INTEGER;
CREATE PROPERTY DeliveryMetric.recordedAt IF NOT EXISTS DATETIME;
-- Vector index for supplier capability similarity
CREATE INDEX IF NOT EXISTS ON Supplier (capability_vec) LSM_VECTOR METADATA { dimensions: 4, similarity: 'COSINE' };
```

---

### Task 4: Write the sample data

**Files:**
- Create: `supply-chain/sql/02-data.sql`

**Step 1: Write the data file**

All INSERTs and CREATE EDGE statements, one per line. Embeddings are 4-dimensional: [electronics, sensors, materials, logistics].

```sql
-- Suppliers
INSERT INTO Supplier SET name = 'Shenzhen Micro Ltd', country = 'China', risk_score = 0.7, lead_time_avg = 14, quality_score = 0.85, certifications = 'ISO-9001', status = 'active', capability_vec = [0.9, 0.2, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Taiwan Semi Corp', country = 'Taiwan', risk_score = 0.3, lead_time_avg = 10, quality_score = 0.95, certifications = 'ISO-9001,ISO-14001', status = 'active', capability_vec = [0.8, 0.1, 0.3, 0.1];
INSERT INTO Supplier SET name = 'Seoul Chip Inc', country = 'South Korea', risk_score = 0.4, lead_time_avg = 12, quality_score = 0.90, certifications = 'ISO-9001', status = 'active', capability_vec = [0.85, 0.15, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Berlin Sensors GmbH', country = 'Germany', risk_score = 0.2, lead_time_avg = 8, quality_score = 0.98, certifications = 'ISO-9001,RoHS', status = 'active', capability_vec = [0.2, 0.9, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Sao Paulo Materials', country = 'Brazil', risk_score = 0.5, lead_time_avg = 21, quality_score = 0.80, certifications = 'ISO-14001', status = 'active', capability_vec = [0.1, 0.1, 0.9, 0.1];
INSERT INTO Supplier SET name = 'Tokyo Electronics', country = 'Japan', risk_score = 0.15, lead_time_avg = 7, quality_score = 0.97, certifications = 'ISO-9001,ISO-14001,RoHS', status = 'active', capability_vec = [0.85, 0.3, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Mumbai Parts Ltd', country = 'India', risk_score = 0.45, lead_time_avg = 16, quality_score = 0.82, certifications = 'ISO-9001', status = 'active', capability_vec = [0.7, 0.1, 0.3, 0.2];
-- Components
INSERT INTO Component SET name = 'Microcontroller';
INSERT INTO Component SET name = 'Sensor Module';
INSERT INTO Component SET name = 'Circuit Board';
INSERT INTO Component SET name = 'Display Panel';
INSERT INTO Component SET name = 'Battery Pack';
-- Products
INSERT INTO Product SET sku = 'WIDGET-PRO-X', name = 'Widget Pro X', revenue_annual = 2500000.00, batchId = 'BATCH-2026-0218';
INSERT INTO Product SET sku = 'WIDGET-LITE', name = 'Widget Lite', revenue_annual = 800000.00, batchId = 'BATCH-2026-0301';
INSERT INTO Product SET sku = 'SENSOR-HUB-1', name = 'Sensor Hub', revenue_annual = 1200000.00, batchId = 'BATCH-2026-0115';
-- Warehouses
INSERT INTO Warehouse SET name = 'US-East', stock_weeks = 6;
INSERT INTO Warehouse SET name = 'EU-Central', stock_weeks = 4;
INSERT INTO Warehouse SET name = 'APAC-South', stock_weeks = 3;
-- Customers
INSERT INTO Customer SET customerId = 'CUST-001', contact_email = 'ops@acmecorp.com';
INSERT INTO Customer SET customerId = 'CUST-002', contact_email = 'procurement@globex.com';
INSERT INTO Customer SET customerId = 'CUST-003', contact_email = 'supply@initech.com';
-- Shipping Routes
INSERT INTO ShippingRoute SET name = 'US-Express', transit_days = 3, cost = 450.00;
INSERT INTO ShippingRoute SET name = 'EU-Standard', transit_days = 7, cost = 200.00;
INSERT INTO ShippingRoute SET name = 'APAC-Freight', transit_days = 14, cost = 150.00;
-- Raw Materials
INSERT INTO RawMaterial SET name = 'Silicon Wafer', origin = 'Taiwan', certification = 'ISO-9001', lot = 'LOT-2026-001';
INSERT INTO RawMaterial SET name = 'Copper Wire', origin = 'Chile', certification = 'RoHS', lot = 'LOT-2026-002';
INSERT INTO RawMaterial SET name = 'Lithium', origin = 'Australia', certification = 'ISO-14001', lot = 'LOT-2026-003';
INSERT INTO RawMaterial SET name = 'Glass Substrate', origin = 'Japan', certification = 'ISO-9001', lot = 'LOT-2026-004';
INSERT INTO RawMaterial SET name = 'Rare Earth Elements', origin = 'China', certification = 'REACH', lot = 'LOT-2026-005';
-- SUPPLIES edges (multi-tier supply chain)
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Sao Paulo Materials') TO (SELECT FROM Supplier WHERE name = 'Taiwan Semi Corp');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Taiwan Semi Corp') TO (SELECT FROM Supplier WHERE name = 'Shenzhen Micro Ltd');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Seoul Chip Inc') TO (SELECT FROM Supplier WHERE name = 'Shenzhen Micro Ltd');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Shenzhen Micro Ltd') TO (SELECT FROM Component WHERE name = 'Microcontroller');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Berlin Sensors GmbH') TO (SELECT FROM Component WHERE name = 'Sensor Module');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Mumbai Parts Ltd') TO (SELECT FROM Component WHERE name = 'Circuit Board');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Tokyo Electronics') TO (SELECT FROM Component WHERE name = 'Display Panel');
-- ALTERNATIVE_FOR edges
CREATE EDGE ALTERNATIVE_FOR FROM (SELECT FROM Supplier WHERE name = 'Tokyo Electronics') TO (SELECT FROM Component WHERE name = 'Microcontroller');
CREATE EDGE ALTERNATIVE_FOR FROM (SELECT FROM Supplier WHERE name = 'Seoul Chip Inc') TO (SELECT FROM Component WHERE name = 'Circuit Board');
-- CONTAINS edges (bill of materials)
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Circuit Board') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Display Panel') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Battery Pack') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
CREATE EDGE CONTAINS FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
-- ASSEMBLED_FROM edges (traceability chain: RawMaterial → Component → Product)
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Silicon Wafer') TO (SELECT FROM Component WHERE name = 'Microcontroller');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Copper Wire') TO (SELECT FROM Component WHERE name = 'Circuit Board');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Rare Earth Elements') TO (SELECT FROM Component WHERE name = 'Sensor Module');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Glass Substrate') TO (SELECT FROM Component WHERE name = 'Display Panel');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Lithium') TO (SELECT FROM Component WHERE name = 'Battery Pack');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Circuit Board') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Display Panel') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Battery Pack') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
-- STORED_AT edges
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Warehouse WHERE name = 'US-East');
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Warehouse WHERE name = 'EU-Central');
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'WIDGET-LITE') TO (SELECT FROM Warehouse WHERE name = 'EU-Central');
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1') TO (SELECT FROM Warehouse WHERE name = 'APAC-South');
-- SHIPS_VIA edges
CREATE EDGE SHIPS_VIA FROM (SELECT FROM Warehouse WHERE name = 'US-East') TO (SELECT FROM ShippingRoute WHERE name = 'US-Express');
CREATE EDGE SHIPS_VIA FROM (SELECT FROM Warehouse WHERE name = 'EU-Central') TO (SELECT FROM ShippingRoute WHERE name = 'EU-Standard');
CREATE EDGE SHIPS_VIA FROM (SELECT FROM Warehouse WHERE name = 'APAC-South') TO (SELECT FROM ShippingRoute WHERE name = 'APAC-Freight');
-- SHIPPED_TO edges
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Customer WHERE customerId = 'CUST-001');
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'WIDGET-LITE') TO (SELECT FROM Customer WHERE customerId = 'CUST-002');
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1') TO (SELECT FROM Customer WHERE customerId = 'CUST-003');
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Customer WHERE customerId = 'CUST-003');
-- DeliveryMetric documents (time-series delivery data)
INSERT INTO DeliveryMetric SET supplierId = 'Shenzhen Micro Ltd', lead_time_hrs = 336, on_time = true, delayed = false, quantity = 500, recordedAt = '2026-01-15 08:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Shenzhen Micro Ltd', lead_time_hrs = 400, on_time = false, delayed = true, quantity = 300, recordedAt = '2026-02-01 10:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Shenzhen Micro Ltd', lead_time_hrs = 360, on_time = true, delayed = false, quantity = 450, recordedAt = '2026-02-20 09:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Taiwan Semi Corp', lead_time_hrs = 240, on_time = true, delayed = false, quantity = 1000, recordedAt = '2026-01-10 07:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Taiwan Semi Corp', lead_time_hrs = 250, on_time = true, delayed = false, quantity = 800, recordedAt = '2026-02-05 11:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Berlin Sensors GmbH', lead_time_hrs = 192, on_time = true, delayed = false, quantity = 200, recordedAt = '2026-01-20 06:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Berlin Sensors GmbH', lead_time_hrs = 200, on_time = true, delayed = false, quantity = 250, recordedAt = '2026-02-15 08:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Mumbai Parts Ltd', lead_time_hrs = 420, on_time = false, delayed = true, quantity = 600, recordedAt = '2026-01-25 09:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Mumbai Parts Ltd', lead_time_hrs = 384, on_time = true, delayed = false, quantity = 550, recordedAt = '2026-02-10 10:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Mumbai Parts Ltd', lead_time_hrs = 450, on_time = false, delayed = true, quantity = 400, recordedAt = '2026-03-01 07:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Tokyo Electronics', lead_time_hrs = 168, on_time = true, delayed = false, quantity = 350, recordedAt = '2026-01-18 08:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Tokyo Electronics', lead_time_hrs = 175, on_time = true, delayed = false, quantity = 400, recordedAt = '2026-02-22 09:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Seoul Chip Inc', lead_time_hrs = 288, on_time = true, delayed = false, quantity = 700, recordedAt = '2026-01-30 10:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Seoul Chip Inc', lead_time_hrs = 310, on_time = false, delayed = true, quantity = 650, recordedAt = '2026-02-25 11:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Sao Paulo Materials', lead_time_hrs = 504, on_time = false, delayed = true, quantity = 2000, recordedAt = '2026-02-01 06:00:00';
```

---

### Task 5: Write setup.sh

**Files:**
- Create: `supply-chain/setup.sh`

Copy the same pattern from recommendation-engine, changing `DB_NAME` to `SupplyChain`.

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="SupplyChain"

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

echo ""
echo "Setup complete. ${DB_NAME} is ready."
```

Make executable: `chmod +x supply-chain/setup.sh`

---

### Task 6: Write queries/queries.sh

**Files:**
- Create: `supply-chain/queries/queries.sh`

Five labeled sections using the `query()` helper. Mix of SQL and Cypher.

```bash
#!/usr/bin/env bash
# Supply Chain Management — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="SupplyChain"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Multi-Tier Supplier Discovery ==="
echo "Find all suppliers (up to 4 tiers) feeding into Widget Pro X."
echo ""
query "cypher" "
MATCH (p:Product {sku: 'WIDGET-PRO-X'})
      <-[:CONTAINS]-(c:Component)
      <-[:SUPPLIES*1..4]-(s:Supplier)
RETURN DISTINCT s.name, s.country, s.risk_score
ORDER BY s.risk_score DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Blast Radius Analysis ==="
echo "If Shenzhen Micro Ltd is disrupted, which products are affected?"
echo ""
query "cypher" "
MATCH (s:Supplier {name: 'Shenzhen Micro Ltd'})
      -[:SUPPLIES]->(c:Component)
      -[:CONTAINS]->(p:Product)
OPTIONAL MATCH (c)<-[:ALTERNATIVE_FOR]-(alt:Supplier)
RETURN c.name AS component, p.name AS product, collect(alt.name) AS alternatives
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Delivery Disruption Detection ==="
echo "Identify suppliers with delivery issues from DeliveryMetric records."
echo ""
query "sql" "
SELECT supplierId,
       avg(lead_time_hrs) AS avg_lead_time,
       sum(CASE WHEN delayed = true THEN 1 ELSE 0 END) AS total_delayed,
       count(*) AS total_deliveries
FROM DeliveryMetric
GROUP BY supplierId
ORDER BY total_delayed DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Vector-Based Alternative Sourcing ==="
echo "Find suppliers with capabilities similar to Shenzhen Micro Ltd [0.9, 0.2, 0.1, 0.1]."
echo ""
query "sql" "
SELECT name, country, risk_score
FROM Supplier
WHERE status = 'active'
ORDER BY vectorNeighbors('Supplier[capability_vec]', [0.9, 0.2, 0.1, 0.1], 10) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: End-to-End Batch Traceability ==="
echo "Trace all raw materials in batch BATCH-2026-0218 through the assembly chain."
echo ""
query "cypher" "
MATCH (p:Product {batchId: 'BATCH-2026-0218'})
      <-[:ASSEMBLED_FROM*1..8]-(material)
RETURN material.name, material.origin, material.certification, material.lot
"
```

Make executable: `chmod +x supply-chain/queries/queries.sh`

**Expected results:**
- Query 1: Shenzhen Micro Ltd, Taiwan Semi Corp, Seoul Chip Inc, Sao Paulo Materials, Berlin Sensors GmbH, Mumbai Parts Ltd (all suppliers in the Widget Pro X supply chain)
- Query 2: Microcontroller → Widget Pro X (alternative: Tokyo Electronics), and other component/product pairs
- Query 3: Mumbai Parts Ltd and Shenzhen Micro Ltd near the top (most delays)
- Query 4: Suppliers ranked by similarity to Shenzhen Micro's capability vector
- Query 5: Silicon Wafer, Copper Wire, Rare Earth Elements (raw materials for BATCH-2026-0218), plus intermediate Components

---

### Task 7: Write java/pom.xml

**Files:**
- Create: `supply-chain/java/pom.xml`

Same pattern as recommendation-engine, changing artifactId/finalName/mainClass.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.arcadedb.examples</groupId>
  <artifactId>supply-chain</artifactId>
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
              <mainClass>com.arcadedb.examples.SupplyChain</mainClass>
            </manifest>
          </archive>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <finalName>supply-chain</finalName>
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

---

### Task 8: Write SupplyChain.java

**Files:**
- Create: `supply-chain/java/src/main/java/com/arcadedb/examples/SupplyChain.java`

Same `tryRun()`/`printHeader()` pattern as RecommendationEngine.java. Five query methods using the same SQL/Cypher as queries.sh.

Key methods:
- `runQuery1MultiTierDiscovery(db)` — Cypher variable-length path
- `runQuery2BlastRadius(db)` — Cypher with OPTIONAL MATCH
- `runQuery3DisruptionDetection(db)` — SQL aggregation
- `runQuery4AlternativeSourcing(db)` — SQL vectorNeighbors
- `runQuery5Traceability(db)` — Cypher variable-length path

Each method: `printHeader()`, build query string, `db.query(lang, query)`, iterate ResultSet, `System.out.printf()`.

---

### Task 9: Write js/package.json and js/supply-chain.js

**Files:**
- Create: `supply-chain/js/package.json`
- Create: `supply-chain/js/supply-chain.js`

**package.json:**
```json
{
  "name": "supply-chain",
  "version": "1.0.0",
  "private": true,
  "description": "ArcadeDB Supply Chain queries via PostgreSQL protocol",
  "main": "supply-chain.js",
  "dependencies": {
    "pg": "^8.13.0"
  }
}
```

**supply-chain.js:**
- CommonJS (`require('pg')`)
- Config from env vars: `ARCADEDB_HOST`, `ARCADEDB_PG_PORT` (default 5432), `ARCADEDB_USER`, `ARCADEDB_PASS`
- All 5 queries in ArcadeDB SQL (Cypher queries rewritten as SQL MATCH for Postgres protocol compatibility)
- Same `tryRun(fn, name)` and `printHeader(title, desc)` pattern
- `async/await` throughout
- Formatted table output with `console.log()`

**SQL MATCH equivalents for JS:**

Query 1 (multi-tier discovery) in SQL MATCH:
```sql
SELECT s.name, s.country, s.risk_score
FROM (
  MATCH {type: Product, where: (sku = 'WIDGET-PRO-X')}
        .in('CONTAINS'){as: c}
        .in('SUPPLIES'){as: s, while: ($depth < 4)}
  RETURN DISTINCT s.name AS name, s.country AS country, s.risk_score AS risk_score
)
ORDER BY risk_score DESC
```

Query 2 (blast radius) — split into two SQL queries (no OPTIONAL MATCH in SQL MATCH):
```sql
-- Part A: affected products
SELECT c.name AS component, p.name AS product
FROM (
  MATCH {type: Supplier, where: (name = 'Shenzhen Micro Ltd')}
        .out('SUPPLIES'){as: c}
        .out('CONTAINS'){as: p}
  RETURN c.name AS component, p.name AS product
)
-- Part B: alternatives per component
SELECT alt.name AS alternative, c.name AS component
FROM (
  MATCH {type: Supplier, where: (name = 'Shenzhen Micro Ltd')}
        .out('SUPPLIES'){as: c}
        .in('ALTERNATIVE_FOR'){as: alt}
  RETURN alt.name AS alternative, c.name AS component
)
```

Query 5 (traceability) in SQL MATCH:
```sql
SELECT name, origin, certification, lot
FROM (
  MATCH {type: Product, where: (batchId = 'BATCH-2026-0218')}
        .in('ASSEMBLED_FROM'){as: material, while: ($depth < 8)}
  RETURN material.name AS name, material.origin AS origin,
         material.certification AS certification, material.lot AS lot
)
```

Queries 3 and 4 are identical to the shell/Java versions (pure SQL).

---

### Task 10: Build and run all three runners

**Step 1: Start ArcadeDB and load data**
```bash
cd supply-chain
docker compose up -d
./setup.sh
```

**Step 2: Run shell queries**
```bash
./queries/queries.sh
```

**Step 3: Build and run Java**
```bash
cd java
mvn package -q
java -jar target/supply-chain.jar
```

**Step 4: Install and run JavaScript**
```bash
cd ../js
npm install
node supply-chain.js
```

**Step 5: If any query fails, note the error and adjust:**
- If Cypher variable-length paths (`*1..4`) don't work: rewrite as SQL MATCH with `while: ($depth < 4)`
- If OPTIONAL MATCH fails: split into two queries
- If `vectorNeighbors` syntax differs: adjust index name format
- If Postgres protocol doesn't accept SQL MATCH: use HTTP API via `fetch` instead of `pg`

---

### Task 11: Write README.md

**Files:**
- Create: `supply-chain/README.md`

Follow the recommendation-engine README format. Sections:
- Overview (3 bullet points: graph traversal, vector similarity, time-series)
- Prerequisites (Docker, curl, jq, Java 21+, Maven, Node.js)
- Quickstart (docker compose up, setup.sh, 3a/3b/3c for curl/java/js)
- Schema table (7 vertex + 7 edge + 1 document)
- Query Patterns table (5 rows)
- Sample Data summary
- ArcadeDB Version Notes
- Reference link

---

### Task 12: Write CI workflow

**Files:**
- Create: `.github/workflows/supply-chain.yml`

Same pattern as recommendation-engine.yml, with matrix expanded to `[curl, java, js]`.

```yaml
name: Supply Chain CI

on:
  push:
    paths:
      - supply-chain/**
      - .github/workflows/supply-chain.yml
  pull_request:
    paths:
      - supply-chain/**
      - .github/workflows/supply-chain.yml

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    strategy:
      fail-fast: false
      matrix:
        runner: [curl, java, js]

    env:
      ARCADEDB_URL: http://localhost:2480
      ARCADEDB_USER: root
      ARCADEDB_PASS: arcadedb

    steps:
      - name: Checkout
        uses: actions/checkout@<pinned-sha>
        with:
          fetch-depth: 1

      - name: Set up Java
        if: matrix.runner == 'java'
        uses: actions/setup-java@<pinned-sha>
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Cache Maven repository
        if: matrix.runner == 'java'
        uses: actions/cache@<pinned-sha>
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('supply-chain/java/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2-

      - name: Set up Node.js
        if: matrix.runner == 'js'
        uses: actions/setup-node@<pinned-sha>
        with:
          node-version: '22'

      - name: Install JS dependencies
        if: matrix.runner == 'js'
        working-directory: supply-chain/js
        run: npm install

      - name: Start ArcadeDB
        working-directory: supply-chain
        run: docker compose up -d

      - name: Setup database
        working-directory: supply-chain
        run: ./setup.sh

      - name: Run curl queries
        if: matrix.runner == 'curl'
        working-directory: supply-chain
        run: ./queries/queries.sh

      - name: Build and run Java
        if: matrix.runner == 'java'
        working-directory: supply-chain/java
        run: |
          mvn package --no-transfer-progress
          java -jar target/supply-chain.jar

      - name: Run JavaScript queries
        if: matrix.runner == 'js'
        working-directory: supply-chain/js
        run: node supply-chain.js

      - name: Teardown
        if: always()
        working-directory: supply-chain
        run: docker compose down
```

Pin action SHAs to match the existing recommendation-engine workflow.

---

### Task 13: Update root README.md and CLAUDE.md

**Files:**
- Modify: `README.md` — add supply-chain row to the use cases table
- Modify: `CLAUDE.md` — add supply-chain to the use cases table

---

### Task 14: Final cleanup and push

**Step 1:** Stop Docker: `docker compose down`
**Step 2:** Verify clean git state: `git status && git log --oneline -10`
**Step 3:** Push branch: `git push origin feat/supply-chain`
