# Identity & Access Management (IAM)

Demonstrates ArcadeDB's multi-model capabilities by implementing an identity
and access management system that unifies three signal types in a single database:

- **Graph traversal** — permission resolution through nested group/role hierarchies
- **Time-series** — access audit logs for compliance reporting
- **Vector similarity** — behavioral anomaly detection via access pattern embeddings

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demo)
- Python 3.12+ (for the Python demo)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `IAM` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/iam.jar
```

### 3c. Run queries via Python (PostgreSQL wire protocol)

```bash
cd python
pip install -r requirements.txt
python iam.py
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

| # | Pattern | Language | Signal Type |
|---|---------|----------|-------------|
| 1 | Permission Resolution | SQL MATCH | Graph |
| 2 | Shadow Admin Detection | SQL MATCH | Graph |
| 3 | SOX Compliance Audit | SQL MATCH + SQL | Graph + Time-series |
| 4 | Separation of Duties | SQL MATCH (2-step) | Graph |
| 5 | Dormant Access Detection | SQL MATCH + SQL | Graph + Time-series |
| 6 | Behavioral Anomaly | SQL + vectorNeighbors | Vector |
| 7 | Impact Analysis (What-If) | SQL MATCH | Graph |

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

This use case targets ArcadeDB **26.3.1**. Vector similarity queries use
`vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR`
index. The PostgreSQL wire protocol is enabled via the `PostgresProtocolPlugin`.

## Reference

[ArcadeDB IAM use case](https://arcadedb.com/iam.html)
