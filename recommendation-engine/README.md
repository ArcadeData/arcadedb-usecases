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
| 2 | Vector Similarity Search | SQL + vectorNeighbors | Vector |
| 3 | Trending Detection | SQL | Time-series |
| 4 | Multi-Model Hybrid (Streaming) | SQL + MATCH | Graph + Vector |
| 5 | Personalized Category Page | SQL + vectorNeighbors | Vector |

## Sample Data

- 5 users with 4-dimensional preference vectors
- 10 products (Electronics and Sports categories)
- 5 shows
- ~30 PURCHASED / WATCHED / INTERACTED edges with deliberate overlap
  (users u1 and u2 share purchases → collaborative filtering recommends
  Running Shoes to u1)

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.2.1**. Vector similarity queries use
`vectorNeighbors('IndexName[property]', vector, k)` with an `LSM_VECTOR`
index. The index name format is `TypeName[propertyName]`.

## Reference

[ArcadeDB Recommendation Engine use case](https://arcadedb.com/recommendation-engine.html)
