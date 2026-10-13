# Route Planning

Shortest paths on a real road network with ArcadeDB: the **Florida road network** of the 9th DIMACS Implementation
Challenge, 1,070,376 junctions and 2,712,798 road segments, each with its length and its travel time. The trip is
**Tallahassee to Coral Gables**, answered with:

- **Fewest hops** — `shortestPath()`
- **Dijkstra and A\*** — `dijkstra()` and `astar()`
- **Customizable Contraction Hierarchies (CCH)** — a Graph Analytical View keeps one CCH per cost (`km`, `minutes`),
  queried with `cchShortestPath()` (SQL) and `algo.cch.shortestPath` (Cypher)
- **Live traffic** — one `SET` changes a road's travel time; the hierarchy re-prices only the arcs above that road,
  and queries never wait for it

The network is loaded with **GraphBatch**: over HTTP through the batch endpoint (`setup.sh`), or with the Java API in
an embedded database (`embedded/FloridaRoutes.java`).

## Prerequisites

- Docker and Docker Compose
- `curl`, `jq`, `awk` and `gzip`
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

This downloads the Florida road network into `data/` (about 38 MB, once), turns it into the CSV of the batch endpoint,
loads it with one `POST /api/v1/batch` request (GraphBatch on the server: about 11 seconds), names a few junctions after
the cities they are in, creates the `Florida` Graph Analytical View with a contraction hierarchy for `km` and one for
`minutes`, and waits until both are ready.

The load is a 150 MB request, above the server's 100 MB default: `docker-compose.yml` raises
`arcadedb.server.httpBodyContentMaxSize` for it.

### 3a. Run queries via curl

```bash
./queries/queries.sh
```

### 3b. Run queries via Java

```bash
cd java
mvn package -q
java -jar target/route-planning.jar
```

### 3c. Run everything in an embedded database

No server and no build step: `embedded/FloridaRoutes.java` loads the same files with the GraphBatch Java API, creates
the view, compares `dijkstra()`, `astar()` and `cchShortestPath()` on Tallahassee to Coral Gables, and applies the
traffic jam. From this directory, with Java 21+ and the `lib` folder of an ArcadeDB 26.10.2+ distribution:

```bash
java -Xmx4g -cp "$ARCADEDB_HOME/lib/*" embedded/FloridaRoutes.java
```

## Schema

| Type | Kind | Key properties |
|------|------|----------------|
| `Junction` | Vertex | `id` (the DIMACS id, unique index), `lat`, `lon`, `name` (for the 8 named cities, indexed) |
| `ROAD` | Edge | `km`, `minutes` — directed, as in DIMACS: a two-way road is two edges |
| `Florida` | Graph Analytical View | `EDGE TYPES (ROAD) UPDATE MODE SYNCHRONOUS CCH (km, minutes)` |

Named junctions: Tallahassee, Coral Gables, Orlando, Tampa, Jacksonville, Miami, Gainesville, Pensacola.

## Query Patterns

| # | Pattern | Language | Algorithm |
|---|---------|----------|-----------|
| 1 | Fewest Hops | SQL | `shortestPath()` (unweighted) |
| 2 | Dijkstra | SQL | `dijkstra()` |
| 3 | A* | SQL | `astar()` with `lat`/`lon` as heuristic axes |
| 4 | Contraction Hierarchy | SQL + Cypher | `cchShortestPath()`, `algo.cch.shortestPath` |
| 5 | Shortest vs Fastest | Cypher | CCH on `km` vs CCH on `minutes`, each with the other cost of its route |
| 6 | Live Traffic | Cypher | `SET` a road's `minutes`, route again, restore |
| 7 | Which Engine Answered | SQL | `schema:graphAnalyticalViews` hierarchy counters |

What to look for (Apple M5 Pro, through the HTTP API):

- Queries 2 to 4 return the same fastest route, 1,501 junctions and 8 h 18 min: `dijkstra()` in about 3 seconds,
  `astar()` in about 6, `cchShortestPath()` in 2 milliseconds.
- Query 5: the shortest route is 742 km and takes 11 h 19 min; the fastest is 789 km and takes 8 h 18 min.
- Query 6: with four hours of queue on the Turnpike south of Orlando, the fastest route leaves I-75 for I-10 and I-95
  down the Atlantic coast: 8 h 20 min. The hierarchy catches up in about a millisecond. The script restores the road
  afterwards, so it can be run again.
- Query 7: `queries` counts the routes each hierarchy answered, `fallbacks` the ones it handed to bidirectional
  Dijkstra (the answer is exact either way).
- A* is slower than Dijkstra here: to stay exact its estimate may never exceed the cost of any road segment, and the
  fastest segments of the data cap how much the straight line can guide the search.
- Name the edge type in every query (`'ROAD'` in Cypher, `edgeTypeNames: ['ROAD']` in SQL): a query over every edge
  type cannot use a hierarchy built on `ROAD` once the schema has other edge types.

## Data

- [DIMACS 9th Implementation Challenge](https://www.diag.uniroma1.it/challenge9/download.shtml), USA road networks,
  Florida: `USA-road-d.FLA.gr.gz` (lengths), `USA-road-t.FLA.gr.gz` (travel times, the same arcs in the same order) and
  `USA-road-d.FLA.co.gz` (coordinates), derived from the TIGER/Line data of the US Census Bureau.
- `km` is the DIMACS length, in tenths of a meter, divided by 10,000. `minutes` is the DIMACS travel time read as
  millionths of an hour: the file does not state its unit, but with that reading its four road classes drive at 40, 60,
  80 and 100 km/h, and Tallahassee to Coral Gables takes 8 h 18 min.

## ArcadeDB Version Notes

This use case targets ArcadeDB **26.10.2**, the first release with Customizable Contraction Hierarchies. They run on
the server: the Java client only sends queries over HTTP, so any recent `arcadedb-network` works with it.

## Reference

- [ArcadeDB Route Planning use case](https://arcadedb.com/route-planning.html)
- [Shortest Path guide](https://docs.arcadedb.com/arcadedb/reference/graph-algorithms/shortest-path.html)
