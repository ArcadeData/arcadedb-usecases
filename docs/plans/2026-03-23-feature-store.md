# AI/ML Feature Store Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a fully self-contained `feature-store/` directory demonstrating ArcadeDB as a unified ML feature store serving three domains (fraud, recommendations, maintenance) via 11 query patterns, runnable with `curl`, Java, and JavaScript (PostgreSQL protocol).

**Architecture:** Self-contained directory per the design doc. Docker Compose brings up ArcadeDB 26.4.2 with PostgreSQL plugin. A `setup.sh` creates the database and applies SQL files. Eleven queries are demonstrated via `queries/queries.sh` (curl), `java/` (Maven fat JAR using `arcadedb-network`), and `js/` (Node.js using `pg` driver).

**Tech Stack:** ArcadeDB 26.4.2, Docker Compose, Maven 3.x, Java 21, `com.arcadedb:arcadedb-network:26.4.2`, Node.js 22, `pg` npm package, `jq` (for setup/query scripts)

---

### Task 1: Scaffold the directory structure

**Files:**
- Create: `feature-store/` (directory)
- Create: `feature-store/sql/` (directory)
- Create: `feature-store/queries/` (directory)
- Create: `feature-store/java/src/main/java/com/arcadedb/examples/` (directory)
- Create: `feature-store/js/` (directory)

**Step 1: Create all directories**

```bash
mkdir -p feature-store/sql
mkdir -p feature-store/queries
mkdir -p feature-store/java/src/main/java/com/arcadedb/examples
mkdir -p feature-store/js
```

**Step 2: Verify**

```bash
find feature-store -type d
```

**Step 3: Commit**

```bash
git add feature-store/
git commit -m "chore: scaffold feature-store directory structure"
```

---

### Task 2: Write docker-compose.yml

**Files:**
- Create: `feature-store/docker-compose.yml`

**Step 1: Write the file**

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.4.2
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
cd feature-store
docker compose up -d
docker compose ps
```

Expected: `arcadedb` service shows `healthy` after ~30 seconds. Both ports 2480 and 5432 mapped.

**Step 3: Verify PostgreSQL protocol is reachable**

```bash
curl -sf -u root:arcadedb http://localhost:2480/api/v1/ready
```

**Step 4: Commit**

```bash
git add feature-store/docker-compose.yml
git commit -m "feat(feature-store): add docker-compose with PostgreSQL plugin"
```

---

### Task 3: Write the SQL schema

**Files:**
- Create: `feature-store/sql/01-schema.sql`

**Step 1: Write the schema file**

One statement per line. 6 vertex types, 6 edge types, 3 document types, 5 indexes.

```sql
-- Fraud domain
CREATE VERTEX TYPE Account IF NOT EXISTS;
CREATE PROPERTY Account.accountId IF NOT EXISTS STRING;
CREATE PROPERTY Account.accountType IF NOT EXISTS STRING;
CREATE PROPERTY Account.signupSource IF NOT EXISTS STRING;
CREATE PROPERTY Account.flagged IF NOT EXISTS BOOLEAN;
CREATE PROPERTY Account.behaviorVec IF NOT EXISTS LIST;
CREATE INDEX IF NOT EXISTS ON Account (accountId) UNIQUE;
CREATE VERTEX TYPE Merchant IF NOT EXISTS;
CREATE PROPERTY Merchant.merchantId IF NOT EXISTS STRING;
CREATE PROPERTY Merchant.category IF NOT EXISTS STRING;
CREATE PROPERTY Merchant.riskTier IF NOT EXISTS STRING;
-- Recommendation domain
CREATE VERTEX TYPE User IF NOT EXISTS;
CREATE PROPERTY User.userId IF NOT EXISTS STRING;
CREATE PROPERTY User.preferenceVec IF NOT EXISTS LIST;
CREATE INDEX IF NOT EXISTS ON User (userId) UNIQUE;
CREATE VERTEX TYPE Product IF NOT EXISTS;
CREATE PROPERTY Product.productId IF NOT EXISTS STRING;
CREATE PROPERTY Product.name IF NOT EXISTS STRING;
CREATE PROPERTY Product.category IF NOT EXISTS STRING;
CREATE PROPERTY Product.price IF NOT EXISTS FLOAT;
CREATE PROPERTY Product.embedding IF NOT EXISTS LIST;
-- Maintenance domain
CREATE VERTEX TYPE Equipment IF NOT EXISTS;
CREATE PROPERTY Equipment.equipmentId IF NOT EXISTS STRING;
CREATE PROPERTY Equipment.name IF NOT EXISTS STRING;
CREATE PROPERTY Equipment.specifications IF NOT EXISTS STRING;
CREATE PROPERTY Equipment.failureRate IF NOT EXISTS FLOAT;
CREATE INDEX IF NOT EXISTS ON Equipment (equipmentId) UNIQUE;
CREATE VERTEX TYPE Sensor IF NOT EXISTS;
CREATE PROPERTY Sensor.sensorId IF NOT EXISTS STRING;
CREATE PROPERTY Sensor.sensorType IF NOT EXISTS STRING;
CREATE PROPERTY Sensor.unit IF NOT EXISTS STRING;
-- Edge types
CREATE EDGE TYPE TRANSFERRED IF NOT EXISTS;
CREATE PROPERTY TRANSFERRED.amount IF NOT EXISTS FLOAT;
CREATE PROPERTY TRANSFERRED.recordedAt IF NOT EXISTS DATETIME;
CREATE EDGE TYPE LINKED_DEVICE IF NOT EXISTS;
CREATE PROPERTY LINKED_DEVICE.deviceId IF NOT EXISTS STRING;
CREATE EDGE TYPE TRANSACTED IF NOT EXISTS;
CREATE PROPERTY TRANSACTED.amount IF NOT EXISTS FLOAT;
CREATE PROPERTY TRANSACTED.recordedAt IF NOT EXISTS DATETIME;
CREATE EDGE TYPE PURCHASED IF NOT EXISTS;
CREATE EDGE TYPE DEPENDS_ON IF NOT EXISTS;
CREATE PROPERTY DEPENDS_ON.criticality IF NOT EXISTS STRING;
CREATE EDGE TYPE MONITORED_BY IF NOT EXISTS;
-- Document types
CREATE DOCUMENT TYPE TransactionMetric IF NOT EXISTS;
CREATE PROPERTY TransactionMetric.accountId IF NOT EXISTS STRING;
CREATE PROPERTY TransactionMetric.txCount IF NOT EXISTS LONG;
CREATE PROPERTY TransactionMetric.totalAmount IF NOT EXISTS FLOAT;
CREATE PROPERTY TransactionMetric.recordedAt IF NOT EXISTS DATETIME;
CREATE DOCUMENT TYPE SensorReading IF NOT EXISTS;
CREATE PROPERTY SensorReading.equipmentId IF NOT EXISTS STRING;
CREATE PROPERTY SensorReading.temperature IF NOT EXISTS FLOAT;
CREATE PROPERTY SensorReading.vibration IF NOT EXISTS FLOAT;
CREATE PROPERTY SensorReading.pressure IF NOT EXISTS FLOAT;
CREATE PROPERTY SensorReading.recordedAt IF NOT EXISTS DATETIME;
CREATE DOCUMENT TYPE FeatureSnapshot IF NOT EXISTS;
CREATE PROPERTY FeatureSnapshot.entityId IF NOT EXISTS STRING;
CREATE PROPERTY FeatureSnapshot.entityType IF NOT EXISTS STRING;
CREATE PROPERTY FeatureSnapshot.featureVector IF NOT EXISTS LIST;
CREATE PROPERTY FeatureSnapshot.computedAt IF NOT EXISTS DATETIME;
CREATE PROPERTY FeatureSnapshot.modelVersion IF NOT EXISTS STRING;
-- Vector indexes
CREATE INDEX IF NOT EXISTS ON Account (behaviorVec) LSM_VECTOR METADATA { dimensions: 4, similarity: 'COSINE' };
CREATE INDEX IF NOT EXISTS ON Product (embedding) LSM_VECTOR METADATA { dimensions: 4, similarity: 'COSINE' };
```

**Step 2: Commit**

```bash
git add feature-store/sql/01-schema.sql
git commit -m "feat(feature-store): add multi-domain schema SQL"
```

---

### Task 4: Write the sample data

**Files:**
- Create: `feature-store/sql/02-data.sql`

Behavior vectors: legit accounts cluster near `[0.1, 0.2, 0.8, 0.9]`, fraud accounts near `[0.9, 0.8, 0.1, 0.2]`. Product embeddings: Electronics near `[0.9, 0.1, 0.1, 0.1]`, Books near `[0.1, 0.9, 0.1, 0.1]`, Sports near `[0.1, 0.1, 0.9, 0.1]`.

**Step 1: Write the data file**

```sql
-- === Fraud Domain: Accounts ===
-- a1-a3: legit, a4-a5: suspicious, a6: flagged
INSERT INTO Account SET accountId = 'a1', accountType = 'personal', signupSource = 'organic', flagged = false, behaviorVec = [0.1, 0.2, 0.8, 0.9];
INSERT INTO Account SET accountId = 'a2', accountType = 'personal', signupSource = 'referral', flagged = false, behaviorVec = [0.2, 0.1, 0.9, 0.8];
INSERT INTO Account SET accountId = 'a3', accountType = 'business', signupSource = 'organic', flagged = false, behaviorVec = [0.1, 0.3, 0.7, 0.9];
INSERT INTO Account SET accountId = 'a4', accountType = 'personal', signupSource = 'ad_campaign', flagged = false, behaviorVec = [0.7, 0.6, 0.2, 0.3];
INSERT INTO Account SET accountId = 'a5', accountType = 'personal', signupSource = 'ad_campaign', flagged = false, behaviorVec = [0.8, 0.7, 0.2, 0.1];
INSERT INTO Account SET accountId = 'a6', accountType = 'personal', signupSource = 'unknown', flagged = true, behaviorVec = [0.9, 0.8, 0.1, 0.2];
-- Merchants
INSERT INTO Merchant SET merchantId = 'm1', category = 'grocery', riskTier = 'low';
INSERT INTO Merchant SET merchantId = 'm2', category = 'electronics', riskTier = 'low';
INSERT INTO Merchant SET merchantId = 'm3', category = 'gambling', riskTier = 'high';
INSERT INTO Merchant SET merchantId = 'm4', category = 'crypto', riskTier = 'high';
-- TRANSFERRED edges (money flows; a4-a6 form a circular pattern)
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a2') SET amount = 500.00, recordedAt = '2026-03-01 10:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a2') TO (SELECT FROM Account WHERE accountId = 'a3') SET amount = 200.00, recordedAt = '2026-03-02 11:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a3') SET amount = 150.00, recordedAt = '2026-03-03 09:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a6') SET amount = 3000.00, recordedAt = '2026-03-10 02:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a6') TO (SELECT FROM Account WHERE accountId = 'a5') SET amount = 2800.00, recordedAt = '2026-03-10 02:30:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Account WHERE accountId = 'a4') SET amount = 2500.00, recordedAt = '2026-03-10 03:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a5') SET amount = 1500.00, recordedAt = '2026-03-11 04:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a6') TO (SELECT FROM Account WHERE accountId = 'a4') SET amount = 4000.00, recordedAt = '2026-03-12 01:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a3') TO (SELECT FROM Account WHERE accountId = 'a1') SET amount = 100.00, recordedAt = '2026-03-05 14:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a2') TO (SELECT FROM Account WHERE accountId = 'a1') SET amount = 250.00, recordedAt = '2026-03-06 16:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Account WHERE accountId = 'a6') SET amount = 1800.00, recordedAt = '2026-03-13 05:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a4') SET amount = 300.00, recordedAt = '2026-03-08 12:00:00';
-- LINKED_DEVICE edges (a4 and a5 share devices with flagged a6)
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a6') SET deviceId = 'dev-001';
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Account WHERE accountId = 'a6') SET deviceId = 'dev-002';
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a5') SET deviceId = 'dev-003';
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a2') SET deviceId = 'dev-004';
-- TRANSACTED edges (account -> merchant)
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Merchant WHERE merchantId = 'm1') SET amount = 85.50, recordedAt = '2026-03-01 09:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Merchant WHERE merchantId = 'm2') SET amount = 450.00, recordedAt = '2026-03-02 14:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a2') TO (SELECT FROM Merchant WHERE merchantId = 'm1') SET amount = 62.30, recordedAt = '2026-03-03 10:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Merchant WHERE merchantId = 'm3') SET amount = 5000.00, recordedAt = '2026-03-10 22:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Merchant WHERE merchantId = 'm4') SET amount = 8000.00, recordedAt = '2026-03-11 01:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Merchant WHERE merchantId = 'm3') SET amount = 3500.00, recordedAt = '2026-03-12 23:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a6') TO (SELECT FROM Merchant WHERE merchantId = 'm4') SET amount = 12000.00, recordedAt = '2026-03-10 00:30:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a3') TO (SELECT FROM Merchant WHERE merchantId = 'm2') SET amount = 320.00, recordedAt = '2026-03-04 15:00:00';
-- TransactionMetric documents (time-bucketed velocity data)
INSERT INTO TransactionMetric SET accountId = 'a1', txCount = 5, totalAmount = 1200.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a1', txCount = 3, totalAmount = 800.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a1', txCount = 4, totalAmount = 950.00, recordedAt = '2026-03-15 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a2', txCount = 2, totalAmount = 400.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a2', txCount = 3, totalAmount = 600.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a3', txCount = 4, totalAmount = 1500.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a3', txCount = 2, totalAmount = 700.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a4', txCount = 15, totalAmount = 25000.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a4', txCount = 22, totalAmount = 48000.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a4', txCount = 30, totalAmount = 72000.00, recordedAt = '2026-03-15 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a5', txCount = 8, totalAmount = 12000.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a5', txCount = 18, totalAmount = 35000.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a6', txCount = 25, totalAmount = 60000.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a6', txCount = 35, totalAmount = 95000.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a6', txCount = 40, totalAmount = 120000.00, recordedAt = '2026-03-15 00:00:00';
-- === Recommendation Domain: Users ===
INSERT INTO User SET userId = 'u1', preferenceVec = [0.9, 0.1, 0.1, 0.1];
INSERT INTO User SET userId = 'u2', preferenceVec = [0.7, 0.3, 0.1, 0.1];
INSERT INTO User SET userId = 'u3', preferenceVec = [0.1, 0.9, 0.1, 0.1];
INSERT INTO User SET userId = 'u4', preferenceVec = [0.1, 0.1, 0.9, 0.1];
INSERT INTO User SET userId = 'u5', preferenceVec = [0.4, 0.4, 0.2, 0.1];
-- Products
INSERT INTO Product SET productId = 'p1', name = 'Laptop', category = 'Electronics', price = 999.99, embedding = [0.9, 0.1, 0.1, 0.1];
INSERT INTO Product SET productId = 'p2', name = 'Phone', category = 'Electronics', price = 699.99, embedding = [0.8, 0.2, 0.1, 0.1];
INSERT INTO Product SET productId = 'p3', name = 'Headphones', category = 'Electronics', price = 199.99, embedding = [0.7, 0.2, 0.2, 0.1];
INSERT INTO Product SET productId = 'p4', name = 'ML Textbook', category = 'Books', price = 79.99, embedding = [0.1, 0.9, 0.1, 0.1];
INSERT INTO Product SET productId = 'p5', name = 'Data Science Guide', category = 'Books', price = 49.99, embedding = [0.2, 0.8, 0.1, 0.1];
INSERT INTO Product SET productId = 'p6', name = 'Python Cookbook', category = 'Books', price = 39.99, embedding = [0.1, 0.8, 0.2, 0.1];
INSERT INTO Product SET productId = 'p7', name = 'Running Shoes', category = 'Sports', price = 89.99, embedding = [0.1, 0.1, 0.9, 0.1];
INSERT INTO Product SET productId = 'p8', name = 'Yoga Mat', category = 'Sports', price = 29.99, embedding = [0.1, 0.1, 0.8, 0.2];
-- PURCHASED edges (u1+u2 share Laptop and Phone -> collab recommends ML Textbook to u1)
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u1') TO (SELECT FROM Product WHERE productId = 'p1');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u1') TO (SELECT FROM Product WHERE productId = 'p2');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u1') TO (SELECT FROM Product WHERE productId = 'p3');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u2') TO (SELECT FROM Product WHERE productId = 'p1');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u2') TO (SELECT FROM Product WHERE productId = 'p2');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u2') TO (SELECT FROM Product WHERE productId = 'p4');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u3') TO (SELECT FROM Product WHERE productId = 'p4');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u3') TO (SELECT FROM Product WHERE productId = 'p5');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u3') TO (SELECT FROM Product WHERE productId = 'p6');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u4') TO (SELECT FROM Product WHERE productId = 'p7');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u4') TO (SELECT FROM Product WHERE productId = 'p8');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u5') TO (SELECT FROM Product WHERE productId = 'p1');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u5') TO (SELECT FROM Product WHERE productId = 'p5');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u5') TO (SELECT FROM Product WHERE productId = 'p7');
-- === Maintenance Domain: Equipment ===
INSERT INTO Equipment SET equipmentId = 'eq1', name = 'Main Compressor', specifications = 'Industrial 500HP', failureRate = 0.02;
INSERT INTO Equipment SET equipmentId = 'eq2', name = 'Cooling Unit A', specifications = 'Glycol cooling 200kW', failureRate = 0.05;
INSERT INTO Equipment SET equipmentId = 'eq3', name = 'Pump Station B', specifications = 'Centrifugal 150GPM', failureRate = 0.03;
INSERT INTO Equipment SET equipmentId = 'eq4', name = 'Generator Alpha', specifications = 'Diesel 800kVA', failureRate = 0.01;
INSERT INTO Equipment SET equipmentId = 'eq5', name = 'Control Panel C', specifications = 'PLC-based HMI', failureRate = 0.08;
-- DEPENDS_ON edges (eq2,eq3 depend on eq1; eq5 depends on eq4; eq4 depends on eq1)
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq2') TO (SELECT FROM Equipment WHERE equipmentId = 'eq1') SET criticality = 'high';
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq3') TO (SELECT FROM Equipment WHERE equipmentId = 'eq1') SET criticality = 'medium';
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq4') TO (SELECT FROM Equipment WHERE equipmentId = 'eq1') SET criticality = 'high';
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq5') TO (SELECT FROM Equipment WHERE equipmentId = 'eq4') SET criticality = 'high';
-- Sensors
INSERT INTO Sensor SET sensorId = 's1', sensorType = 'temperature', unit = 'celsius';
INSERT INTO Sensor SET sensorId = 's2', sensorType = 'vibration', unit = 'mm_per_sec';
INSERT INTO Sensor SET sensorId = 's3', sensorType = 'pressure', unit = 'bar';
-- MONITORED_BY edges
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq1') TO (SELECT FROM Sensor WHERE sensorId = 's1');
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq1') TO (SELECT FROM Sensor WHERE sensorId = 's2');
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq2') TO (SELECT FROM Sensor WHERE sensorId = 's1');
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq3') TO (SELECT FROM Sensor WHERE sensorId = 's3');
-- SensorReading documents (eq1 showing anomalous high temperature and vibration)
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 85.2, vibration = 4.5, pressure = 6.1, recordedAt = '2026-03-15 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 92.1, vibration = 5.8, pressure = 6.3, recordedAt = '2026-03-16 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 98.5, vibration = 7.2, pressure = 6.5, recordedAt = '2026-03-17 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 105.3, vibration = 9.1, pressure = 6.8, recordedAt = '2026-03-18 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 42.1, vibration = 1.2, pressure = 4.5, recordedAt = '2026-03-15 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 43.0, vibration = 1.3, pressure = 4.6, recordedAt = '2026-03-16 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 41.8, vibration = 1.1, pressure = 4.4, recordedAt = '2026-03-17 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 42.5, vibration = 1.2, pressure = 4.5, recordedAt = '2026-03-18 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 55.0, vibration = 2.0, pressure = 8.1, recordedAt = '2026-03-15 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 54.5, vibration = 2.1, pressure = 8.0, recordedAt = '2026-03-16 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 56.2, vibration = 1.9, pressure = 8.2, recordedAt = '2026-03-17 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 55.8, vibration = 2.0, pressure = 8.1, recordedAt = '2026-03-18 08:00:00';
-- === Feature Store Infrastructure: FeatureSnapshots ===
INSERT INTO FeatureSnapshot SET entityId = 'a1', entityType = 'Account', featureVector = [4, 3, 5, 12, 2950, 0.15], computedAt = '2026-03-15 00:00:00', modelVersion = 'fraud-v2.1';
INSERT INTO FeatureSnapshot SET entityId = 'a4', entityType = 'Account', featureVector = [8, 6, 3, 67, 145000, 0.87], computedAt = '2026-03-15 00:00:00', modelVersion = 'fraud-v2.1';
INSERT INTO FeatureSnapshot SET entityId = 'a6', entityType = 'Account', featureVector = [11, 5, 1, 100, 275000, 0.99], computedAt = '2026-03-15 00:00:00', modelVersion = 'fraud-v2.1';
```

**Step 2: Commit**

```bash
git add feature-store/sql/02-data.sql
git commit -m "feat(feature-store): add multi-domain sample data"
```

---

### Task 5: Write setup.sh

**Files:**
- Create: `feature-store/setup.sh`

Copy the pattern from recommendation-engine: wait for ArcadeDB, create database `FeatureStore`, apply sql files line-by-line.

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="FeatureStore"

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

**Step 2: Make executable**

```bash
chmod +x feature-store/setup.sh
```

**Step 3: Run it (ArcadeDB must be up from Task 2)**

```bash
cd feature-store
./setup.sh
```

Expected: no errors, ends with "Setup complete."

**Step 4: Smoke-test**

```bash
curl -s -u root:arcadedb \
  -X POST "http://localhost:2480/api/v1/query/FeatureStore" \
  -H "Content-Type: application/json" \
  -d '{"language":"sql","command":"SELECT count(*) FROM Account"}' | jq .
```

Expected: count = 6.

**Step 5: Commit**

```bash
git add feature-store/setup.sh
git commit -m "feat(feature-store): add database setup script"
```

---

### Task 6: Write queries/queries.sh

**Files:**
- Create: `feature-store/queries/queries.sh`

All 11 query patterns as curl calls. Uses `query()` helper for both SQL and Cypher.

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
# AI/ML Feature Store — all 11 query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="FeatureStore"
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
echo "========== FRAUD DOMAIN =========="
echo ""
echo "=== Query 1: Account Graph Features (SQL MATCH) ==="
echo "Compute graph topology features for account a4."
echo ""
query "sql" "
SELECT inDeg, outDeg, counterparties
FROM (
  MATCH {type: Account, where: (accountId = 'a4'), as: acct}
  RETURN acct.in('TRANSFERRED').size() AS inDeg,
         acct.out('TRANSFERRED').size() AS outDeg,
         acct.both('TRANSFERRED').size() AS counterparties
)
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Distance to Flagged Account (SQL MATCH) ==="
echo "Find shortest path from a4 to nearest flagged account via transfers."
echo ""
query "sql" "
SELECT flaggedId, depth
FROM (
  MATCH {type: Account, where: (accountId = 'a4')}
        .both('TRANSFERRED'){while: (\$depth < 4), as: hop}
        {type: Account, where: (flagged = true), as: flagged}
  RETURN flagged.accountId AS flaggedId, \$depth AS depth
)
ORDER BY depth ASC
LIMIT 1
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Behavior Similarity Search (SQL) ==="
echo "Find accounts with behavior vectors similar to flagged a6 [0.9,0.8,0.1,0.2]."
echo ""
query "sql" "
SELECT accountId, accountType, flagged
FROM Account
ORDER BY vectorNeighbors('Account[behaviorVec]', [0.9, 0.8, 0.1, 0.2], 10) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Transaction Velocity (SQL) ==="
echo "Aggregate TransactionMetric for velocity features per account."
echo ""
query "sql" "
SELECT accountId,
       sum(txCount) AS totalTx,
       sum(totalAmount) AS totalAmount,
       avg(totalAmount) AS avgBucketAmount
FROM TransactionMetric
GROUP BY accountId
ORDER BY totalTx DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: Shared Device Network (Cypher) ==="
echo "Find accounts sharing devices with flagged accounts."
echo ""
query "cypher" "
MATCH (flagged:Account {flagged: true})
      -[:LINKED_DEVICE]-(suspect:Account)
WHERE suspect.flagged = false
RETURN DISTINCT suspect.accountId, suspect.accountType,
       flagged.accountId AS linkedToFlagged
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========== RECOMMENDATION DOMAIN =========="
echo ""
echo "=== Query 6: Collaborative Filtering (Cypher) ==="
echo "Find products to recommend to u1 based on shared purchases."
echo ""
query "cypher" "
MATCH (me:User {userId: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
WHERE rec <> p
  AND NOT (me)-[:PURCHASED]->(rec)
RETURN rec.name, rec.category, count(DISTINCT other) AS score
ORDER BY score DESC LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 7: Product Embedding Search (SQL) ==="
echo "Find products similar to Laptop embedding [0.9,0.1,0.1,0.1]."
echo ""
query "sql" "
SELECT name, category, price
FROM Product
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 10) DESC
LIMIT 5
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 8: Personalized Ranking (SQL) ==="
echo "Rank Electronics products for u1 by preference vector similarity."
echo ""
query "sql" "
SELECT name, price
FROM Product
WHERE category = 'Electronics'
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 20) DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========== MAINTENANCE DOMAIN =========="
echo ""
echo "=== Query 9: Equipment Dependency Chain (SQL MATCH) ==="
echo "Find all downstream equipment affected if eq1 fails."
echo ""
query "sql" "
SELECT name, failureRate, criticality
FROM (
  MATCH {type: Equipment, where: (equipmentId = 'eq1')}
        .in('DEPENDS_ON'){as: dep}
  RETURN dep.name AS name, dep.failureRate AS failureRate,
         dep.out('DEPENDS_ON')[0].criticality AS criticality
)
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 10: Sensor Anomaly Detection (SQL) ==="
echo "Find equipment with anomalous sensor readings."
echo ""
query "sql" "
SELECT equipmentId,
       avg(temperature) AS avgTemp,
       max(vibration) AS maxVibration,
       avg(pressure) AS avgPressure
FROM SensorReading
GROUP BY equipmentId
ORDER BY avgTemp DESC
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========== CROSS-DOMAIN =========="
echo ""
echo "=== Query 11: Feature Vector Assembly (Multi-step) ==="
echo "Assemble a fraud feature vector for account a4."
echo ""

echo "--- Step 1: Graph features (degree + counterparties) ---"
query "sql" "
SELECT inDeg, outDeg, counterparties
FROM (
  MATCH {type: Account, where: (accountId = 'a4'), as: acct}
  RETURN acct.in('TRANSFERRED').size() AS inDeg,
         acct.out('TRANSFERRED').size() AS outDeg,
         acct.both('TRANSFERRED').size() AS counterparties
)
"

echo ""
echo "--- Step 2: Vector features (similarity rank to known fraud) ---"
query "sql" "
SELECT accountId, flagged
FROM Account
ORDER BY vectorNeighbors('Account[behaviorVec]', [0.7, 0.6, 0.2, 0.3], 10) DESC
LIMIT 5
"

echo ""
echo "--- Step 3: Time-series features (transaction velocity) ---"
query "sql" "
SELECT sum(txCount) AS totalTx,
       sum(totalAmount) AS totalAmount,
       avg(totalAmount) AS avgBucketAmount
FROM TransactionMetric
WHERE accountId = 'a4'
"

echo ""
echo "--- Step 4: Store feature snapshot ---"
command "sql" "
INSERT INTO FeatureSnapshot SET entityId = 'a4', entityType = 'Account',
  featureVector = [8, 6, 3, 67, 145000, 0.87],
  computedAt = '2026-03-23 00:00:00', modelVersion = 'fraud-v2.2'
"
echo "(Snapshot stored)"

echo ""
echo "--- Verify: Feature snapshots for a4 ---"
query "sql" "
SELECT entityId, modelVersion, computedAt
FROM FeatureSnapshot
WHERE entityId = 'a4'
ORDER BY computedAt DESC
"
```

**Step 2: Make executable**

```bash
chmod +x feature-store/queries/queries.sh
```

**Step 3: Run and verify all 11 queries return results**

```bash
cd feature-store
./queries/queries.sh
```

Expected for key queries:
- Query 1: inDeg/outDeg/counterparties for a4
- Query 3: a6, a5, a4 near top (fraud-like vectors)
- Query 5: a4 and a5 as suspects linked to a6
- Query 6: ML Textbook recommended to u1 (via shared purchases with u2)
- Query 10: eq1 with highest avgTemp (~95)

**Step 4: Commit**

```bash
git add feature-store/queries/queries.sh
git commit -m "feat(feature-store): add 11 curl query demonstrations"
```

---

### Task 7: Write java/pom.xml

**Files:**
- Create: `feature-store/java/pom.xml`

**Step 1: Write the pom.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.arcadedb.examples</groupId>
  <artifactId>feature-store</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <arcadedb.version>26.4.2</arcadedb.version>
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
        <version>3.7.1</version>
        <configuration>
          <archive>
            <manifest>
              <mainClass>com.arcadedb.examples.FeatureStore</mainClass>
            </manifest>
          </archive>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <finalName>feature-store</finalName>
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

**Step 2: Verify Maven resolves dependencies**

```bash
cd feature-store/java
mvn dependency:resolve -q
```

**Step 3: Commit**

```bash
git add feature-store/java/pom.xml
git commit -m "feat(feature-store): add Maven project for Java demo"
```

---

### Task 8: Write FeatureStore.java

**Files:**
- Create: `feature-store/java/src/main/java/com/arcadedb/examples/FeatureStore.java`

Follows the `tryRun()`/`printHeader()` pattern. Implements all 11 queries. Uses `RemoteDatabase` with `query()` for reads and `command()` for writes. Cypher queries use `"cypher"` language.

Note: For Cypher queries returning properties like `rec.name`, use `getProperty("rec.name")`. Be aware of the `ClassCastException` issue with `collect()` — avoid `collect()` in Cypher.

**Step 1: Write the Java class**

The class should:
1. Open a `RemoteDatabase` connection
2. Run all 11 queries sequentially wrapped in `tryRun()`
3. Print formatted output for each
4. For Query 11, use `db.command()` for the INSERT

**Step 2: Build and run**

```bash
cd feature-store/java
mvn package -q
java -jar target/feature-store.jar
```

**Step 3: If a query throws an exception**, note the error and adjust:
- If `$depth` variable causes issues in MATCH: try alternative syntax
- If Cypher `RETURN DISTINCT` fails: remove DISTINCT
- If `vectorNeighbors` ordering seems wrong: verify the index name format `TypeName[propertyName]`

**Step 4: Commit once all queries run successfully**

```bash
git add feature-store/java/
git commit -m "feat(feature-store): add Java FeatureStore main class"
```

---

### Task 9: Write js/package.json

**Files:**
- Create: `feature-store/js/package.json`

```json
{
  "name": "feature-store",
  "version": "1.0.0",
  "private": true,
  "description": "ArcadeDB Feature Store queries via PostgreSQL protocol",
  "main": "feature-store.js",
  "dependencies": {
    "pg": "^8.13.0"
  }
}
```

**Step 1: Install dependencies**

```bash
cd feature-store/js
npm install
```

**Step 2: Commit** (include package.json only, not package-lock.json — it will be gitignored or committed separately)

```bash
git add feature-store/js/package.json
git commit -m "feat(feature-store): add Node.js package for PostgreSQL protocol"
```

---

### Task 10: Write js/feature-store.js

**Files:**
- Create: `feature-store/js/feature-store.js`

Follows supply-chain/js pattern: `pg.Client`, `printHeader()`, `tryRun()`, sequential queries. Cypher queries use `{cypher}` prefix. All 11 queries.

**Step 1: Write the script**

Connection config from env vars: `ARCADEDB_HOST`, `ARCADEDB_PG_PORT` (default 5432), `ARCADEDB_USER`, `ARCADEDB_PASS`. Database: `FeatureStore`.

For Cypher queries (5, 6, 8), prefix with `{cypher}`:
```javascript
const sql = `{cypher} MATCH (flagged:Account {flagged: true}) ...`;
```

For Query 11 Step 4 (INSERT), use `client.query()` with the SQL INSERT statement.

**Step 2: Run and verify**

```bash
cd feature-store/js
node feature-store.js
```

**Step 3: Commit**

```bash
git add feature-store/js/feature-store.js
git commit -m "feat(feature-store): add JavaScript queries via PostgreSQL protocol"
```

---

### Task 11: Write feature-store/README.md

**Files:**
- Create: `feature-store/README.md`

Follow the recommendation-engine README format. Include:
- Overview (3 ML teams, unified feature store)
- Prerequisites (Docker, curl, jq, Java 21, Maven, Node.js 22)
- Quickstart (docker compose up, setup.sh, queries.sh, Java, JS)
- Schema table (all 15 types)
- Query patterns table (all 11)
- Sample data summary
- ArcadeDB version notes
- Reference link

**Step 1: Write the README**

**Step 2: Commit**

```bash
git add feature-store/README.md
git commit -m "docs(feature-store): add README with quickstart guide"
```

---

### Task 12: Create CI workflow

**Files:**
- Create: `.github/workflows/feature-store.yml`

Copy from `supply-chain.yml`, change 5 values:
1. `name: Feature Store CI`
2. `paths: feature-store/**` and `.github/workflows/feature-store.yml`
3. Cache keys: `feature-store` instead of `supply-chain`
4. `working-directory: feature-store` (and `feature-store/java`, `feature-store/js`)
5. JAR filename: `feature-store.jar`

Matrix: `[curl, java, js]` — same as supply-chain.

Use the same pinned action SHAs from supply-chain.yml.

**Step 1: Write the workflow file**

**Step 2: Commit**

```bash
git add .github/workflows/feature-store.yml
git commit -m "ci: add Feature Store CI workflow"
```

---

### Task 13: Update dependabot.yml

**Files:**
- Modify: `.github/dependabot.yml`

Add three new entries before the closing of the file, following existing patterns:

1. Maven entry for `/feature-store/java` with `arcadedb` and `maven-plugins` groups
2. npm entry for `/feature-store/js` with `node-pg` group
3. Docker Compose entry for `/feature-store` with `arcadedb-docker` group

**Step 1: Read current file and append entries**

**Step 2: Commit**

```bash
git add .github/dependabot.yml
git commit -m "chore: add dependabot entries for feature-store module"
```

---

### Task 14: Update root README.md

**Files:**
- Modify: `README.md`

Add a row to the use cases table:

```markdown
| [feature-store](./feature-store/) | Unified ML feature store for fraud, recommendations, and maintenance | Graph traversal, Vector similarity, Time-series, PostgreSQL protocol, JavaScript |
```

**Step 1: Insert row into table**

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add feature-store to root README use cases table"
```

---

### Task 15: Final cleanup and push

**Step 1: Stop Docker**

```bash
cd feature-store
docker compose down
```

**Step 2: Verify clean git state**

```bash
git status
git log --oneline -15
```

**Step 3: Push branch**

```bash
git push origin feat/feature-store
```
