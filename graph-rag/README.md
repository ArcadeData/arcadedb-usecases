# Graph RAG

Demonstrates ArcadeDB's multi-model capabilities by implementing a Graph RAG
(Retrieval-Augmented Generation) system that unifies three retrieval signals
in a single database:

- **Graph traversal** — multi-hop entity bridging via knowledge graph relationships
- **Vector similarity** — semantic chunk retrieval using embeddings
- **Full-text indexing** — keyword-based content lookup

## Prerequisites

- Docker and Docker Compose
- `curl` and `jq`
- Java 21+ and Maven 3.x (for the Java demos)

## Quickstart

### 1. Start ArcadeDB

```bash
docker compose up -d
```

### 2. Create database and load data

```bash
./setup.sh
```

This creates the `GraphRAG` database, applies the schema, and inserts sample data.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java (Bolt)

```bash
cd java
mvn package -q
java -jar target/graph-rag.jar
```

### 3c. Run LangChain4j demos

```bash
cd langchain4j
mvn package -q

# Embedding store: ingest + similarity search
java -jar target/graph-rag-langchain4j.jar

# Content retriever: semantic search + graph expansion
java -cp target/graph-rag-langchain4j.jar com.arcadedb.examples.GraphRAGContentRetriever
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Chunk` | Vertex | `content`, `source`, `chunkIndex`, `embedding` |
| `Entity` | Vertex | `name` |
| `Person` | Vertex (extends Entity) | `name` |
| `Concept` | Vertex (extends Entity) | `name` |
| `Organization` | Vertex (extends Entity) | `name` |
| `MENTIONS` | Edge | Chunk → Entity |
| `RELATES_TO` | Edge | Entity → Entity |
| `WORKS_AT` | Edge | Person → Organization |
| `AUTHORED` | Edge | Person → Chunk |

## Query Patterns

| # | Pattern | Language | Signal type |
|---|---------|----------|-------------|
| 1 | Hybrid Vector + Graph | SQL | Vector + Graph |
| 2 | Multi-Hop Entity Bridge | Cypher | Graph |
| 3 | Temporal-Aware Retrieval | Cypher | Graph |
| 4 | Composite Scoring | SQL | Vector + Graph |
| 5 | Agentic RAG Steps | Mixed | Multi-signal |

## Sample Data

- 8 chunks from 4 internal documents with 4D embeddings
- 11 entities (4 persons, 4 concepts, 3 organizations)
- ~25 edges (MENTIONS, RELATES_TO, WORKS_AT, AUTHORED)
- Multi-hop design: querying "Vector Search" bridges to GraphRAG docs via shared entity mentions

## Langchain4j Module

The `langchain4j/` directory contains two standalone examples using LangChain4j
with ArcadeDB via the Neo4j Bolt protocol:

- **GraphRAGEmbeddingStore** — ingests text chunks with real 384D embeddings (AllMiniLmL6V2), stores via Cypher over Bolt, and performs similarity search using LangChain4j's cosine similarity
- **GraphRAGContentRetriever** — re-embeds the sample Chunk data with 384D vectors, runs semantic search, then enriches results with graph context via Cypher traversal (entities mentioned by top matches)

No external API keys required — the embedding model runs in-process.

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.2.1**. Vector similarity queries use
`vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR`
index. The Bolt protocol (port 7687) enables Neo4j driver compatibility.

## Reference

[ArcadeDB Graph RAG use case](https://arcadedb.com/graph-rag.html)
