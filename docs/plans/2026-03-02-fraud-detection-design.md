# Fraud Detection Use Case — Design

**Date:** 2026-03-02
**Branch:** feat/fraud-detection
**ArcadeDB version:** 26.3.1-SNAPSHOT

## Overview

Implement the [ArcadeDB Fraud Detection](https://arcadedb.com/fraud-detection.html) use case as the second entry in the `arcadedb-usecases` repository. The use case demonstrates ArcadeDB's ability to unify four detection capabilities — graph relationship analysis, vector-based behavioral anomaly detection, time-series pattern identification, and full-text fuzzy matching — in a single multi-model database.

## Repository Structure

Self-contained directory, same layout as the recommendation-engine:

```
fraud-detection/
├── README.md
├── docker-compose.yml
├── setup.sh
├── sql/
│   ├── 01-schema.sql
│   └── 02-data.sql
├── queries/
│   └── queries.sh
└── java/
    ├── pom.xml
    └── src/main/java/
        └── com/arcadedb/examples/FraudDetection.java
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.3.1-SNAPSHOT`
- HTTP API port exposed: `2480`
- Root credentials passed as environment variables (`JAVA_OPTS: -Darcadedb.server.rootPassword=arcadedb`)
- Healthcheck on `/api/v1/ready`

## Schema (`sql/01-schema.sql`)

Eight vertex types, six edge types, one document type.

**Vertices:**
- `Account` — `id` (STRING), `name` (STRING), `full_name` (STRING), `ssn` (STRING), `credit_limit` (FLOAT), `balance` (FLOAT)
- `Customer` — `id` (STRING), `baseline_behavior` (STRING), `recent_behavior` (STRING), `profile_embedding` (LIST)
- `Device` — `id` (STRING), `fingerprint` (STRING)
- `Phone` — `number` (STRING)
- `Address` — `street` (STRING), `city` (STRING), `zip` (STRING)
- `Email` — `address` (STRING)
- `Beneficiary` — `id` (STRING), `name` (STRING)
- `Transaction` — `id` (STRING), `amount` (FLOAT), `merchant` (STRING), `behavior_embedding` (LIST), `ts` (DATETIME)

**Edges:**
- `USES_DEVICE` — Account → Device
- `HAS_PHONE` — Account → Phone
- `HAS_ADDRESS` — Account → Address
- `HAS_EMAIL` — Account → Email
- `TRANSFERRED_TO` — Account → Account (properties: `amount` FLOAT, `ts` DATETIME)
- `BENEFICIARY_OF` — Account → Beneficiary

**Document types:**
- `Deposit` — `account_id` (STRING), `amount` (FLOAT), `ts` (DATETIME)

**Indexes:**
- `UNIQUE` on `Account(id)`, `Customer(id)`, `Transaction(id)`
- `LSM_VECTOR` on `Customer(profile_embedding)` — 8 dimensions, COSINE
- `LSM_VECTOR` on `Transaction(behavior_embedding)` — 8 dimensions, COSINE
- `FULL_TEXT` on `Account(full_name)`

## Sample Data (`sql/02-data.sql`)

Approximately 60–70 records across 11 accounts with distinct fraud patterns:

**Fraud Ring (accounts A–E):**
- 5 accounts sharing one Device (`dev-shared`) and one Phone (`phone-shared`)
- Circular transfers A→B→C→D→E→A, amounts $8,000–$9,500, spread over 30 days
- Each account has its own unique Email
- 3+ deposits per day in the $8,000–$9,999 range (structuring pattern)

**Synthetic Identity Pair (accounts F–G):**
- `acct-F` ("Robert J. Smith", SSN "123-45-6789") and `acct-G` ("Rob Smith Jr.", same SSN)
- Same Address, different Phones and Emails
- `full_name` similarity between 0.4–0.9

**Velocity Attacker (account H):**
- 10+ transactions in a 5-minute window
- `behavior_embedding` deviates significantly from Customer `profile_embedding` (vectorDistance > 0.7)

**Legitimate Accounts (L1–L3):**
- Each has unique Device, Phone, Address, Email
- Normal transfer patterns, occasional deposits of varying amounts
- `behavior_embedding` close to `profile_embedding` (vectorDistance < 0.3)

**Customers:**
- 11 Customer records (one per account) with 8-dimensional `profile_embedding` vectors
- Fraud ring members share similar embeddings; legitimate accounts have distinct profiles

All embeddings use 8-dimensional float arrays.

## Queries

Eight query patterns covering all four signal types:

| # | Pattern | Language | Signal Type |
|---|---------|----------|-------------|
| 1 | Fraud Ring Detection | Cypher | Graph |
| 2 | Synthetic Identity Resolution | SQL | Full-Text |
| 3 | Circular Money Flow | Cypher | Graph |
| 4 | Structuring Detection | SQL | Time-Series |
| 5 | Behavioral Anomaly | SQL | Vector |
| 6 | Velocity Attack Detection | SQL | Time-Series |
| 7 | Correlated Account Activity | SQL | Time-Series |
| 8 | Multi-Model Investigation | SQL | Combined |

### Query 1: Fraud Ring Detection (Graph Traversal)

Multi-hop traversal through shared identifiers to find accounts connected to a flagged account:

```cypher
MATCH (flagged:Account {id: 'acct-A'})
      -[:USES_DEVICE|HAS_PHONE|HAS_ADDRESS*1..4]-
      (connected:Account)
WHERE connected <> flagged
RETURN DISTINCT connected.id, connected.name
```

### Query 2: Synthetic Identity Resolution (Full-Text)

Fuzzy matching on `full_name` where SSN matches but names differ:

```sql
SELECT a.id, b.id, a.full_name, b.full_name
FROM Account AS a, Account AS b
WHERE a.ssn = b.ssn
  AND a.id < b.id
  AND a.full_name.similarity(b.full_name) BETWEEN 0.4 AND 0.9
```

### Query 3: Circular Money Flow (Graph Cycles)

Detect circular transfer paths returning to origin within 30 days:

```cypher
MATCH path = (origin:Account)-[:TRANSFERRED_TO*3..6]->(origin)
WHERE all(t IN relationships(path)
  WHERE t.ts > datetime() - duration('P30D'))
RETURN origin.id, [n IN nodes(path) | n.id] AS chain
```

### Query 4: Structuring Detection (Time-Series Bucketing)

Flag accounts making 3+ deposits per day in the $8,000–$9,999 range:

```sql
SELECT time_bucket('1d', ts) AS day, account_id, count(*) AS deposit_count
FROM Deposit
WHERE amount BETWEEN 8000 AND 9999
GROUP BY day, account_id
HAVING deposit_count >= 3
```

### Query 5: Behavioral Anomaly (Vector Distance)

Detect transactions whose behavioral embedding deviates from the customer's profile:

```sql
SELECT t.id, t.amount, t.merchant,
       vectorDistance(t.behavior_embedding, c.profile_embedding) AS deviation
FROM Transaction t
JOIN Customer c ON t.account_id = c.id
WHERE vectorDistance(t.behavior_embedding, c.profile_embedding) > 0.7
ORDER BY deviation DESC
```

### Query 6: Velocity Attack Detection (Time-Series Rate)

Detect accounts with abnormally high transaction rates over a 5-minute window:

```sql
SELECT account_id, count(*) AS txn_count, min(ts) AS first_txn, max(ts) AS last_txn
FROM Transaction
WHERE ts BETWEEN '2026-03-01T13:00:00Z' AND '2026-03-01T13:05:00Z'
GROUP BY account_id
HAVING txn_count > 5
```

### Query 7: Correlated Account Activity (Time-Series Correlation)

Detect coordinated transfer activity between two accounts:

```sql
SELECT a.account_id AS account_a, b.account_id AS account_b,
       avg(a.amount) AS avg_a, avg(b.amount) AS avg_b,
       count(*) AS matching_txns
FROM Transaction a, Transaction b
WHERE a.account_id = 'acct-A' AND b.account_id = 'acct-B'
  AND a.ts >= '2026-02-01T00:00:00Z'
  AND b.ts >= '2026-02-01T00:00:00Z'
```

### Query 8: Multi-Model Investigation (Combined)

Composite risk score blending graph distance, temporal patterns, and behavioral deviation. Starts with graph traversal to find connected accounts, enriches with velocity and vector anomaly scores.

## curl Queries (`queries/queries.sh`)

Eight labeled sections, one per query pattern, each POSTing to `http://localhost:2480/api/v1/query/FraudDetection`. Same `query()` helper function as the recommendation-engine.

All queries use hardcoded values matching `02-data.sql` (known account IDs, the shared device, the synthetic identity SSN) so the script works out-of-the-box after setup.

## Java Program (`java/`)

- **Build tool:** Maven (standalone `pom.xml`, no parent)
- **Dependency:** `com.arcadedb:arcadedb-network:26.3.1-SNAPSHOT`
- **Output:** executable fat JAR via `maven-assembly-plugin` (`mvn package` → `java -jar target/fraud-detection.jar`)
- **Entry point:** single `FraudDetection.java` with a `main` method that:
  1. Opens a `RemoteDatabase` connection to `localhost:2480`
  2. Runs all 8 queries sequentially, each wrapped in `tryRun()`
  3. Prints a header and formatted results for each query to stdout
  4. Closes the connection

## Query Language Mapping

| # | Pattern | Language |
|---|---------|----------|
| 1 | Fraud Ring Detection | Cypher |
| 2 | Synthetic Identity Resolution | SQL |
| 3 | Circular Money Flow | Cypher |
| 4 | Structuring Detection | SQL |
| 5 | Behavioral Anomaly | SQL |
| 6 | Velocity Attack Detection | SQL |
| 7 | Correlated Account Activity | SQL |
| 8 | Multi-Model Investigation | SQL |

## Success Criteria

- `docker compose up` starts ArcadeDB 26.3.1-SNAPSHOT successfully
- SQL files apply cleanly via `setup.sh` with no errors
- `queries.sh` runs all 8 queries and returns non-empty result sets
- `mvn package && java -jar target/fraud-detection.jar` runs all 8 queries and prints results to stdout
- Fraud ring query returns accounts B–E when investigating account A
- Synthetic identity query returns the F/G pair
- Circular flow query detects the A→B→C→D→E→A cycle
- Structuring query flags fraud ring accounts with 3+ sub-$10K deposits per day
- Behavioral anomaly query flags account H's transactions
- Velocity query flags account H
