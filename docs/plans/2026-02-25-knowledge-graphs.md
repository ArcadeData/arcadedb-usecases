# Knowledge Graphs Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a self-contained `knowledge-graphs/` use case that demonstrates ArcadeDB's four multi-model pillars (graph, vector, full-text, time-series) using an academic research domain.

**Architecture:** Mirror the `recommendation-engine/` structure exactly — `docker-compose.yml`, `setup.sh`, `sql/`, `queries/queries.sh`, and a standalone Maven fat JAR. Five labeled curl queries each target one or two ArcadeDB capability pillars. The Java program runs the same five queries via `RemoteDatabase`.

**Tech Stack:** ArcadeDB 26.2.1, SQL + Cypher query languages, Maven 3.x + Java 21, `arcadedb-network:26.2.1`

---

## Reference: recommendation-engine structure

Before touching any file, understand the pattern you are mirroring:

```
recommendation-engine/
├── docker-compose.yml       ← single arcadedb service, port 2480
├── setup.sh                 ← waits for ArcadeDB, creates DB, applies sql/ files
├── sql/01-schema.sql        ← one statement per line, no semicolons at end
├── sql/02-data.sql          ← inserts + CREATE EDGE statements
├── queries/queries.sh       ← 5 sections, each calls query() helper
└── java/
    ├── pom.xml              ← maven-assembly-plugin fat JAR, mainClass
    └── src/main/java/com/arcadedb/examples/RecommendationEngine.java
```

The setup.sh `apply_file()` helper reads the SQL file **one line at a time** and strips trailing semicolons before sending each statement to the HTTP API. This means **each SQL statement must be on one line** in the `.sql` files.

---

## Task 1: Create directory skeleton

**Files:**
- Create directory: `knowledge-graphs/`
- Create directory: `knowledge-graphs/sql/`
- Create directory: `knowledge-graphs/queries/`
- Create directory: `knowledge-graphs/java/src/main/java/com/arcadedb/examples/`

**Step 1: Create all directories**

```bash
mkdir -p knowledge-graphs/sql \
         knowledge-graphs/queries \
         knowledge-graphs/java/src/main/java/com/arcadedb/examples
```

**Step 2: Verify**

```bash
find knowledge-graphs -type d
```

Expected output:
```
knowledge-graphs
knowledge-graphs/sql
knowledge-graphs/queries
knowledge-graphs/java
knowledge-graphs/java/src
knowledge-graphs/java/src/main
knowledge-graphs/java/src/main/java
knowledge-graphs/java/src/main/java/com
knowledge-graphs/java/src/main/java/com/arcadedb
knowledge-graphs/java/src/main/java/com/arcadedb/examples
```

**Step 3: Commit**

```bash
git add knowledge-graphs/
git commit -m "feat: scaffold knowledge-graphs directory structure"
```

---

## Task 2: docker-compose.yml

**Files:**
- Create: `knowledge-graphs/docker-compose.yml`

**Step 1: Create the file**

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.2.1
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

**Step 2: Verify it is identical in structure to recommendation-engine/docker-compose.yml**

```bash
diff knowledge-graphs/docker-compose.yml recommendation-engine/docker-compose.yml
```

Only difference should be none (files are identical in structure).

**Step 3: Commit**

```bash
git add knowledge-graphs/docker-compose.yml
git commit -m "feat: add knowledge-graphs docker-compose"
```

---

## Task 3: setup.sh

**Files:**
- Create: `knowledge-graphs/setup.sh`

**Step 1: Create the file**

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="KnowledgeGraph"

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

**Step 2: Make it executable**

```bash
chmod +x knowledge-graphs/setup.sh
```

**Step 3: Commit**

```bash
git add knowledge-graphs/setup.sh
git commit -m "feat: add knowledge-graphs setup script"
```

---

## Task 4: sql/01-schema.sql

**Files:**
- Create: `knowledge-graphs/sql/01-schema.sql`

**Important:** One statement per line. No blank lines between statements (comments are allowed). No trailing semicolons needed — `setup.sh` strips them, but you may include them for readability.

**Step 1: Create the schema file**

```sql
CREATE VERTEX TYPE Researcher IF NOT EXISTS
CREATE PROPERTY Researcher.id IF NOT EXISTS STRING
CREATE PROPERTY Researcher.name IF NOT EXISTS STRING
CREATE PROPERTY Researcher.embedding IF NOT EXISTS LIST
CREATE INDEX IF NOT EXISTS ON Researcher (id) UNIQUE
CREATE VERTEX TYPE Institution IF NOT EXISTS
CREATE PROPERTY Institution.id IF NOT EXISTS STRING
CREATE PROPERTY Institution.name IF NOT EXISTS STRING
CREATE INDEX IF NOT EXISTS ON Institution (id) UNIQUE
CREATE VERTEX TYPE Topic IF NOT EXISTS
CREATE PROPERTY Topic.id IF NOT EXISTS STRING
CREATE PROPERTY Topic.name IF NOT EXISTS STRING
CREATE PROPERTY Topic.embedding IF NOT EXISTS LIST
CREATE INDEX IF NOT EXISTS ON Topic (id) UNIQUE
CREATE VERTEX TYPE Paper IF NOT EXISTS
CREATE PROPERTY Paper.id IF NOT EXISTS STRING
CREATE PROPERTY Paper.title IF NOT EXISTS STRING
CREATE PROPERTY Paper.abstract IF NOT EXISTS STRING
CREATE PROPERTY Paper.year IF NOT EXISTS INTEGER
CREATE PROPERTY Paper.embedding IF NOT EXISTS LIST
CREATE INDEX IF NOT EXISTS ON Paper (id) UNIQUE
CREATE EDGE TYPE CO_AUTHORED IF NOT EXISTS
CREATE EDGE TYPE CITES IF NOT EXISTS
CREATE EDGE TYPE COVERS IF NOT EXISTS
CREATE EDGE TYPE AFFILIATED_WITH IF NOT EXISTS
CREATE DOCUMENT TYPE PaperActivity IF NOT EXISTS
CREATE PROPERTY PaperActivity.paperId IF NOT EXISTS STRING
CREATE PROPERTY PaperActivity.citationCount IF NOT EXISTS LONG
CREATE PROPERTY PaperActivity.ts IF NOT EXISTS DATETIME
CREATE INDEX IF NOT EXISTS ON Paper (embedding) LSM_VECTOR METADATA { dimensions: 4, similarity: 'COSINE' }
CREATE INDEX IF NOT EXISTS ON Topic (embedding) LSM_VECTOR METADATA { dimensions: 4, similarity: 'COSINE' }
CREATE INDEX IF NOT EXISTS ON Paper (abstract) FULL_TEXT
```

**Step 2: Count lines to confirm 28 statements**

```bash
grep -c . knowledge-graphs/sql/01-schema.sql
```

Expected: `28`

**Step 3: Commit**

```bash
git add knowledge-graphs/sql/01-schema.sql
git commit -m "feat: add knowledge-graphs schema"
```

---

## Task 5: sql/02-data.sql

**Files:**
- Create: `knowledge-graphs/sql/02-data.sql`

**Important:** One statement per line. CREATE EDGE statements use subselects to look up vertices by `id`. The edge overlap is deliberate — r1 and r5 co-authored p1, so Query 1 will return r5 as a co-author of r1 and expose r5's other papers (p3, p10).

**Step 1: Create the data file**

```sql
-- Institutions
INSERT INTO Institution SET id = 'i1', name = 'MIT'
INSERT INTO Institution SET id = 'i2', name = 'Stanford'
INSERT INTO Institution SET id = 'i3', name = 'Oxford'
INSERT INTO Institution SET id = 'i4', name = 'ETH Zurich'
-- Researchers
INSERT INTO Researcher SET id = 'r1', name = 'Alice Chen', embedding = [0.9, 0.1, 0.1, 0.1]
INSERT INTO Researcher SET id = 'r2', name = 'Bob Kim', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Researcher SET id = 'r3', name = 'Carol Davis', embedding = [0.1, 0.9, 0.1, 0.1]
INSERT INTO Researcher SET id = 'r4', name = 'David Lee', embedding = [0.1, 0.1, 0.9, 0.1]
INSERT INTO Researcher SET id = 'r5', name = 'Eve Patel', embedding = [0.5, 0.5, 0.1, 0.1]
-- Topics
INSERT INTO Topic SET id = 't1', name = 'Distributed Systems', embedding = [0.9, 0.1, 0.1, 0.1]
INSERT INTO Topic SET id = 't2', name = 'Machine Learning', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Topic SET id = 't3', name = 'Graph Databases', embedding = [0.7, 0.3, 0.1, 0.1]
INSERT INTO Topic SET id = 't4', name = 'Bioinformatics', embedding = [0.1, 0.9, 0.1, 0.1]
INSERT INTO Topic SET id = 't5', name = 'Quantum Computing', embedding = [0.1, 0.1, 0.9, 0.1]
INSERT INTO Topic SET id = 't6', name = 'Knowledge Graphs', embedding = [0.6, 0.4, 0.1, 0.1]
-- Papers
INSERT INTO Paper SET id = 'p1', year = 2021, title = 'Consensus Algorithms in Distributed Systems', abstract = 'This paper surveys consensus algorithms for distributed systems including Paxos and Raft protocols for fault-tolerant replication.', embedding = [0.9, 0.1, 0.1, 0.1]
INSERT INTO Paper SET id = 'p2', year = 2022, title = 'Graph Neural Networks for Knowledge Representation', abstract = 'We present graph neural network architectures for knowledge graph embedding, reasoning, and link prediction at scale.', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Paper SET id = 'p3', year = 2022, title = 'Vector Databases and Approximate Nearest Neighbor Search', abstract = 'A comparative study of vector database systems supporting approximate nearest neighbor search and embedding retrieval at scale.', embedding = [0.7, 0.3, 0.1, 0.1]
INSERT INTO Paper SET id = 'p4', year = 2023, title = 'Multi-Model Databases for Complex Applications', abstract = 'We analyze multi-model database systems that unify graph, document, and vector storage without impedance mismatch.', embedding = [0.8, 0.1, 0.2, 0.1]
INSERT INTO Paper SET id = 'p5', year = 2022, title = 'Federated Learning over Graph-Structured Data', abstract = 'Federated learning methods applied to distributed graph-structured datasets across privacy-preserving node partitions.', embedding = [0.7, 0.2, 0.2, 0.1]
INSERT INTO Paper SET id = 'p6', year = 2021, title = 'Protein-Protein Interaction Networks', abstract = 'A graph-based analysis of protein-protein interaction networks reveals functional modules in cellular biology.', embedding = [0.1, 0.9, 0.1, 0.1]
INSERT INTO Paper SET id = 'p7', year = 2023, title = 'Quantum Entanglement in Noisy Systems', abstract = 'Studying quantum entanglement and coherence properties under realistic noise conditions using density matrix formalism.', embedding = [0.1, 0.1, 0.9, 0.1]
INSERT INTO Paper SET id = 'p8', year = 2023, title = 'Knowledge Graph Completion with Embeddings', abstract = 'Embedding-based methods for knowledge graph completion enable scalable link prediction and relation inference tasks.', embedding = [0.8, 0.2, 0.1, 0.1]
INSERT INTO Paper SET id = 'p9', year = 2023, title = 'Distributed Consensus for Blockchain Networks', abstract = 'Consensus mechanisms designed for permissioned blockchain networks with Byzantine fault tolerance guarantees.', embedding = [0.9, 0.1, 0.1, 0.2]
INSERT INTO Paper SET id = 'p10', year = 2024, title = 'RAG Systems with Knowledge Graph Augmentation', abstract = 'Retrieval-augmented generation combined with knowledge graph traversal improves factual accuracy by 2.8x over vector-only retrieval.', embedding = [0.7, 0.3, 0.1, 0.1]
-- AFFILIATED_WITH edges (Researcher -> Institution)
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Institution WHERE id = 'i1')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Institution WHERE id = 'i2')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r3') TO (SELECT FROM Institution WHERE id = 'i1')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r4') TO (SELECT FROM Institution WHERE id = 'i3')
CREATE EDGE AFFILIATED_WITH FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Institution WHERE id = 'i2')
-- CO_AUTHORED edges (Researcher -> Paper) — r1 and r5 both authored p1 (deliberate overlap for Query 1)
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Paper WHERE id = 'p4')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r1') TO (SELECT FROM Paper WHERE id = 'p9')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Paper WHERE id = 'p5')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r2') TO (SELECT FROM Paper WHERE id = 'p8')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r3') TO (SELECT FROM Paper WHERE id = 'p6')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r4') TO (SELECT FROM Paper WHERE id = 'p7')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CO_AUTHORED FROM (SELECT FROM Researcher WHERE id = 'r5') TO (SELECT FROM Paper WHERE id = 'p10')
-- CITES edges (Paper -> Paper) — creates citation graph for GraphRAG (Query 5)
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p2') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p3') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p5') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p8') TO (SELECT FROM Paper WHERE id = 'p2')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p8') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p9') TO (SELECT FROM Paper WHERE id = 'p1')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Paper WHERE id = 'p3')
CREATE EDGE CITES FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Paper WHERE id = 'p8')
-- COVERS edges (Paper -> Topic)
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p1') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p2') TO (SELECT FROM Topic WHERE id = 't2')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p2') TO (SELECT FROM Topic WHERE id = 't6')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p3') TO (SELECT FROM Topic WHERE id = 't3')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p3') TO (SELECT FROM Topic WHERE id = 't2')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Topic WHERE id = 't3')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p4') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p5') TO (SELECT FROM Topic WHERE id = 't2')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p5') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p6') TO (SELECT FROM Topic WHERE id = 't4')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p7') TO (SELECT FROM Topic WHERE id = 't5')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p8') TO (SELECT FROM Topic WHERE id = 't6')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p9') TO (SELECT FROM Topic WHERE id = 't1')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Topic WHERE id = 't6')
CREATE EDGE COVERS FROM (SELECT FROM Paper WHERE id = 'p10') TO (SELECT FROM Topic WHERE id = 't2')
-- PaperActivity documents for trending query (varied counts so results are ordered meaningfully)
INSERT INTO PaperActivity SET paperId = 'p1', citationCount = 15, ts = date()
INSERT INTO PaperActivity SET paperId = 'p2', citationCount = 22, ts = date()
INSERT INTO PaperActivity SET paperId = 'p3', citationCount = 18, ts = date()
INSERT INTO PaperActivity SET paperId = 'p8', citationCount = 30, ts = date()
INSERT INTO PaperActivity SET paperId = 'p10', citationCount = 25, ts = date()
INSERT INTO PaperActivity SET paperId = 'p1', citationCount = 8, ts = date()
INSERT INTO PaperActivity SET paperId = 'p2', citationCount = 10, ts = date()
INSERT INTO PaperActivity SET paperId = 'p9', citationCount = 12, ts = date()
INSERT INTO PaperActivity SET paperId = 'p3', citationCount = 7, ts = date()
INSERT INTO PaperActivity SET paperId = 'p5', citationCount = 5, ts = date()
```

**Step 2: Verify line count**

```bash
grep -c . knowledge-graphs/sql/02-data.sql
```

Expected: approximately 80 lines (comments + data statements).

**Step 3: Commit**

```bash
git add knowledge-graphs/sql/02-data.sql
git commit -m "feat: add knowledge-graphs sample data"
```

---

## Task 6: queries/queries.sh

**Files:**
- Create: `knowledge-graphs/queries/queries.sh`

**Step 1: Create the queries file**

Understand the expected results before writing queries:
- **Q1 (Cypher):** r1 (Alice) co-authored p1 with r5 (Eve). Eve also authored p3 and p10 → they appear as 2-hop connections.
- **Q2 (SQL vector):** Query vector `[0.8, 0.2, 0.1, 0.1]` is closest to p2, p8, p4 embeddings.
- **Q3 (SQL full-text):** Papers with "distributed" in abstract: p1, p4, p5, p9 (and p10 mentions "retrieval").
- **Q4 (SQL time-series):** p8 has 30 citations total, p10 has 25, p2 has 32 (22+10).
- **Q5 (SQL GraphRAG):** Seed papers by vector similarity → expand via CITES → COVERS → topics. Seeds around `[0.8, 0.2, 0.1, 0.1]` are p2, p8, p4. Their cited papers cover t1, t2, t3, t6.

```bash
#!/usr/bin/env bash
# Knowledge Graph — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="KnowledgeGraph"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Co-authorship Network (Graph Traversal) ==="
echo "Find researchers reachable from Alice (r1) within 2 co-authorship hops."
echo ""
query "cypher" "
MATCH (me:Researcher {id: 'r1'})
      -[:CO_AUTHORED]->(p:Paper)
      <-[:CO_AUTHORED]-(colleague:Researcher)
      -[:CO_AUTHORED]->(collab:Paper)
WHERE colleague.id <> 'r1'
  AND NOT (me)-[:CO_AUTHORED]->(collab)
RETURN colleague.name, collab.title, count(DISTINCT p) AS shared_papers
ORDER BY shared_papers DESC LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Semantic Paper Search (Vector Similarity) ==="
echo "Find papers semantically similar to the embedding [0.8, 0.2, 0.1, 0.1]."
echo ""
query "sql" "
SELECT id, title, year
FROM Paper
ORDER BY vectorNeighbors('Paper[embedding]', [0.8, 0.2, 0.1, 0.1], 10) DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Full-Text Abstract Search ==="
echo "Find papers whose abstract mentions 'distributed' and 'consensus'."
echo ""
query "sql" "
SELECT id, title, year
FROM Paper
WHERE SEARCH_CLASS('distributed AND consensus') = true
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Trending Papers (Time-Series) ==="
echo "Rank papers by cumulative citation activity."
echo ""
query "sql" "
SELECT paperId, sum(citationCount) AS totalCitations
FROM PaperActivity
GROUP BY paperId
ORDER BY totalCitations DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: GraphRAG Hybrid (Vector Seed + Citation Expansion) ==="
echo "Find topics reachable via citation graph from papers most similar to [0.8, 0.2, 0.1, 0.1]."
echo ""
query "sql" "
SELECT topic.name AS topic, count(*) AS connections
FROM (
  MATCH {type: Paper, where: (id IN (SELECT id FROM Paper ORDER BY vectorNeighbors('Paper[embedding]', [0.8, 0.2, 0.1, 0.1], 3) DESC LIMIT 3))}
        .out('CITES'){as: cited}
        .out('COVERS'){as: topic}
  RETURN topic
)
GROUP BY topic
ORDER BY connections DESC
LIMIT 5
"
```

**Step 2: Make it executable**

```bash
chmod +x knowledge-graphs/queries/queries.sh
```

**Step 3: Note on Query 5 (GraphRAG)**

If the MATCH subquery in Query 5 fails because ArcadeDB does not support a `SELECT` subquery inside the MATCH `where` clause, use this alternative that hardcodes the top-3 seed paper IDs (p2, p8, p4 — closest to `[0.8, 0.2, 0.1, 0.1]`):

```sql
SELECT topic.name AS topic, count(*) AS connections
FROM (
  MATCH {type: Paper, where: (id IN ['p2', 'p8', 'p4'])}
        .out('CITES'){as: cited}
        .out('COVERS'){as: topic}
  RETURN topic
)
GROUP BY topic
ORDER BY connections DESC
LIMIT 5
```

**Step 4: Commit**

```bash
git add knowledge-graphs/queries/queries.sh
git commit -m "feat: add knowledge-graphs curl queries"
```

---

## Task 7: java/pom.xml

**Files:**
- Create: `knowledge-graphs/java/pom.xml`

**Step 1: Create the pom.xml** (adapted from `recommendation-engine/java/pom.xml` — only `artifactId`, `finalName`, and `mainClass` change)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.arcadedb.examples</groupId>
  <artifactId>knowledge-graph</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <arcadedb.version>26.2.1</arcadedb.version>
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
              <mainClass>com.arcadedb.examples.KnowledgeGraph</mainClass>
            </manifest>
          </archive>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <finalName>knowledge-graph</finalName>
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
git add knowledge-graphs/java/pom.xml
git commit -m "feat: add knowledge-graphs maven pom"
```

---

## Task 8: KnowledgeGraph.java

**Files:**
- Create: `knowledge-graphs/java/src/main/java/com/arcadedb/examples/KnowledgeGraph.java`

**Step 1: Create the Java file**

The queries are identical to the shell script. The `tryRun()` / `printHeader()` pattern is taken verbatim from `RecommendationEngine.java`.

```java
package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class KnowledgeGraph {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "KnowledgeGraph";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1CoauthorshipNetwork(db), "Query 1");
      tryRun(() -> runQuery2SemanticSearch(db), "Query 2");
      tryRun(() -> runQuery3FullTextSearch(db), "Query 3");
      tryRun(() -> runQuery4TrendingPapers(db), "Query 4");
      tryRun(() -> runQuery5GraphRag(db), "Query 5");
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

  // Query 1: Co-authorship Network — Graph Traversal (Cypher)
  private static void runQuery1CoauthorshipNetwork(RemoteDatabase db) {
    printHeader("Query 1: Co-authorship Network (Graph Traversal)",
        "Find researchers reachable from Alice (r1) within 2 co-authorship hops.");

    String cypher =
        """
            MATCH (me:Researcher {id: 'r1'})
                  -[:CO_AUTHORED]->(p:Paper)
                  <-[:CO_AUTHORED]-(colleague:Researcher)
                  -[:CO_AUTHORED]->(collab:Paper)
             WHERE colleague.id <> 'r1'
               AND NOT (me)-[:CO_AUTHORED]->(collab)
             RETURN colleague.name, collab.title, count(DISTINCT p) AS shared_papers
             ORDER BY shared_papers DESC LIMIT 10""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-50s | shared: %s%n",
            r.getProperty("colleague.name"),
            r.getProperty("collab.title"),
            r.getProperty("shared_papers"));
      }
    }
  }

  // Query 2: Semantic Paper Search — Vector Similarity (SQL)
  private static void runQuery2SemanticSearch(RemoteDatabase db) {
    printHeader("Query 2: Semantic Paper Search (Vector Similarity)",
        "Find papers semantically similar to the embedding [0.8, 0.2, 0.1, 0.1].");

    String sql =
        """
            SELECT id, title, year
             FROM Paper
             ORDER BY vectorNeighbors('Paper[embedding]', [0.8, 0.2, 0.1, 0.1], 10) DESC
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s | %d | %s%n",
            r.getProperty("id"),
            ((Number) r.getProperty("year")).intValue(),
            r.getProperty("title"));
      }
    }
  }

  // Query 3: Full-Text Abstract Search (SQL + FULL_TEXT index)
  private static void runQuery3FullTextSearch(RemoteDatabase db) {
    printHeader("Query 3: Full-Text Abstract Search",
        "Find papers whose abstract mentions 'distributed' and 'consensus'.");

    String sql =
        """
            SELECT id, title, year
             FROM Paper
             WHERE SEARCH_CLASS('distributed AND consensus') = true
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s | %d | %s%n",
            r.getProperty("id"),
            ((Number) r.getProperty("year")).intValue(),
            r.getProperty("title"));
      }
    }
  }

  // Query 4: Trending Papers — Time-Series Aggregation (SQL)
  private static void runQuery4TrendingPapers(RemoteDatabase db) {
    printHeader("Query 4: Trending Papers (Time-Series)",
        "Rank papers by cumulative citation activity.");

    String sql =
        """
            SELECT paperId, sum(citationCount) AS totalCitations
             FROM PaperActivity
             GROUP BY paperId
             ORDER BY totalCitations DESC
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s | totalCitations: %s%n",
            r.getProperty("paperId"),
            r.getProperty("totalCitations"));
      }
    }
  }

  // Query 5: GraphRAG Hybrid — Vector Seed + Citation Graph Expansion (SQL)
  private static void runQuery5GraphRag(RemoteDatabase db) {
    printHeader("Query 5: GraphRAG Hybrid (Vector Seed + Citation Expansion)",
        "Discover topics connected via citation graph to papers most similar to [0.8, 0.2, 0.1, 0.1].");

    String sql =
        """
            SELECT topic.name AS topic, count(*) AS connections
             FROM (
              MATCH {type: Paper, where: (id IN (SELECT id FROM Paper ORDER BY vectorNeighbors('Paper[embedding]', [0.8, 0.2, 0.1, 0.1], 3) DESC LIMIT 3))}
                    .out('CITES'){as: cited}
                    .out('COVERS'){as: topic}
              RETURN topic
             )
             GROUP BY topic
             ORDER BY connections DESC
             LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | connections: %s%n",
            r.getProperty("topic"),
            r.getProperty("connections"));
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

**Step 2: Commit**

```bash
git add knowledge-graphs/java/src/
git commit -m "feat: add KnowledgeGraph Java program"
```

---

## Task 9: README.md

**Files:**
- Create: `knowledge-graphs/README.md`

**Step 1: Create the README**

```markdown
# Knowledge Graphs

Demonstrates ArcadeDB's multi-model capabilities using an academic research
knowledge graph that unifies four signal types in a single database:

- **Graph traversal** — co-authorship network and citation graph multi-hop queries
- **Vector similarity** — semantic paper search using embeddings
- **Full-text search** — keyword search across paper abstracts
- **Time-series** — trending papers by cumulative citation activity

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

This creates the `KnowledgeGraph` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/knowledge-graph.jar
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Researcher` | Vertex | `id`, `name`, `embedding` |
| `Paper` | Vertex | `id`, `title`, `abstract`, `year`, `embedding` |
| `Topic` | Vertex | `id`, `name`, `embedding` |
| `Institution` | Vertex | `id`, `name` |
| `CO_AUTHORED` | Edge | Researcher → Paper |
| `CITES` | Edge | Paper → Paper |
| `COVERS` | Edge | Paper → Topic |
| `AFFILIATED_WITH` | Edge | Researcher → Institution |
| `PaperActivity` | Document | `paperId`, `citationCount`, `ts` |

## Query Patterns

| # | Pattern | Language | Pillar |
|---|---------|----------|--------|
| 1 | Co-authorship Network | Cypher | Graph |
| 2 | Semantic Paper Search | SQL + vectorNeighbors | Vector |
| 3 | Full-Text Abstract Search | SQL + SEARCH_CLASS | Full-text |
| 4 | Trending Papers | SQL | Time-series |
| 5 | GraphRAG Hybrid | SQL + MATCH | Graph + Vector |

## Sample Data

- 5 researchers, 4 institutions, 6 topics, 10 papers
- 11 CO_AUTHORED edges, 10 CITES edges, 15 COVERS edges, 5 AFFILIATED_WITH edges
- 10 PaperActivity records (citation events for time-series queries)
- 4-dimensional embeddings throughout

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.2.1**. Vector similarity uses
`vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR` index.
Full-text search uses `SEARCH_CLASS('query')` against a `FULL_TEXT` index on
`Paper(abstract)`.

## Reference

[ArcadeDB Knowledge Graphs use case](https://arcadedb.com/knowledge-graphs.html)
```

**Step 2: Commit**

```bash
git add knowledge-graphs/README.md
git commit -m "feat: add knowledge-graphs README"
```

---

## Task 10: Smoke test end-to-end

This task verifies the full implementation works. Run from the `knowledge-graphs/` directory.

**Step 1: Start ArcadeDB**

```bash
cd knowledge-graphs
docker compose up -d
```

Wait for the healthcheck to pass:

```bash
docker compose ps
```

Expected: `arcadedb` service shows `healthy`.

**Step 2: Run setup**

```bash
./setup.sh
```

Expected output (no curl errors, no `jq` errors):
```
Waiting for ArcadeDB at http://localhost:2480...
ArcadeDB is ready.
Creating database KnowledgeGraph...
Database ready.
Applying sql/01-schema.sql...
Done: sql/01-schema.sql
Applying sql/02-data.sql...
Done: sql/02-data.sql

Setup complete. KnowledgeGraph is ready.
```

**Step 3: Run curl queries**

```bash
./queries/queries.sh
```

Check each query section returns a non-empty JSON array (not `[]`). Specifically:
- Q1: expect at least one result with `colleague.name` = `"Eve Patel"`
- Q2: expect papers with IDs near p2, p8, p4 at the top
- Q3: expect p1 (`Consensus Algorithms...`) and p9 (`Distributed Consensus...`) to appear
- Q4: expect p2 (22+10 = 32 citations) at or near the top
- Q5: expect `Machine Learning`, `Knowledge Graphs`, `Distributed Systems` in results

**Step 4: If Query 5 fails with a subquery error**

Replace the MATCH subquery in `queries/queries.sh` and `KnowledgeGraph.java` with the hardcoded fallback (see Task 6, Step 3). Then re-run.

**Step 5: Build and run Java program**

```bash
cd java
mvn package -q
java -jar target/knowledge-graph.jar
```

Expected: five sections of formatted output, no `[Query N FAILED]` lines.

**Step 6: Commit**

```bash
cd ..
git add .
git commit -m "feat: complete knowledge-graphs use case — all queries verified"
```

**Step 7: Stop ArcadeDB**

```bash
docker compose down
```
