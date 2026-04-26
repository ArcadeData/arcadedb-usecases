# AI/ML Feature Store Use Case — Design

**Date:** 2026-03-23
**Branch:** feat/feature-store
**ArcadeDB version:** 26.4.2

## Overview

Implement the [ArcadeDB AI/ML Feature Store](https://arcadedb.com/ai-ml-feature-store.html) use case. The scenario demonstrates ArcadeDB as a unified feature store for production ML systems, replacing the typical scatter of 3+ specialized databases (graph DB, vector DB, time-series DB) with a single multi-model engine.

Three ML teams share one ArcadeDB instance:

| ML Team | Domain | Feature Types |
|---------|--------|--------------|
| Risk | Fraud scoring | Graph topology + behavior vectors + transaction velocity |
| Growth | Product recommendations | Collaborative filtering + product embeddings |
| Operations | Predictive maintenance | Equipment dependency graph + sensor aggregates |

A cross-cutting **Feature Store infrastructure** layer records feature snapshots for audit/lineage, demonstrating training-serving consistency.

## Repository Structure

```
feature-store/
├── docker-compose.yml          # ArcadeDB with PostgreSQL plugin (ports 2480 + 5432)
├── setup.sh
├── sql/
│   ├── 01-schema.sql
│   └── 02-data.sql
├── queries/
│   └── queries.sh
├── java/
│   ├── pom.xml
│   └── src/main/java/com/arcadedb/examples/FeatureStore.java
├── js/
│   ├── package.json
│   └── feature-store.js
└── README.md
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.4.2`
- HTTP API port: `2480` (shell scripts + Java)
- PostgreSQL protocol port: `5432` (JavaScript)
- PostgreSQL plugin enabled via `JAVA_OPTS`
- Root password: `-Darcadedb.server.rootPassword=arcadedb`

## Schema (`sql/01-schema.sql`)

### Vertex Types (6)

| Type | Properties | Purpose |
|------|-----------|---------|
| `Account` | `accountId` (STRING), `accountType` (STRING), `signupSource` (STRING), `flagged` (BOOLEAN), `behaviorVec` (LIST) | Fraud domain — financial accounts with behavior embeddings |
| `Merchant` | `merchantId` (STRING), `category` (STRING), `riskTier` (STRING) | Fraud domain — transaction counterparties |
| `User` | `userId` (STRING), `preferenceVec` (LIST) | Recommendation domain — platform users |
| `Product` | `productId` (STRING), `name` (STRING), `category` (STRING), `price` (FLOAT), `embedding` (LIST) | Recommendation domain — catalog items |
| `Equipment` | `equipmentId` (STRING), `name` (STRING), `specifications` (STRING), `failureRate` (FLOAT) | Maintenance domain — monitored assets |
| `Sensor` | `sensorId` (STRING), `sensorType` (STRING), `unit` (STRING) | Maintenance domain — sensor metadata |

### Edge Types (6)

| Type | From → To | Properties | Purpose |
|------|-----------|-----------|---------|
| `TRANSFERRED` | Account → Account | `amount` (FLOAT), `recordedAt` (DATETIME) | Money transfers between accounts |
| `LINKED_DEVICE` | Account → Account | `deviceId` (STRING) | Shared-device signal (fraud) |
| `TRANSACTED` | Account → Merchant | `amount` (FLOAT), `recordedAt` (DATETIME) | Account-to-merchant transactions |
| `PURCHASED` | User → Product | — | Purchase history (recommendations) |
| `DEPENDS_ON` | Equipment → Equipment | `criticality` (STRING) | Upstream dependency chain |
| `MONITORED_BY` | Equipment → Sensor | — | Sensor-to-equipment mapping |

### Document Types (3)

| Type | Properties | Purpose |
|------|-----------|---------|
| `TransactionMetric` | `accountId` (STRING), `txCount` (LONG), `totalAmount` (FLOAT), `recordedAt` (DATETIME) | Time-bucketed transaction aggregates for velocity features |
| `SensorReading` | `equipmentId` (STRING), `temperature` (FLOAT), `vibration` (FLOAT), `pressure` (FLOAT), `recordedAt` (DATETIME) | Time-series sensor data for anomaly detection |
| `FeatureSnapshot` | `entityId` (STRING), `entityType` (STRING), `featureVector` (LIST), `computedAt` (DATETIME), `modelVersion` (STRING) | Audit trail — persisted feature vectors for lineage |

### Indexes

| Index | Type | Purpose |
|-------|------|---------|
| `Account[behaviorVec]` | LSM_VECTOR (4d, COSINE) | Behavior similarity search |
| `Product[embedding]` | LSM_VECTOR (4d, COSINE) | Product embedding search |
| `Account(accountId)` | UNIQUE | Account lookup |
| `User(userId)` | UNIQUE | User lookup |
| `Equipment(equipmentId)` | UNIQUE | Equipment lookup |

## Sample Data (`sql/02-data.sql`)

### Fraud Domain
- 6 accounts (a1–a6): a1–a3 legit, a4–a5 suspicious, a6 flagged
- Behavior vectors: legit cluster near `[0.1, 0.2, 0.8, 0.9]`, fraud cluster near `[0.9, 0.8, 0.1, 0.2]`
- 4 merchants: grocery, electronics, gambling (high-risk), crypto (high-risk)
- ~12 TRANSFERRED edges (including circular patterns involving a6)
- ~8 TRANSACTED edges
- 4 LINKED_DEVICE edges (a4↔a6, a5↔a6 share devices)
- ~15 TransactionMetric documents across 3 time buckets

### Recommendation Domain
- 5 users (u1–u5) with 4-d preference vectors
- 8 products across Electronics, Books, Sports categories with 4-d embeddings
- ~15 PURCHASED edges with deliberate overlap (u1+u2 share purchases → collab signal)

### Maintenance Domain
- 5 equipment units (eq1–eq5) forming a dependency chain: eq1 → eq2 → eq3, eq1 → eq4, eq4 → eq5
- 3 sensors monitoring eq1–eq3
- ~12 SensorReading documents (eq1 showing anomalous readings)

### Feature Store Infrastructure
- 3 FeatureSnapshot documents showing pre-computed feature vectors for a1, a4, a6

## Queries

### Fraud Domain (5 queries)

#### Query 1: Account Graph Features (SQL MATCH)
Compute graph topology features for account a4: in-degree, out-degree, distinct counterparty count.
```sql
SELECT inDeg, outDeg, counterparties
FROM (
  MATCH {type: Account, where: (accountId = 'a4'), as: acct}
  RETURN acct.in('TRANSFERRED').size() AS inDeg,
         acct.out('TRANSFERRED').size() AS outDeg,
         acct.both('TRANSFERRED').size() AS counterparties
)
```

#### Query 2: Distance to Flagged Account (SQL MATCH)
Find the shortest path length from a4 to the nearest flagged account via TRANSFERRED edges (up to 4 hops).
```sql
SELECT flaggedId, depth
FROM (
  MATCH {type: Account, where: (accountId = 'a4')}
        .both('TRANSFERRED'){while: ($depth < 4), as: hop}
        {type: Account, where: (flagged = true), as: flagged}
  RETURN flagged.accountId AS flaggedId, $depth AS depth
)
ORDER BY depth ASC
LIMIT 1
```

#### Query 3: Behavior Similarity Search (SQL)
Find accounts with behavior vectors most similar to flagged account a6.
```sql
SELECT accountId, accountType, flagged
FROM Account
ORDER BY vectorNeighbors('Account[behaviorVec]', [0.9, 0.8, 0.1, 0.2], 10) DESC
LIMIT 5
```

#### Query 4: Transaction Velocity (SQL)
Aggregate TransactionMetric documents for each account: total transactions, total amount, average amount per bucket.
```sql
SELECT accountId,
       sum(txCount) AS totalTx,
       sum(totalAmount) AS totalAmount,
       avg(totalAmount) AS avgBucketAmount
FROM TransactionMetric
GROUP BY accountId
ORDER BY totalTx DESC
```

#### Query 5: Shared Device Network (Cypher)
Find accounts sharing devices with flagged accounts — guilt-by-association.
```cypher
MATCH (flagged:Account {flagged: true})
      -[:LINKED_DEVICE]-(suspect:Account)
WHERE suspect.flagged = false
RETURN DISTINCT suspect.accountId, suspect.accountType,
       flagged.accountId AS linkedToFlagged
```

### Recommendation Domain (3 queries)

#### Query 6: Collaborative Filtering (Cypher)
Find products to recommend to u1 based on shared purchase history.
```cypher
MATCH (me:User {userId: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
WHERE rec <> p
  AND NOT (me)-[:PURCHASED]->(rec)
RETURN rec.name, rec.category, count(DISTINCT other) AS score
ORDER BY score DESC LIMIT 10
```

#### Query 7: Product Embedding Search (SQL)
Find products similar to "Laptop" by embedding vector.
```sql
SELECT name, category, price
FROM Product
ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 10) DESC
LIMIT 5
```

#### Query 8: Personalized Ranking (Cypher)
Rank Electronics products for u1 by preference vector similarity.
```cypher
MATCH (u:User {userId: 'u1'})
MATCH (p:Product)
WHERE p.category = 'Electronics'
RETURN p.name, p.price
ORDER BY vectorNeighbors('Product[embedding]', u.preferenceVec, 20) DESC
LIMIT 10
```

### Maintenance Domain (2 queries)

#### Query 9: Equipment Dependency Chain (SQL MATCH)
Find all downstream equipment affected if eq1 fails.
```sql
SELECT name, failureRate, depth
FROM (
  MATCH {type: Equipment, where: (equipmentId = 'eq1')}
        .in('DEPENDS_ON'){while: ($depth < 5), as: dep}
  RETURN dep.name AS name, dep.failureRate AS failureRate, $depth AS depth
)
ORDER BY depth ASC
```

#### Query 10: Sensor Anomaly Detection (SQL)
Find equipment with anomalous sensor readings (high temperature or vibration).
```sql
SELECT equipmentId,
       avg(temperature) AS avgTemp,
       max(vibration) AS maxVibration,
       avg(pressure) AS avgPressure
FROM SensorReading
GROUP BY equipmentId
ORDER BY avgTemp DESC
```

### Cross-Domain (1 multi-step query)

#### Query 11: Feature Vector Assembly (Multi-step)
Assemble a complete fraud feature vector for account a4 by combining graph, vector, and time-series signals, then store as a FeatureSnapshot.

**Step 1 — Graph features:** degree + distance-to-flagged (reuses queries 1 & 2 logic)
**Step 2 — Vector features:** similarity rank among known fraud accounts (reuses query 3 logic)
**Step 3 — Time-series features:** transaction velocity (reuses query 4 logic)
**Step 4 — Store snapshot:** INSERT INTO FeatureSnapshot with assembled vector

## Query Language Mapping

| # | Pattern | Language | Signal | Shell | Java | JS (pg) |
|---|---------|----------|--------|-------|------|---------|
| 1 | Account Graph Features | SQL MATCH | Graph | sql | sql | sql |
| 2 | Distance to Flagged | SQL MATCH | Graph | sql | sql | sql |
| 3 | Behavior Similarity | SQL | Vector | sql | sql | sql |
| 4 | Transaction Velocity | SQL | Time-series | sql | sql | sql |
| 5 | Shared Device Network | Cypher | Graph | cypher | cypher | {cypher} prefix |
| 6 | Collaborative Filtering | Cypher | Graph | cypher | cypher | {cypher} prefix |
| 7 | Product Embedding Search | SQL | Vector | sql | sql | sql |
| 8 | Personalized Ranking | Cypher | Graph + Vector | cypher | cypher | {cypher} prefix |
| 9 | Equipment Dependency Chain | SQL MATCH | Graph | sql | sql | sql |
| 10 | Sensor Anomaly Detection | SQL | Time-series | sql | sql | sql |
| 11 | Feature Vector Assembly | SQL (multi-step) | All | sql | sql | sql |

## JavaScript Module (`js/`)

- Uses the `pg` npm package to connect via ArcadeDB's PostgreSQL wire protocol on port 5432
- Cypher queries prefixed with `{cypher}` (e.g., `{cypher} MATCH ...`)
- Same `printHeader()` / `tryRun()` pattern as `supply-chain/js/`
- All 11 queries implemented

## Dependabot

Three new entries in `.github/dependabot.yml`:

1. **Maven** — `/feature-store/java` (groups: `arcadedb`, `maven-plugins`)
2. **npm** — `/feature-store/js` (groups: `node-pg`)
3. **Docker Compose** — `/feature-store` (groups: `arcadedb-docker`)

## CI Workflow

`.github/workflows/feature-store.yml` — matrix `[curl, java, js]`, same pattern as `supply-chain.yml`.

## Success Criteria

- `docker compose up` starts ArcadeDB with PostgreSQL plugin successfully
- SQL files apply cleanly via `setup.sh`
- `queries.sh` runs all 11 queries and returns non-empty result sets
- `mvn package && java -jar ...` runs all 11 queries and prints results
- `node feature-store.js` runs all 11 queries via PostgreSQL protocol
- Dependabot entries pass validation

## Reference

- [ArcadeDB AI/ML Feature Store](https://arcadedb.com/ai-ml-feature-store.html)
- [ArcadeDB PostgreSQL Protocol](https://docs.arcadedb.com/#Postgres-Driver)
