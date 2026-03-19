# Identity & Access Management (IAM)

Demonstrates ArcadeDB's multi-model capabilities by implementing an identity
and access management system that unifies three signal types in a single database:

- **Graph traversal** — permission resolution through nested group/role hierarchies
- **Time-series** — access audit logs for compliance reporting
- **Vector similarity** — behavioral anomaly detection via access pattern embeddings

Each query is implemented twice: once in **ArcadeDB SQL MATCH** and once in
**OpenCypher**, showing how the same graph problems can be expressed in both
languages against the same dataset.

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demos)
- Python 3.12+ (for the Python demos)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

Exposes three protocols:
- **HTTP API** on port 2480 (curl, `arcadedb-network`)
- **PostgreSQL wire protocol** on port 5432 (`psycopg`)
- **Bolt protocol** on port 7687 (`neo4j-java-driver`, `neo4j` Python driver)

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `IAM` database, applies the schema, and inserts sample data.

### 3. Run queries

#### SQL queries

```bash
# curl + jq (HTTP API)
./queries/queries.sh

# Java (arcadedb-network HTTP client)
cd java && mvn package -q && java -jar target/iam.jar

# Python (psycopg — PostgreSQL wire protocol)
cd python && pip install -r requirements.txt && python iam.py
```

#### OpenCypher queries

```bash
# curl + jq (HTTP API with language: "opencypher")
./queries/queries-cypher.sh

# Java (neo4j-java-driver — Bolt protocol)
cd java && mvn package -q && java -cp target/iam.jar com.arcadedb.examples.IamCypher

# Python (neo4j driver — Bolt + psycopg for document/vector queries)
cd python && pip install -r requirements-cypher.txt && python iam_cypher.py
```

## Schema

| Type | Kind | Key Properties |
|------|------|----------------|
| `Identity` | Vertex | `email`, `identityType`, `department`, `title`, `access_pattern_vec` |
| `Group` | Vertex | `name`, `description` |
| `Role` | Vertex | `name`, `description` |
| `Permission` | Vertex | `action` |
| `Resource` | Vertex | `name`, `classification`, `data_sensitivity`, `compliance_scope` |
| `Policy` | Vertex | `name`, `policyType`, `description` |
| `MEMBER_OF` | Edge | Identity/Group → Group |
| `HAS_ROLE` | Edge | Group/Identity → Role |
| `GRANTS` | Edge | Role → Permission |
| `APPLIES_TO` | Edge | Permission → Resource |
| `GOVERNED_BY` | Edge | Resource → Policy |
| `AccessLog` | Document | `identityEmail`, `resourceName`, `action`, `source_ip`, `recordedAt` |

## Query Patterns

| # | Pattern | SQL | OpenCypher | Signal Type |
|---|---------|-----|------------|-------------|
| 1 | Permission Resolution | SQL MATCH | Cypher `*1..3` | Graph |
| 2 | Shadow Admin Detection | SQL MATCH | Cypher `*1..5` | Graph |
| 3 | SOX Compliance Audit | SQL MATCH + SQL | Cypher + SQL | Graph + Time-series |
| 4 | Separation of Duties | SQL MATCH (2-step) | Cypher (2-step) | Graph |
| 5 | Dormant Access Detection | SQL MATCH + SQL | Cypher + SQL | Graph + Time-series |
| 6 | Behavioral Anomaly | SQL + vectorNeighbors | SQL (ArcadeDB-only) | Vector |
| 7 | Impact Analysis (What-If) | SQL MATCH | Cypher | Graph |

Queries 3, 5, and 6 require SQL even in the OpenCypher variant because they
access `AccessLog` (a document type outside the graph) or use `vectorNeighbors()`
(an ArcadeDB SQL function with no Cypher equivalent).

## Connectivity Matrix

| Runner | Protocol | Port | Driver |
|--------|----------|------|--------|
| `queries.sh` | HTTP API | 2480 | curl |
| `queries-cypher.sh` | HTTP API | 2480 | curl |
| `IdentityAccessManagement.java` | HTTP API | 2480 | `arcadedb-network` |
| `IamCypher.java` | Bolt + HTTP | 7687 + 2480 | `neo4j-java-driver` + `arcadedb-network` |
| `iam.py` | PostgreSQL wire | 5432 | `psycopg` |
| `iam_cypher.py` | Bolt + PostgreSQL | 7687 + 5432 | `neo4j` + `psycopg` |

## Sample Data

- 8 identities (4 employees, 2 contractors, 2 service accounts)
- 5 groups with nested memberships (Contractors → Engineering → Platform-Admins)
- 6 roles
- 6 permissions scoped to 6 resources
- 3 compliance policies (SOX, GDPR, Least-Privilege)
- 15 access log entries spanning 6 months
- 8-dimensional access pattern vectors for anomaly detection

**Engineered scenarios:**
- Bob (contractor) has shadow admin access to critical resources via 3+ nested groups
- Carol has a separation of duties violation (approve + execute on Payment-API)
- Frank has dormant access (permissions granted, no recent usage)
- Carol's access vector deviates from the department baseline (anomaly)

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.3.1**. Key notes:

- Vector similarity queries use `vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR` index
- The PostgreSQL wire protocol is enabled via `PostgresProtocolPlugin`
- The Bolt protocol is enabled via `BoltProtocolPlugin` with `-Darcadedb.bolt.defaultDatabase=IAM`
- Neo4j Java driver 6.0.3 is used for Bolt connectivity

## Reference

[ArcadeDB IAM use case](https://arcadedb.com/iam.html)
