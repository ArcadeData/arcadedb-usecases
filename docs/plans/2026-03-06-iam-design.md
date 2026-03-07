# IAM (Identity & Access Management) Use Case — Design

**Date:** 2026-03-06
**Branch:** feat/iam
**ArcadeDB version:** 26.3.1

## Overview

Implement the [ArcadeDB IAM](https://arcadedb.com/iam.html) use case demonstrating how a multi-model database handles permission resolution, privilege escalation detection, compliance auditing, and behavioral anomaly detection — all in a single database.

This is the first use case to include a **Python client** (via `psycopg` over the PostgreSQL wire protocol) alongside the standard shell (curl) and Java runners.

## Multi-Model Capabilities

| Capability | IAM Application |
|-----------|----------------|
| **Graph traversal** | Permission resolution through nested groups/roles (variable-depth paths) |
| **Time-series** | Access audit logs for compliance reporting (SOX, dormant access) |
| **Vector similarity** | Behavioral anomaly detection via access pattern embeddings |
| **Polyglot queries** | Cypher for graph traversals (shell/Java), SQL MATCH for PG protocol (Python), SQL for analytics |

## Repository Structure

```
iam/
├── docker-compose.yml          # HTTP (2480) + PostgreSQL (5432) + PG plugin
├── setup.sh                    # Standard pattern (wait, create DB, apply SQL files)
├── sql/
│   ├── 01-schema.sql
│   └── 02-data.sql
├── queries/
│   └── queries.sh              # 7 queries via curl (Cypher + SQL)
├── java/
│   ├── pom.xml                 # arcadedb-network dependency
│   └── src/main/java/com/arcadedb/examples/IdentityAccessManagement.java
├── python/
│   ├── requirements.txt        # psycopg[binary]
│   └── iam.py                  # 7 queries via PostgreSQL wire protocol
└── README.md
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.3.1`
- HTTP API port: `2480`
- PostgreSQL wire protocol port: `5432`
- Root password via `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
- PostgreSQL plugin: `-Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`
- Healthcheck: `curl -sf http://localhost:2480/api/v1/ready`, interval 5s, retries 20

## Schema (`sql/01-schema.sql`)

### Vertex Types (7)

| Type | Properties | Notes |
|------|-----------|-------|
| `Identity` | `email` (STRING, UNIQUE), `identityType` (STRING: employee/contractor/service_account), `department` (STRING), `title` (STRING), `access_pattern_vec` (LIST) | `type` avoided (reserved-ish). 8-dim vector for anomaly detection. |
| `Group` | `name` (STRING, UNIQUE), `description` (STRING) | Organizational teams |
| `Role` | `name` (STRING, UNIQUE), `description` (STRING) | Job function bundles |
| `Permission` | `action` (STRING: admin/approve/execute/read/write/deploy) | Specific actions |
| `Resource` | `name` (STRING, UNIQUE), `classification` (STRING: critical/internal/public), `data_sensitivity` (STRING), `compliance_scope` (STRING) | Systems, APIs, databases |
| `Policy` | `name` (STRING, UNIQUE), `policyType` (STRING: regulatory/operational), `description` (STRING) | Compliance rules |

### Edge Types (6)

| Type | Direction | Notes |
|------|-----------|-------|
| `MEMBER_OF` | Identity → Group | Group membership |
| `HAS_ROLE` | Group → Role, Identity → Role | Role assignment (direct or via group) |
| `GRANTS` | Role → Permission | Role bundles permissions |
| `APPLIES_TO` | Permission → Resource | Permission scoped to resource |
| `INHERITS_FROM` | Role → Role | Role hierarchy (child inherits parent perms) |
| `GOVERNED_BY` | Resource → Policy | Compliance governance (used in audit query) |

### Document Type (1)

| Type | Properties | Notes |
|------|-----------|-------|
| `AccessLog` | `identityEmail` (STRING), `resourceName` (STRING), `action` (STRING), `source_ip` (STRING), `recordedAt` (DATETIME) | Time-series audit trail. `timestamp` is reserved — use `recordedAt`. DATETIME format: `'YYYY-MM-DD HH:MM:SS'`. |

### Indexes

```sql
CREATE INDEX ON Identity (email) UNIQUE
CREATE INDEX ON Group (name) UNIQUE
CREATE INDEX ON Role (name) UNIQUE
CREATE INDEX ON Resource (name) UNIQUE
CREATE INDEX ON Policy (name) UNIQUE
CREATE INDEX ON Identity (access_pattern_vec) LSM_VECTOR METADATA { dimensions: 8, similarity: 'COSINE' }
```

## Sample Data (`sql/02-data.sql`)

### Identities (8)

| Email | Type | Department | Notes |
|-------|------|-----------|-------|
| alice@company.com | employee | Engineering | Legitimate developer access |
| bob@company.com | contractor | External | Shadow admin via deep nesting |
| carol@company.com | employee | Finance | SoD violation (approve + execute) |
| dave@company.com | employee | Security | Security team, auditor role |
| eve@company.com | employee | Engineering | Platform admin |
| svc-deploy@company.com | service_account | Engineering | CI/CD service account |
| svc-backup@company.com | service_account | Operations | Backup service |
| frank@company.com | contractor | External | Minimal access, dormant |

### Groups (5)

| Name | Description |
|------|-------------|
| Engineering | Engineering department |
| Platform-Admins | Infrastructure administrators |
| Finance | Finance department |
| Security | Security operations |
| Contractors | External contractors |

### Roles (6)

| Name | Description |
|------|-------------|
| Admin | Full administrative access |
| Developer | Development read/write access |
| Auditor | Read-only compliance auditing |
| Approver | Financial approval authority |
| Executor | Financial execution authority |
| Viewer | Read-only basic access |

### Permissions (6)

| Action |
|--------|
| admin |
| approve |
| execute |
| read |
| write |
| deploy |

### Resources (6)

| Name | Classification | Sensitivity | Compliance |
|------|---------------|-------------|-----------|
| Production-DB | critical | high | SOX |
| Payment-API | critical | high | SOX |
| Customer-Data | critical | high | GDPR |
| CI-Pipeline | internal | medium | — |
| Audit-System | internal | medium | SOX |
| Internal-Wiki | public | low | — |

### Policies (3)

| Name | Type | Description |
|------|------|-------------|
| SOX-Compliance | regulatory | Sarbanes-Oxley financial controls |
| Data-Privacy | regulatory | GDPR data protection requirements |
| Least-Privilege | operational | Minimum necessary access policy |

### Key Data Relationships (engineered for query results)

**Permission chains:**
- Alice → Engineering → Developer → (read, write) → Production-DB *(legitimate, 3 hops)*
- Bob → Contractors → Engineering → Platform-Admins → Admin → admin → Production-DB *(shadow admin, 5+ hops)*
- Carol → Finance → Approver → approve → Payment-API *(one path)*
- Carol → Finance → Executor → execute → Payment-API *(second path → SoD violation)*
- Eve → Platform-Admins → Admin → admin → Production-DB *(legitimate admin)*
- svc-deploy → (direct) HAS_ROLE → Developer → deploy → CI-Pipeline

**Role inheritance:**
- Admin INHERITS_FROM Developer (Admin inherits all Developer permissions)

**Governance:**
- Production-DB GOVERNED_BY SOX-Compliance
- Payment-API GOVERNED_BY SOX-Compliance
- Customer-Data GOVERNED_BY Data-Privacy

**AccessLog entries (~15):**
- Recent logs for alice, carol, dave, eve, svc-deploy (active users)
- No recent logs for frank@company.com (dormant access detection)
- Timestamps spanning 2025-12-01 through 2026-03-06

**Vectors (8-dimensional access pattern embeddings):**
- Employees in same department get similar vectors
- Carol gets a deviant vector to trigger anomaly detection

## Query Patterns (7)

### Query 1: Permission Resolution

Find all resources alice@company.com can access through any chain of group memberships, roles, and permissions.

**Shell/Java (Cypher):**
```cypher
MATCH (u:Identity {email: 'alice@company.com'})
      -[:MEMBER_OF*1..3]->(g:Group)
      -[:HAS_ROLE]->(r:Role)
      -[:GRANTS]->(p:Permission)
      -[:APPLIES_TO]->(res:Resource)
RETURN res.name AS resource, p.action AS action,
       r.name AS via_role, g.name AS via_group
ORDER BY resource, action
```

**Python (SQL MATCH):**
```sql
SELECT resource, action, via_role, via_group
FROM (
  MATCH {type: Identity, where: (email = 'alice@company.com')}
        .out('MEMBER_OF'){as: g, while: ($depth < 3)}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){as: p}
        .out('APPLIES_TO'){as: res}
  RETURN res.name AS resource, p.action AS action,
         r.name AS via_role, g.name AS via_group
)
ORDER BY resource, action
```

**Signal type:** Graph (multi-hop traversal)

### Query 2: Shadow Admin Detection

Find contractors or service accounts that have admin access to critical resources through deeply nested group memberships.

**Shell/Java (Cypher):**
```cypher
MATCH (u:Identity)
      -[:MEMBER_OF*1..5]->(g:Group)
      -[:HAS_ROLE]->(r:Role)
      -[:GRANTS]->(p:Permission {action: 'admin'})
      -[:APPLIES_TO]->(res:Resource {classification: 'critical'})
WHERE u.identityType IN ['contractor', 'service_account']
RETURN u.email AS identity, u.identityType AS identity_type,
       res.name AS critical_resource, r.name AS via_role
ORDER BY identity
```

**Python (SQL MATCH):**
```sql
SELECT identity, identity_type, critical_resource, via_role
FROM (
  MATCH {type: Identity, where: (identityType IN ['contractor', 'service_account']), as: u}
        .out('MEMBER_OF'){while: ($depth < 5)}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){as: p, where: (action = 'admin')}
        .out('APPLIES_TO'){as: res, where: (classification = 'critical')}
  RETURN u.email AS identity, u.identityType AS identity_type,
         res.name AS critical_resource, r.name AS via_role
)
ORDER BY identity
```

**Signal type:** Graph (deep traversal, security audit)

### Query 3: SOX Compliance Audit

Track access to SOX-governed resources, joining AccessLog time-series with the governance graph (Resource → GOVERNED_BY → Policy).

**Language:** SQL (all runners)
```sql
SELECT al.identityEmail AS identity, al.action,
       res.name AS resource, pol.name AS policy,
       al.recordedAt, al.source_ip
FROM AccessLog AS al
  JOIN Resource AS res ON al.resourceName = res.name
  JOIN GOVERNED_BY AS gb ON gb.@out = res.@rid
  JOIN Policy AS pol ON gb.@in = pol.@rid
WHERE pol.name = 'SOX-Compliance'
  AND al.recordedAt > '2025-12-01 00:00:00'
ORDER BY al.recordedAt DESC
```

> **Note:** If JOIN on edge `@out`/`@in` doesn't work in 26.3.1, fall back to a SQL MATCH approach:
> ```sql
> SELECT identity, action, resource, policy, recordedAt, source_ip
> FROM (
>   MATCH {type: Resource, as: res}
>         .out('GOVERNED_BY'){as: pol, where: (name = 'SOX-Compliance')}
>   RETURN res.name AS resource, pol.name AS policy
> ) AS gov
> JOIN AccessLog AS al ON al.resourceName = gov.resource
> WHERE al.recordedAt > '2025-12-01 00:00:00'
> ORDER BY al.recordedAt DESC
> ```
>
> If that also fails, use a two-step approach: first get SOX-governed resource names, then filter AccessLog.

**Signal type:** Time-series + Graph (governance)

### Query 4: Separation of Duties Violation

Find identities who can both approve AND execute on the same resource (through any path).

**Shell/Java (Cypher):**
```cypher
MATCH (u:Identity)
      -[:MEMBER_OF*1..3]->(g1:Group)
      -[:HAS_ROLE]->(r1:Role)
      -[:GRANTS]->(p1:Permission {action: 'approve'})
      -[:APPLIES_TO]->(res:Resource),
      (u)-[:MEMBER_OF*1..3]->(g2:Group)
      -[:HAS_ROLE]->(r2:Role)
      -[:GRANTS]->(p2:Permission {action: 'execute'})
      -[:APPLIES_TO]->(res)
RETURN u.email AS identity, res.name AS resource,
       r1.name AS approve_role, r2.name AS execute_role
```

**Python (SQL MATCH):** Two separate queries, one for approve paths and one for execute paths, then intersect in Python (dual MATCH in a single SQL statement may not work in 26.3.1).

**Signal type:** Graph (dual-path detection)

### Query 5: Dormant Access Detection

Find identities with granted permissions but no AccessLog entries in the last 90 days.

**Language:** SQL (all runners) — two-step approach
```sql
-- Step 1: Get all identities with any permission grant
SELECT DISTINCT identity, resource
FROM (
  MATCH {type: Identity, as: u}
        .out('MEMBER_OF'){while: ($depth < 3)}
        .out('HAS_ROLE'){}
        .out('GRANTS'){}
        .out('APPLIES_TO'){as: res}
  RETURN u.email AS identity, res.name AS resource
)

-- Step 2: Get identities with recent access
SELECT DISTINCT identityEmail FROM AccessLog
WHERE recordedAt > '2025-12-06 00:00:00'
```

Then subtract Step 2 from Step 1 in the client (shell/Java/Python). If subquery NOT IN works:
```sql
SELECT DISTINCT identity, resource
FROM (
  MATCH {type: Identity, as: u}
        .out('MEMBER_OF'){while: ($depth < 3)}
        .out('HAS_ROLE'){}
        .out('GRANTS'){}
        .out('APPLIES_TO'){as: res}
  RETURN u.email AS identity, res.name AS resource
)
WHERE identity NOT IN (
  SELECT DISTINCT identityEmail FROM AccessLog
  WHERE recordedAt > '2025-12-06 00:00:00'
)
```

**Signal type:** Graph + Time-series

### Query 6: Behavioral Anomaly Detection

Find identities whose current access pattern vector deviates from a given "normal" session vector.

**Language:** SQL (all runners)
```sql
SELECT email, department, identityType
FROM Identity
WHERE identityType = 'employee'
ORDER BY vectorNeighbors('Identity[access_pattern_vec]', [0.5, 0.5, 0.3, 0.1, 0.2, 0.1, 0.1, 0.1], 10) DESC
LIMIT 10
```

And a second query to find the "outlier" (Carol) — the employee whose vector is most distant from the department norm. This uses vectorNeighbors to rank Engineering employees by similarity to the Engineering centroid, showing Carol as the outlier.

**Signal type:** Vector similarity

### Query 7: Impact Analysis (What-If)

Predict consequences of removing the Platform-Admins group — which identities would lose which permissions on which resources?

**Shell/Java (Cypher):**
```cypher
MATCH (u:Identity)
      -[:MEMBER_OF*1..3]->(target:Group {name: 'Platform-Admins'})
      -[:HAS_ROLE]->(r:Role)
      -[:GRANTS]->(p:Permission)
      -[:APPLIES_TO]->(res:Resource)
RETURN u.email AS identity, r.name AS role,
       p.action AS action, res.name AS resource
ORDER BY identity, resource
```

**Python (SQL MATCH):**
```sql
SELECT identity, role, action, resource
FROM (
  MATCH {type: Identity, as: u}
        .out('MEMBER_OF'){while: ($depth < 3), where: (name = 'Platform-Admins')}{as: target}
        .out('HAS_ROLE'){as: r}
        .out('GRANTS'){as: p}
        .out('APPLIES_TO'){as: res}
  RETURN u.email AS identity, r.name AS role,
         p.action AS action, res.name AS resource
)
ORDER BY identity, resource
```

**Signal type:** Graph (dependency analysis)

## Query Language Mapping

| # | Pattern | Shell/Java | Python (PG) | Signal |
|---|---------|-----------|-------------|--------|
| 1 | Permission Resolution | Cypher | SQL MATCH | Graph |
| 2 | Shadow Admin Detection | Cypher | SQL MATCH | Graph |
| 3 | SOX Compliance Audit | SQL | SQL | Time-series + Graph |
| 4 | Separation of Duties | Cypher | SQL MATCH (2-step) | Graph |
| 5 | Dormant Access Detection | SQL | SQL | Graph + Time-series |
| 6 | Behavioral Anomaly | SQL | SQL | Vector |
| 7 | Impact Analysis | Cypher | SQL MATCH | Graph |

## Java Program

- **Class:** `com.arcadedb.examples.IdentityAccessManagement`
- **Dependency:** `com.arcadedb:arcadedb-network:26.3.1`
- **Pattern:** `tryRun()`/`printHeader()` per existing convention
- Queries use `db.query("cypher", ...)` for graph queries, `db.query("sql", ...)` for SQL queries
- Fat JAR via `maven-assembly-plugin`, `finalName=iam`

## Python Program

- **File:** `python/iam.py`
- **Dependency:** `psycopg[binary]` (psycopg3, synchronous)
- **Connection:** `psycopg.connect(host, port=5432, dbname='IAM', user, password, autocommit=True)`
- **Pattern:** `try_run()`/`print_header()` helpers matching the Java convention
- All graph queries use SQL MATCH (Cypher not available over PG protocol)
- Named parameters via `%(name)s` syntax where applicable

## CI Workflow

**File:** `.github/workflows/iam.yml`

Three-runner matrix: `[curl, java, python]`

Steps per runner:
- **curl:** `./queries/queries.sh`
- **java:** `mvn package --no-transfer-progress && java -jar target/iam.jar`
- **python:** `pip install -r python/requirements.txt && python python/iam.py`

## Success Criteria

1. `docker compose up` starts ArcadeDB with PostgreSQL plugin enabled
2. SQL files apply cleanly via `setup.sh` with no errors
3. `queries.sh` runs all 7 queries and returns non-empty result sets
4. Java program runs all 7 queries and prints results to stdout
5. Python program connects via PG protocol and runs all 7 queries
6. Shadow admin detection finds bob@company.com (contractor with admin on critical resource)
7. SoD violation detection finds carol@company.com (approve + execute on Payment-API)
8. Dormant access detection finds frank@company.com (no recent AccessLog)
9. Vector anomaly query returns ranked identities by similarity
