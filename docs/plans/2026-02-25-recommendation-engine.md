# Recommendation Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a fully self-contained `recommendation-engine/` directory demonstrating ArcadeDB's multi-model capabilities (graph traversal, vector similarity, time-series) via five query patterns, runnable with both `curl` and a Java program.

**Architecture:** Self-contained directory per the design doc. Docker Compose brings up ArcadeDB 26.2.1. A `setup.sh` creates the database and applies SQL files. Five queries are demonstrated via `queries/queries.sh` (curl) and `java/` (Maven fat JAR using `arcadedb-network`).

**Tech Stack:** ArcadeDB 26.2.1, Docker Compose, Maven 3.x, Java 17+, `com.arcadedb:arcadedb-network:26.2.1`, `jq` (for setup script)

> **Implementation notes (deviations from this plan discovered during execution):**
> - `ARCADEDB_SERVER_ROOTPASSWORD` env var not picked up by 26.2.1 Docker image; replaced with `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"`
> - `vectorDistance()` does not exist in 26.2.1; replaced with `vectorNeighbors('TypeName[property]', vector, k)` (requires an `LSM_VECTOR` index)
> - `LET $var = (SELECT ... GROUP BY ...)` syntax not supported; Query 4 simplified to a plain MATCH-based graph traversal (collaborative filtering for shows)
> - Vector indexes require the full index name `TypeName[propertyName]` as the first argument to `vectorNeighbors()`

---

### Task 1: Scaffold the directory structure

**Files:**
- Create: `recommendation-engine/` (directory)
- Create: `recommendation-engine/sql/` (directory)
- Create: `recommendation-engine/queries/` (directory)
- Create: `recommendation-engine/java/src/main/java/com/arcadedb/examples/` (directory)

**Step 1: Create all directories**

```bash
mkdir -p recommendation-engine/sql
mkdir -p recommendation-engine/queries
mkdir -p recommendation-engine/java/src/main/java/com/arcadedb/examples
```

**Step 2: Verify**

```bash
find recommendation-engine -type d
```

Expected output:
```
recommendation-engine
recommendation-engine/sql
recommendation-engine/queries
recommendation-engine/java
recommendation-engine/java/src
recommendation-engine/java/src/main
recommendation-engine/java/src/main/java
recommendation-engine/java/src/main/java/com
recommendation-engine/java/src/main/java/com/arcadedb
recommendation-engine/java/src/main/java/com/arcadedb/examples
```

**Step 3: Commit**

```bash
git add recommendation-engine/
git commit -m "chore: scaffold recommendation-engine directory structure"
```

---

### Task 2: Write docker-compose.yml

**Files:**
- Create: `recommendation-engine/docker-compose.yml`

**Step 1: Write the file**

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.2.1
    ports:
      - "2480:2480"
    environment:
      ARCADEDB_SERVER_ROOTPASSWORD: arcadedb
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:2480/api/v1/ready"]
      interval: 5s
      timeout: 3s
      retries: 20
      start_period: 10s
```

**Step 2: Verify the container starts**

```bash
cd recommendation-engine
docker compose up -d
docker compose ps
```

Expected: `arcadedb` service shows `healthy` after ~30 seconds.

**Step 3: Verify HTTP API is reachable**

```bash
curl -sf -u root:arcadedb http://localhost:2480/api/v1/ready
```

Expected: HTTP 200 with a JSON response containing `"ready"`.

**Step 4: Commit**

```bash
git add recommendation-engine/docker-compose.yml
git commit -m "feat(recommendation-engine): add docker-compose for ArcadeDB 26.2.1"
```

---

### Task 3: Write the SQL schema

**Files:**
- Create: `recommendation-engine/sql/01-schema.sql`

**Step 1: Write the schema file**

Each statement on its own line (one statement = one line, semicolon-terminated):

```sql
CREATE VERTEX TYPE User IF NOT EXISTS;
CREATE PROPERTY User.id IF NOT EXISTS STRING;
CREATE PROPERTY User.embedding IF NOT EXISTS LIST;
CREATE INDEX ON User (id) UNIQUE;
CREATE VERTEX TYPE Product IF NOT EXISTS;
CREATE PROPERTY Product.name IF NOT EXISTS STRING;
CREATE PROPERTY Product.category IF NOT EXISTS STRING;
CREATE PROPERTY Product.price IF NOT EXISTS FLOAT;
CREATE PROPERTY Product.inStock IF NOT EXISTS BOOLEAN;
CREATE PROPERTY Product.embedding IF NOT EXISTS LIST;
CREATE VERTEX TYPE Show IF NOT EXISTS;
CREATE PROPERTY Show.title IF NOT EXISTS STRING;
CREATE PROPERTY Show.genre IF NOT EXISTS STRING;
CREATE PROPERTY Show.embedding IF NOT EXISTS LIST;
CREATE EDGE TYPE PURCHASED IF NOT EXISTS;
CREATE EDGE TYPE WATCHED IF NOT EXISTS;
CREATE EDGE TYPE INTERACTED IF NOT EXISTS;
CREATE DOCUMENT TYPE ProductInteraction IF NOT EXISTS;
CREATE PROPERTY ProductInteraction.productId IF NOT EXISTS STRING;
CREATE PROPERTY ProductInteraction.purchaseCount IF NOT EXISTS LONG;
CREATE PROPERTY ProductInteraction.ts IF NOT EXISTS DATETIME;
```

**Step 2: Commit**

```bash
git add recommendation-engine/sql/01-schema.sql
git commit -m "feat(recommendation-engine): add graph schema SQL"
```

---

### Task 4: Write the sample data

**Files:**
- Create: `recommendation-engine/sql/02-data.sql`

Embeddings are 4-dimensional. Tech products cluster near `[0.9, 0.1, 0.1, 0.1]`, sports near `[0.1, 0.9, 0.1, 0.1]`, entertainment near `[0.1, 0.1, 0.9, 0.1]`. Users u1 and u2 share purchases so collaborative filtering has a signal.

**Step 1: Write the data file**

```sql
-- Users
INSERT INTO User SET id = 'u1', embedding = [0.9, 0.1, 0.1, 0.1];
INSERT INTO User SET id = 'u2', embedding = [0.5, 0.5, 0.1, 0.1];
INSERT INTO User SET id = 'u3', embedding = [0.1, 0.9, 0.1, 0.1];
INSERT INTO User SET id = 'u4', embedding = [0.1, 0.1, 0.9, 0.1];
INSERT INTO User SET id = 'u5', embedding = [0.4, 0.3, 0.2, 0.1];
-- Products (Electronics)
INSERT INTO Product SET name = 'Laptop', category = 'Electronics', price = 999.99, inStock = true, embedding = [0.9, 0.1, 0.1, 0.1];
INSERT INTO Product SET name = 'Phone', category = 'Electronics', price = 699.99, inStock = true, embedding = [0.8, 0.1, 0.2, 0.1];
INSERT INTO Product SET name = 'Headphones', category = 'Electronics', price = 199.99, inStock = true, embedding = [0.7, 0.2, 0.2, 0.1];
INSERT INTO Product SET name = 'Keyboard', category = 'Electronics', price = 99.99, inStock = true, embedding = [0.8, 0.2, 0.1, 0.1];
INSERT INTO Product SET name = 'Monitor', category = 'Electronics', price = 399.99, inStock = true, embedding = [0.9, 0.1, 0.1, 0.2];
-- Products (Sports)
INSERT INTO Product SET name = 'Running Shoes', category = 'Sports', price = 89.99, inStock = true, embedding = [0.1, 0.9, 0.1, 0.1];
INSERT INTO Product SET name = 'Yoga Mat', category = 'Sports', price = 29.99, inStock = true, embedding = [0.1, 0.8, 0.2, 0.1];
INSERT INTO Product SET name = 'Water Bottle', category = 'Sports', price = 19.99, inStock = true, embedding = [0.2, 0.7, 0.1, 0.1];
INSERT INTO Product SET name = 'Tennis Racket', category = 'Sports', price = 59.99, inStock = true, embedding = [0.1, 0.9, 0.1, 0.2];
INSERT INTO Product SET name = 'Jump Rope', category = 'Sports', price = 14.99, inStock = false, embedding = [0.1, 0.8, 0.1, 0.2];
-- Shows
INSERT INTO Show SET title = 'Action Movie', genre = 'Action', embedding = [0.3, 0.2, 0.9, 0.1];
INSERT INTO Show SET title = 'Comedy Show', genre = 'Comedy', embedding = [0.1, 0.1, 0.8, 0.2];
INSERT INTO Show SET title = 'Documentary', genre = 'Documentary', embedding = [0.2, 0.3, 0.7, 0.1];
INSERT INTO Show SET title = 'Drama Series', genre = 'Drama', embedding = [0.1, 0.2, 0.8, 0.1];
INSERT INTO Show SET title = 'Sci-Fi Movie', genre = 'Sci-Fi', embedding = [0.4, 0.1, 0.9, 0.1];
-- PURCHASED edges (u1+u2 share Phone and Headphones -> u1 will get Running Shoes via collab)
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Headphones');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Headphones');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Yoga Mat');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Tennis Racket');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Water Bottle');
-- WATCHED edges (u1+u2 both watched Action Movie -> u1 gets Comedy Show via collab)
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Show WHERE title = 'Action Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Show WHERE title = 'Sci-Fi Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Show WHERE title = 'Action Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Show WHERE title = 'Comedy Show');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Show WHERE title = 'Documentary');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u4') TO (SELECT FROM Show WHERE title = 'Comedy Show');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u4') TO (SELECT FROM Show WHERE title = 'Drama Series');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Show WHERE title = 'Action Movie');
CREATE EDGE WATCHED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Show WHERE title = 'Documentary');
-- INTERACTED edges
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u1') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Phone');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u2') TO (SELECT FROM Product WHERE name = 'Running Shoes');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u3') TO (SELECT FROM Product WHERE name = 'Yoga Mat');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Laptop');
CREATE EDGE INTERACTED FROM (SELECT FROM User WHERE id = 'u5') TO (SELECT FROM Product WHERE name = 'Water Bottle');
-- ProductInteraction documents for trending query
INSERT INTO ProductInteraction SET productId = 'Laptop', purchaseCount = 12, ts = date();
INSERT INTO ProductInteraction SET productId = 'Phone', purchaseCount = 20, ts = date();
INSERT INTO ProductInteraction SET productId = 'Running Shoes', purchaseCount = 35, ts = date();
INSERT INTO ProductInteraction SET productId = 'Headphones', purchaseCount = 8, ts = date();
INSERT INTO ProductInteraction SET productId = 'Yoga Mat', purchaseCount = 15, ts = date();
INSERT INTO ProductInteraction SET productId = 'Laptop', purchaseCount = 3, ts = date();
INSERT INTO ProductInteraction SET productId = 'Running Shoes', purchaseCount = 18, ts = date();
INSERT INTO ProductInteraction SET productId = 'Phone', purchaseCount = 9, ts = date();
```

**Step 2: Commit**

```bash
git add recommendation-engine/sql/02-data.sql
git commit -m "feat(recommendation-engine): add sample data SQL"
```

---

### Task 5: Write setup.sh

**Files:**
- Create: `recommendation-engine/setup.sh`

This script creates the database and applies both SQL files. Requires `jq` and `curl` to be installed. Run from the `recommendation-engine/` directory.

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
DB_NAME="RecommendationEngine"

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
chmod +x recommendation-engine/setup.sh
```

**Step 3: Run it (ArcadeDB must be up from Task 2)**

```bash
cd recommendation-engine
./setup.sh
```

Expected: no errors, ends with "Setup complete."

**Step 4: Smoke-test the data loaded**

```bash
curl -s -u root:arcadedb \
  -X POST "http://localhost:2480/api/v1/query/RecommendationEngine" \
  -H "Content-Type: application/json" \
  -d '{"language":"sql","command":"SELECT count(*) FROM User"}' | jq .
```

Expected: result shows `count(*)` = 5.

```bash
curl -s -u root:arcadedb \
  -X POST "http://localhost:2480/api/v1/query/RecommendationEngine" \
  -H "Content-Type: application/json" \
  -d '{"language":"sql","command":"SELECT count(*) FROM Product"}' | jq .
```

Expected: result shows `count(*)` = 10.

**Step 5: Commit**

```bash
git add recommendation-engine/setup.sh
git commit -m "feat(recommendation-engine): add database setup script"
```

---

### Task 6: Write queries/queries.sh

**Files:**
- Create: `recommendation-engine/queries/queries.sh`

All five query patterns as curl one-liners against a running ArcadeDB instance. Run from the `recommendation-engine/` directory after `./setup.sh`.

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Recommendation Engine — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
AUTH="root:arcadedb"
DB="RecommendationEngine"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# ─────────────────────────────────────────────────────────────────────────────
echo "=== Query 1: Collaborative Filtering (Graph Traversal) ==="
echo "Find products to recommend to u1 based on shared purchases with other users."
echo ""
query "cypher" "
MATCH (me:User {id: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
WHERE rec <> p
  AND NOT (me)-[:PURCHASED]->(rec)
RETURN rec.name, rec.category, count(DISTINCT other) AS score
ORDER BY score DESC LIMIT 20
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 2: Vector Similarity Search ==="
echo "Find products semantically similar to the Laptop embedding [0.9,0.1,0.1,0.1]."
echo ""
query "sql" "
SELECT name, category, price,
       vectorDistance(embedding, [0.9, 0.1, 0.1, 0.1]) AS distance
FROM Product
WHERE inStock = true
ORDER BY distance ASC
LIMIT 20
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 3: Trending Products (Time-Series) ==="
echo "Rank products by total recent purchase interactions."
echo ""
query "sql" "
SELECT productId, sum(purchaseCount) AS totalInteractions
FROM ProductInteraction
GROUP BY productId
ORDER BY totalInteractions DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 4: Multi-Model Hybrid — Streaming Platform ==="
echo "Recommend shows to u1 blending collaborative signal + vector similarity."
echo ""
query "sql" "
LET \$collab = (
  SELECT rec, count(DISTINCT viewer) AS collab_score
  FROM (
    MATCH {type: User, where: (id = 'u1')}
          .out('WATCHED'){as: show}
          .in('WATCHED'){as: viewer, where: (id != 'u1')}
          .out('WATCHED'){as: rec, where: (\$matched.show != @this)}
    RETURN rec, viewer
  ) GROUP BY rec
)
SELECT rec.title, rec.genre,
  collab_score,
  vectorDistance(rec.embedding, [0.9, 0.1, 0.1, 0.1]) AS similarity,
  (0.6 * collab_score + 0.4 * (1 - similarity)) AS final_score
FROM \$collab
ORDER BY final_score DESC
LIMIT 10
"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Query 5: E-Commerce Personalized Category Page ==="
echo "Rank Electronics products for u1 by vector relevance + trending interactions."
echo ""
query "cypher" "
MATCH (u:User {id: 'u1'})
MATCH (p:Product)
WHERE p.category = 'Electronics'
  AND p.inStock = true
RETURN p.name, p.price,
  vectorDistance(p.embedding, u.embedding) AS relevance
ORDER BY relevance ASC
LIMIT 30
"
```

**Step 2: Make executable**

```bash
chmod +x recommendation-engine/queries/queries.sh
```

**Step 3: Run and verify all 5 queries return results**

```bash
cd recommendation-engine
./queries/queries.sh
```

Expected for each query:
- Query 1: JSON array with `rec.name` = `"Running Shoes"` (and/or `"Water Bottle"`) near top
- Query 2: JSON array with `Laptop` first (distance 0), other Electronics nearby
- Query 3: JSON array with `Running Shoes` and `Phone` near top
- Query 4: JSON array with `Comedy Show` (shared viewer u2)
- Query 5: JSON array of Electronics products ordered by relevance to u1's embedding

**Step 4: Commit**

```bash
git add recommendation-engine/queries/queries.sh
git commit -m "feat(recommendation-engine): add curl query demonstrations"
```

---

### Task 7: Write java/pom.xml

**Files:**
- Create: `recommendation-engine/java/pom.xml`

**Step 1: Write the pom.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.arcadedb.examples</groupId>
  <artifactId>recommendation-engine</artifactId>
  <version>1.0-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
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
              <mainClass>com.arcadedb.examples.RecommendationEngine</mainClass>
            </manifest>
          </archive>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <finalName>recommendation-engine</finalName>
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

**Step 2: Verify Maven can resolve dependencies**

```bash
cd recommendation-engine/java
mvn dependency:resolve -q
```

Expected: exits 0, no "BUILD FAILURE".

**Step 3: Commit**

```bash
git add recommendation-engine/java/pom.xml
git commit -m "feat(recommendation-engine): add Maven project for Java demo"
```

---

### Task 8: Write RecommendationEngine.java

**Files:**
- Create: `recommendation-engine/java/src/main/java/com/arcadedb/examples/RecommendationEngine.java`

**Step 1: Write the Java class**

```java
package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class RecommendationEngine {

    private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
    private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
    private static final String DB_NAME  = "RecommendationEngine";
    private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
    private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

    public static void main(String[] args) {
        try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
            runQuery1CollaborativeFiltering(db);
            runQuery2VectorSimilarity(db);
            runQuery3Trending(db);
            runQuery4StreamingHybrid(db);
            runQuery5EcommerceCategory(db);
        }
        System.out.println("\nAll queries complete.");
    }

    // ── Query 1: Collaborative Filtering via Graph Traversal ──────────────────
    private static void runQuery1CollaborativeFiltering(RemoteDatabase db) {
        printHeader("Query 1: Collaborative Filtering (Graph Traversal)",
            "Find products to recommend to u1 based on shared purchases with other users.");

        String cypher =
            "MATCH (me:User {id: 'u1'})" +
            "      -[:PURCHASED]->(p:Product)" +
            "      <-[:PURCHASED]-(other:User)" +
            "      -[:PURCHASED]->(rec:Product)" +
            " WHERE rec <> p" +
            "   AND NOT (me)-[:PURCHASED]->(rec)" +
            " RETURN rec.name, rec.category, count(DISTINCT other) AS score" +
            " ORDER BY score DESC LIMIT 20";

        try (ResultSet rs = db.query("cypher", cypher)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | %-15s | score: %s%n",
                    r.getProperty("rec.name"),
                    r.getProperty("rec.category"),
                    r.getProperty("score"));
            }
        }
    }

    // ── Query 2: Vector Similarity Search ─────────────────────────────────────
    private static void runQuery2VectorSimilarity(RemoteDatabase db) {
        printHeader("Query 2: Vector Similarity Search",
            "Find products similar to the Laptop embedding [0.9, 0.1, 0.1, 0.1].");

        String sql =
            "SELECT name, category, price," +
            "       vectorDistance(embedding, [0.9, 0.1, 0.1, 0.1]) AS distance" +
            " FROM Product" +
            " WHERE inStock = true" +
            " ORDER BY distance ASC" +
            " LIMIT 20";

        try (ResultSet rs = db.query("sql", sql)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | %-15s | $%-8.2f | distance: %.4f%n",
                    r.getProperty("name"),
                    r.getProperty("category"),
                    ((Number) r.getProperty("price")).doubleValue(),
                    ((Number) r.getProperty("distance")).doubleValue());
            }
        }
    }

    // ── Query 3: Trending Products (Time-Series Proxy) ────────────────────────
    private static void runQuery3Trending(RemoteDatabase db) {
        printHeader("Query 3: Trending Products (Time-Series)",
            "Rank products by total recent purchase interaction counts.");

        String sql =
            "SELECT productId, sum(purchaseCount) AS totalInteractions" +
            " FROM ProductInteraction" +
            " GROUP BY productId" +
            " ORDER BY totalInteractions DESC" +
            " LIMIT 10";

        try (ResultSet rs = db.query("sql", sql)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | interactions: %s%n",
                    r.getProperty("productId"),
                    r.getProperty("totalInteractions"));
            }
        }
    }

    // ── Query 4: Multi-Model Hybrid — Streaming Platform ──────────────────────
    private static void runQuery4StreamingHybrid(RemoteDatabase db) {
        printHeader("Query 4: Multi-Model Hybrid — Streaming Platform",
            "Recommend shows to u1 blending collaborative signal + vector similarity.");

        String sql =
            "LET $collab = (" +
            "  SELECT rec, count(DISTINCT viewer) AS collab_score" +
            "  FROM (" +
            "    MATCH {type: User, where: (id = 'u1')}" +
            "          .out('WATCHED'){as: show}" +
            "          .in('WATCHED'){as: viewer, where: (id != 'u1')}" +
            "          .out('WATCHED'){as: rec, where: ($matched.show != @this)}" +
            "    RETURN rec, viewer" +
            "  ) GROUP BY rec" +
            ")" +
            " SELECT rec.title, rec.genre," +
            "   collab_score," +
            "   vectorDistance(rec.embedding, [0.9, 0.1, 0.1, 0.1]) AS similarity," +
            "   (0.6 * collab_score + 0.4 * (1 - similarity)) AS final_score" +
            " FROM $collab" +
            " ORDER BY final_score DESC" +
            " LIMIT 10";

        try (ResultSet rs = db.query("sql", sql)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | %-15s | collab: %s | score: %.4f%n",
                    r.getProperty("rec.title"),
                    r.getProperty("rec.genre"),
                    r.getProperty("collab_score"),
                    ((Number) r.getProperty("final_score")).doubleValue());
            }
        }
    }

    // ── Query 5: E-Commerce Personalized Category Page ────────────────────────
    private static void runQuery5EcommerceCategory(RemoteDatabase db) {
        printHeader("Query 5: E-Commerce Personalized Category Page",
            "Rank Electronics products for u1 by vector relevance.");

        String cypher =
            "MATCH (u:User {id: 'u1'})" +
            " MATCH (p:Product)" +
            " WHERE p.category = 'Electronics'" +
            "   AND p.inStock = true" +
            " RETURN p.name, p.price," +
            "   vectorDistance(p.embedding, u.embedding) AS relevance" +
            " ORDER BY relevance ASC" +
            " LIMIT 30";

        try (ResultSet rs = db.query("cypher", cypher)) {
            while (rs.hasNext()) {
                Result r = rs.next();
                System.out.printf("  %-20s | $%-8.2f | relevance: %.4f%n",
                    r.getProperty("p.name"),
                    ((Number) r.getProperty("p.price")).doubleValue(),
                    ((Number) r.getProperty("relevance")).doubleValue());
            }
        }
    }

    // ── Utility ───────────────────────────────────────────────────────────────
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
git add recommendation-engine/java/src/
git commit -m "feat(recommendation-engine): add Java RecommendationEngine main class"
```

---

### Task 9: Build and run the Java program

**Step 1: Build the fat JAR**

```bash
cd recommendation-engine/java
mvn package -q
```

Expected: `BUILD SUCCESS`, creates `target/recommendation-engine.jar`.

**Step 2: Run the JAR (ArcadeDB must be running with data loaded from Task 5)**

```bash
java -jar target/recommendation-engine.jar
```

Expected: 5 sections of output, each showing a query header followed by result rows. No stack traces or connection errors.

**Step 3: If a query throws an exception**, note the error message — the SQL/Cypher may need minor adjustment for ArcadeDB 26.2.1. Common adjustments:
- If Query 4 (LET) fails: simplify to two separate queries in the Java code, printing both result sets.
- If `vectorDistance` syntax differs: try `distance(embedding, [0.9, 0.1, 0.1, 0.1])`.
- If Cypher `MATCH (p:Product)` without a relationship pattern fails: use `MATCH (p:Product) WHERE p.category = 'Electronics'` directly.

**Step 4: Commit once all 5 queries run successfully**

```bash
git add recommendation-engine/java/
git commit -m "feat(recommendation-engine): verify Java program runs all 5 queries"
```

---

### Task 10: Write recommendation-engine/README.md

**Files:**
- Create: `recommendation-engine/README.md`

**Step 1: Write the README**

```markdown
# Recommendation Engine

Demonstrates ArcadeDB's multi-model capabilities by implementing an intelligent
recommendation system that unifies three signal types in a single database:

- **Graph traversal** — collaborative filtering via relationship patterns
- **Vector similarity** — content-based recommendations using embeddings
- **Time-series** — trending detection via interaction counts

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 17+ and Maven 3.x (for the Java demo)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `RecommendationEngine` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/recommendation-engine.jar
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `User` | Vertex | `id`, `embedding` |
| `Product` | Vertex | `name`, `category`, `price`, `inStock`, `embedding` |
| `Show` | Vertex | `title`, `genre`, `embedding` |
| `PURCHASED` | Edge | User → Product |
| `WATCHED` | Edge | User → Show |
| `INTERACTED` | Edge | User → Product |
| `ProductInteraction` | Document | `productId`, `purchaseCount`, `ts` |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Collaborative Filtering | Cypher | Graph |
| 2 | Vector Similarity Search | SQL | Vector |
| 3 | Trending Detection | SQL | Time-series |
| 4 | Multi-Model Hybrid (Streaming) | SQL + MATCH | Graph + Vector |
| 5 | Personalized Category Page | Cypher | Graph + Vector |

## Sample Data

- 5 users with 4-dimensional preference vectors
- 10 products (Electronics and Sports categories)
- 5 shows
- ~30 PURCHASED / WATCHED / INTERACTED edges with deliberate overlap
  (users u1 and u2 share purchases → collaborative filtering recommends
  Running Shoes to u1)

## Reference

[ArcadeDB Recommendation Engine use case](https://arcadedb.com/recommendation-engine.html)
```

**Step 2: Commit**

```bash
git add recommendation-engine/README.md
git commit -m "docs(recommendation-engine): add README with quickstart guide"
```

---

### Task 11: Update root README.md

**Files:**
- Modify: `README.md`

**Step 1: Read current README**

```bash
cat README.md
```

**Step 2: Replace content**

```markdown
# ArcadeDB Use Cases

A collection of self-contained projects demonstrating how to use [ArcadeDB](https://arcadedb.com).

Each use case lives in its own directory with a Docker Compose file, SQL schema/data files,
and runnable demos via both `curl` and a Java program.

## Use Cases

| Directory | Description | ArcadeDB features |
|-----------|-------------|-------------------|
| [recommendation-engine](./recommendation-engine/) | Intelligent product and content recommendations | Graph traversal, Vector similarity, Time-series |

## Structure

Each use case directory contains:
- `docker-compose.yml` — ArcadeDB instance (pinned version)
- `setup.sh` — creates the database and loads schema + data
- `sql/01-schema.sql` — vertex/edge type definitions
- `sql/02-data.sql` — sample data
- `queries/queries.sh` — all queries via `curl`
- `java/` — standalone Maven project running the same queries via `arcadedb-network`
- `README.md` — quickstart guide
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update root README with use cases table"
```

---

### Task 12: Final cleanup and push

**Step 1: Stop Docker (optional)**

```bash
cd recommendation-engine
docker compose down
```

**Step 2: Verify clean git state**

```bash
git status
git log --oneline -10
```

**Step 3: Push branch**

```bash
git push origin feat/recommendation-engine
```
