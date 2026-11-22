# Fraud Detection

Demonstrates ArcadeDB's multi-model capabilities by implementing a fraud detection
system that unifies four signal types in a single database:

- **Graph traversal** — fraud ring detection via shared identifier patterns
- **Vector similarity** — behavioral anomaly detection using embeddings
- **Time-series** — structuring and velocity attack detection via temporal analysis
- **Document queries** — synthetic identity resolution via shared SSN detection

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

This creates the `FraudDetection` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/fraud-detection.jar
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Account` | Vertex | `id`, `name`, `full_name`, `ssn`, `credit_limit`, `balance` |
| `Customer` | Vertex | `id`, `baseline_behavior`, `recent_behavior`, `profile_embedding` |
| `Device` | Vertex | `id`, `fingerprint` |
| `Phone` | Vertex | `number` |
| `Address` | Vertex | `street`, `city`, `zip` |
| `Email` | Vertex | `address` |
| `Beneficiary` | Vertex | `id`, `name` |
| `Transaction` | Vertex | `id`, `account_id`, `amount`, `merchant`, `behavior_embedding`, `ts` |
| `USES_DEVICE` | Edge | Account → Device |
| `HAS_PHONE` | Edge | Account → Phone |
| `HAS_ADDRESS` | Edge | Account → Address |
| `HAS_EMAIL` | Edge | Account → Email |
| `TRANSFERRED_TO` | Edge | Account → Account (`amount`, `ts`) |
| `BENEFICIARY_OF` | Edge | Account → Beneficiary |
| `Deposit` | Document | `account_id`, `amount`, `ts` |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Fraud Ring Detection | Cypher | Graph |
| 2 | Synthetic Identity Resolution | SQL | Document |
| 3 | Circular Money Flow | Cypher | Graph |
| 4 | Structuring Detection | SQL + subquery | Time-Series |
| 5 | Behavioral Anomaly | SQL + vectorCosineSimilarity() | Vector |
| 6 | Velocity Attack Detection | SQL | Time-Series |
| 7 | Correlated Account Activity | SQL | Time-Series |
| 8 | Cross-Type Investigation | SQL + subquery | Combined |
| 9 | Investigation Triage | SQL + FACETS | Facets |

### Investigation triage (Query 9)

> **Faceted search needs ArcadeDB 26.12.1.** Until that release is out, `docker-compose.yml` and
> `java/pom.xml` point to `26.12.1-SNAPSHOT` (the Docker Hub tag and Maven Central snapshots).

Query 9 gives an analyst the transaction list plus where it concentrates: by merchant, by account, by
amount band (including the band just below the 10k reporting threshold) and per day:

```sql
SELECT id, account_id, amount, merchant, ts FROM Transaction
WHERE amount >= 400
FACETS
  merchant TERMS TOP 10,
  account_id TERMS,
  amountBand: amount RANGES ([*, 1000) AS 'under 1k', [1000, 8000) AS '1k-8k', [8000, 10000) AS '8k-10k (near CTR threshold)', [10000, *) AS '10k+'),
  perDay: ts HISTOGRAM CALENDAR '1d' TIMEZONE 'UTC'
LIMIT 5
```

Each faceted property has a `COLUMNAR` index. The drill-down selects merchant "Transfer" with
`FILTER`: the rows are the transfers, while the merchant facet keeps counting every merchant.

## Sample Data

- 11 accounts across four profiles: fraud ring (A–E), synthetic identity pair (F–G),
  velocity attacker (H), and legitimate users (L1–L3)
- 11 customers with 8-dimensional profile embedding vectors
- Shared Device and Phone for fraud ring members; unique identifiers for others
- Circular transfers A→B→C→D→E→A ($8K–$9.5K over 30 days)
- 10 rapid-fire transactions for account H (velocity pattern)
- Structuring deposits: 3+ per day in the $8K–$9,999 range for fraud ring
- Normal transactions and deposits for legitimate accounts

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.12.1** (currently `26.12.1-SNAPSHOT`). It uses:
- `SELECT ... FACETS` over `COLUMNAR` indexes for investigation triage
- `vectorCosineSimilarity()` for behavioral anomaly detection with `LSM_VECTOR` indexes
- Subquery wrapping for `HAVING`-equivalent filtering (ArcadeDB does not support `HAVING`)
- Cypher queries for graph traversal and cycle detection

## Reference

[ArcadeDB Fraud Detection use case](https://arcadedb.com/fraud-detection.html)
