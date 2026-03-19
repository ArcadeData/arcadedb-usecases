# IAM OpenCypher — Design & Implementation Plan

## Goal

Add OpenCypher query variants to the IAM use case across three runtimes:

| File | Protocol | Driver |
|------|----------|--------|
| `queries/queries-cypher.sh` | HTTP API (`language: "opencypher"`) | curl |
| `java/.../IamCypher.java` | Bolt (7687) | `neo4j-java-driver:6.0.3` |
| `python/iam_cypher.py` | Bolt (7687) | `neo4j` (Python) |

All 7 queries mirrored. Queries 3, 5, 6 stay SQL because they target `AccessLog` (document type, not in graph) or use `vectorNeighbors()` — these are sent via the Bolt session using `db.query("sql", ...)` in Java/Python or `language: "sql"` in shell.

## Query Translation Map

| # | Name | SQL Mechanism | Cypher Equivalent | Notes |
|---|------|---------------|-------------------|-------|
| 1 | Permission Resolution | MATCH `.out('MEMBER_OF'){while: ($depth < 3)}` | `(u)-[:MEMBER_OF*1..3]->(g)` chain | Variable-length path; needs testing |
| 2 | Shadow Admin Detection | MATCH `.out('MEMBER_OF'){while: ($depth < 5)}` | `(u)-[:MEMBER_OF*1..5]->(g)` | Same pattern |
| 3 | SOX Compliance Audit | MATCH + AccessLog SELECT | **Keep as SQL** — AccessLog is a document type | Two-step: Cypher for graph part, SQL for AccessLog |
| 4 | Separation of Duties | 2-step MATCH (approve + execute) | Two Cypher MATCH patterns | Same 2-step approach |
| 5 | Dormant Access | MATCH + AccessLog SELECT | **Keep as SQL for step 2** | Cypher for granted perms, SQL for AccessLog |
| 6 | Behavioral Anomaly | `vectorNeighbors()` | **Keep as SQL** — vectorNeighbors is ArcadeDB SQL only | Pass-through SQL |
| 7 | Impact Analysis | MATCH group→roles + MATCH group←members | Two Cypher patterns | Direct translation |

### Critical Risk: Variable-Length Paths

Memory says Cypher `*1..3` doesn't work in ArcadeDB. The website uses them extensively. Plan:
1. Test `*1..3` in step 1 (docker compose up + manual curl test)
2. If it works → use variable-length paths
3. If it doesn't → use explicit multi-hop with UNION:
   ```cypher
   MATCH (u:Identity)-[:MEMBER_OF]->(g:Group)-[:HAS_ROLE]->(r:Role)...
   UNION
   MATCH (u:Identity)-[:MEMBER_OF]->()-[:MEMBER_OF]->(g:Group)-[:HAS_ROLE]->(r:Role)...
   UNION
   MATCH (u:Identity)-[:MEMBER_OF]->()-[:MEMBER_OF]->()-[:MEMBER_OF]->(g:Group)-[:HAS_ROLE]->(r:Role)...
   ```

## Infrastructure Changes

### docker-compose.yml

Add Bolt port and plugin (alongside existing PostgreSQL plugin):

```yaml
ports:
  - "2480:2480"
  - "5432:5432"
  - "7687:7687"
environment:
  JAVA_OPTS: >-
    -Darcadedb.server.rootPassword=arcadedb
    -Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin,BoltProtocolPlugin
    -Darcadedb.bolt.defaultDatabase=IAM
```

### java/pom.xml

Add neo4j-java-driver dependency (keep existing arcadedb-network):

```xml
<neo4j.driver.version>6.0.3</neo4j.driver.version>
...
<dependency>
  <groupId>org.neo4j.driver</groupId>
  <artifactId>neo4j-java-driver</artifactId>
  <version>${neo4j.driver.version}</version>
</dependency>
```

Main class in manifest stays `IdentityAccessManagement`. The Cypher class is invoked via:
```bash
java -cp target/iam.jar com.arcadedb.examples.IamCypher
```

### python/requirements-cypher.txt

```
neo4j>=5.0,<6
```

## File Layout (after changes)

```
iam/
├── docker-compose.yml              # + Bolt port 7687, BoltProtocolPlugin
├── setup.sh                        # unchanged
├── sql/                            # unchanged
├── queries/
│   ├── queries.sh                  # unchanged (SQL)
│   └── queries-cypher.sh           # NEW — OpenCypher via HTTP API
├── java/
│   ├── pom.xml                     # + neo4j-java-driver dependency
│   └── src/main/java/com/arcadedb/examples/
│       ├── IdentityAccessManagement.java  # unchanged
│       └── IamCypher.java                 # NEW — OpenCypher via Bolt
├── python/
│   ├── iam.py                      # unchanged
│   ├── iam_cypher.py               # NEW — OpenCypher via Bolt
│   ├── requirements.txt            # unchanged (psycopg)
│   └── requirements-cypher.txt     # NEW (neo4j)
└── README.md                       # updated
```

## CI Changes

Expand matrix from `[curl, java, python]` to:
`[curl, java, python, curl-cypher, java-cypher, python-cypher]`

New conditional steps:

| Runner | Setup | Install | Run |
|--------|-------|---------|-----|
| `curl-cypher` | — | — | `./queries/queries-cypher.sh` |
| `java-cypher` | Java 21 | Maven | `mvn package && java -cp target/iam.jar com.arcadedb.examples.IamCypher` |
| `python-cypher` | Python 3.12 | `pip install -r requirements-cypher.txt` | `python iam_cypher.py` |

Java setup/cache conditions: `matrix.runner == 'java' || matrix.runner == 'java-cypher'`
Python setup/cache conditions: `matrix.runner == 'python' || matrix.runner == 'python-cypher'`

## Implementation Steps

### Step 1: Infrastructure
- [ ] Update `docker-compose.yml` — add Bolt port + plugin
- [ ] Update `java/pom.xml` — add neo4j-java-driver dependency
- [ ] Create `python/requirements-cypher.txt`
- [ ] Test Cypher variable-length paths via curl

### Step 2: Shell Script
- [ ] Create `queries/queries-cypher.sh` — 7 queries using `query "opencypher" "..."` for graph queries, `query "sql" "..."` for AccessLog/vector queries

### Step 3: Java Class
- [ ] Create `IamCypher.java` — Neo4j Bolt driver, SessionConfig.forDatabase("IAM"), 7 query methods

### Step 4: Python Script
- [ ] Create `iam_cypher.py` — neo4j Python driver, 7 query functions

### Step 5: CI & Docs
- [ ] Update `.github/workflows/iam.yml` — expand matrix, add conditions
- [ ] Update `README.md` — add OpenCypher sections, update query table
- [ ] Update CLAUDE.md if needed

### Step 6: Test
- [ ] `docker compose up -d && ./setup.sh`
- [ ] Run all 6 variants and verify output
