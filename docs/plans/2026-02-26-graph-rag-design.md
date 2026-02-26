# Graph RAG Use Case — Design

**Date:** 2026-02-26
**Branch:** feat/graph-rag
**ArcadeDB version:** 26.2.1

## Overview

Implement the [ArcadeDB Graph RAG](https://arcadedb.com/graph-rag.html) use case following the same structure as the recommendation-engine. The use case demonstrates ArcadeDB's ability to unify vector search, graph traversal, and full-text indexing for retrieval-augmented generation — without requiring multiple databases or ETL pipelines.

Key differences from recommendation-engine:
- Java module uses **Neo4j Bolt driver** (`neo4j-java-driver`) and **Cypher** as query language, connecting via `bolt://localhost:2424`
- Additional **langchain4j** submodule demonstrates `Neo4jEmbeddingStore` and `EmbeddingStoreContentRetriever` with local `AllMiniLmL6V2` embeddings (no external API keys)

## Repository Structure

```
graph-rag/
├── README.md
├── docker-compose.yml
├── setup.sh
├── sql/
│   ├── 01-schema.sql
│   └── 02-data.sql
├── queries/
│   └── queries.sh
├── java/
│   ├── pom.xml
│   └── src/main/java/com/arcadedb/examples/
│       └── GraphRAG.java
└── langchain4j/
    ├── pom.xml
    └── src/main/java/com/arcadedb/examples/
        ├── GraphRAGEmbeddingStore.java
        └── GraphRAGContentRetriever.java
```

## Docker Compose

- Single service: `arcadedata/arcadedb:26.2.1`
- Ports exposed: `2480` (HTTP API), `2424` (Bolt)
- Root password via `JAVA_OPTS: -Darcadedb.server.rootPassword=arcadedb`
- Health check on `http://localhost:2480/api/v1/ready`

## Schema (`sql/01-schema.sql`)

One document type, four vertex types, and four edge types:

**Document:**
- `Chunk` — `content` (STRING), `source` (STRING), `chunkIndex` (INTEGER), `embedding` (LIST)
- Vector index on `Chunk(embedding)`: LSM, 4 dimensions, COSINE

**Vertices:**
- `Entity` — `name` (STRING)
- `Person EXTENDS Entity`
- `Concept EXTENDS Entity`
- `Organization EXTENDS Entity`

**Edges:**
- `MENTIONS` — Chunk -> Entity
- `RELATES_TO` — Entity -> Entity
- `WORKS_AT` — Person -> Organization
- `AUTHORED` — Person -> Chunk

## Sample Data (`sql/02-data.sql`)

**Domain:** Fictional tech company "ArcadeSoft" knowledge base.

**Chunks (~8-10):** Snippets from internal documentation:
- "Getting Started with GraphRAG" (2 chunks)
- "Microservices Architecture Guide" (2 chunks)
- "Vector Search Best Practices" (2 chunks)
- "Team Onboarding Handbook" (2 chunks)

Each chunk has a hand-crafted 4D embedding reflecting its topic (e.g. graph-heavy docs: `[0.9, 0.1, 0.2, 0.1]`, vector-heavy: `[0.1, 0.9, 0.2, 0.1]`).

**Entities (~8-10):**
- Persons: Alice Chen, Bob Martinez, Carol Wu, Dave Park
- Concepts: GraphRAG, Vector Search, Microservices, Knowledge Graph
- Organizations: ArcadeSoft, Platform Team, Research Team

**Edges (~20-25):**
- MENTIONS: chunks reference concepts and people
- RELATES_TO: GraphRAG -> Vector Search, GraphRAG -> Knowledge Graph, Microservices -> Knowledge Graph
- WORKS_AT: Alice -> Research Team, Bob -> Platform Team, Carol -> ArcadeSoft, Dave -> Platform Team
- AUTHORED: Alice -> GraphRAG doc chunks, Bob -> Microservices doc chunks

**Design intent:** Multi-hop queries work because querying "Vector Search" finds a chunk that MENTIONS the "GraphRAG" concept, which is MENTIONED by other chunks about GraphRAG — creating entity bridges. RELATES_TO edges form a small concept graph for traversal.

## Queries

### `queries/queries.sh` — 5 labeled sections via curl

| # | Pattern | Language | Description |
|---|---------|----------|-------------|
| 1 | Hybrid Vector + Graph | Cypher | Vector search for similar chunks, traverse MENTIONS to find entities and connected chunks |
| 2 | Multi-Hop Entity Bridge | Cypher | Find chunks connected through entity chains: query chunk -> entity -> related chunk |
| 3 | Temporal-Aware Retrieval | Cypher | Filter chunks by `chunkIndex` ordering, return most recent context first |
| 4 | Triple Hybrid | SQL | Composite scoring: vector distance + `CONTAINSTEXT` keyword + entity connection count |
| 5 | Agentic RAG Steps | Mixed | 4-step sequence: vector search, graph expansion, full-text lookup, context assembly |

### `java/GraphRAG.java` — All Cypher via Bolt

Adapts the 5 patterns to pure Cypher. Queries that rely on SQL-specific features are adapted:
- Query 4: vector distance + entity count (2-signal composite, no full-text)
- Query 5: vector search -> graph expansion -> collect results (3 steps, no full-text)

### `langchain4j/` — 2 example classes

1. **GraphRAGEmbeddingStore** — ingest text chunks, generate real 384D embeddings with AllMiniLmL6V2, store in ArcadeDB via `Neo4jEmbeddingStore` over Bolt, run similarity searches
2. **GraphRAGContentRetriever** — wire `Neo4jEmbeddingStore` into a langchain4j `EmbeddingStoreContentRetriever` pipeline, query with natural language, print retrieved chunks with scores

## Java Module (`java/`)

- **Build tool:** Maven (standalone `pom.xml`, no parent)
- **Dependency:** `org.neo4j.driver:neo4j-java-driver:5.28.x`
- **Java:** 21
- **Output:** fat JAR via maven-assembly-plugin -> `graph-rag.jar`
- **Entry point:** `GraphRAG.java` with `main` method that:
  1. Opens a Neo4j `Driver` connection to `bolt://localhost:2424`
  2. Runs all 5 queries sequentially in Cypher
  3. Prints header and formatted results for each query
  4. Closes the driver

## Langchain4j Module (`langchain4j/`)

- **Build tool:** Maven (standalone `pom.xml`, no parent, no Spring Boot)
- **Dependencies:** `langchain4j-community-neo4j`, `langchain4j-embeddings-all-minilm-l6-v2`, `neo4j-java-driver`
- **Java:** 21
- **Output:** fat JAR via maven-assembly-plugin -> `graph-rag-langchain4j.jar`
- **No external API keys required** — AllMiniLmL6V2 runs in-process

## Setup

`setup.sh` follows the recommendation-engine pattern:
1. Wait for ArcadeDB ready endpoint
2. Create database `GraphRAG` via HTTP API
3. Apply `sql/01-schema.sql`
4. Apply `sql/02-data.sql`

## Success Criteria

- `docker compose up` starts ArcadeDB with both HTTP and Bolt ports
- SQL files apply cleanly via `setup.sh`
- `queries.sh` runs all 5 queries and returns non-empty result sets
- `mvn package && java -jar target/graph-rag.jar` connects via Bolt, runs all 5 Cypher queries
- `mvn package && java -jar target/graph-rag-langchain4j.jar` ingests chunks, generates embeddings, runs similarity search and content retrieval
