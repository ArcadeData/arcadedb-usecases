# Route Planning — Design Document

**Date:** 2026-10-13
**Branch:** `feat/route-planning`
**Database:** `RoutePlanning`
**ArcadeDB Version:** 26.10.2 (the first release with Customizable Contraction Hierarchies), server and client
**Connectivity:** HTTP API (`arcadedb-network`) and the batch endpoint; `embedded/` uses the Java API

## Overview

Shortest paths on the real Florida road network of the 9th DIMACS Implementation Challenge (1,070,376 junctions,
2,712,798 road segments), Tallahassee to Coral Gables: fewest hops, `dijkstra()`, `astar()`, Customizable Contraction
Hierarchies (CCH) kept on a Graph Analytical View, shortest against fastest, and a live traffic update. Based on the
scenario at https://arcadedb.com/route-planning.html and the Shortest Path guide in the documentation, which use the
same data, route and numbers.

**Key differentiators:** the only use case built on a Graph Analytical View; the only one loading a real data set of
millions of records, through GraphBatch (the HTTP batch endpoint, and the Java API in the embedded variant); the only
one whose answers come from a precomputed structure that has to follow writes.

## Directory Structure

```
route-planning/
├── docker-compose.yml          # ArcadeDB 26.10.2 (port 2480), httpBodyContentMaxSize raised for the 150 MB load
├── setup.sh                    # Downloads DIMACS FLA into data/, builds the batch CSV, loads it, names cities, view
├── sql/
│   ├── 01-schema.sql           # Junction vertex (id, lat, lon, name), ROAD edge (km, minutes)
│   ├── 02-places.sql           # id index, 8 named junctions, name index
│   └── 03-view.sql             # CREATE GRAPH ANALYTICAL VIEW Florida ... CCH (km, minutes)
├── queries/
│   └── queries.sh              # 7 query sections via curl, SQL + Cypher, with timings; one SET pair
├── java/
│   ├── pom.xml                 # arcadedb-network 26.10.2, fat JAR
│   └── src/main/java/com/arcadedb/examples/RoutePlanning.java
├── embedded/
│   └── FloridaRoutes.java      # single-file program: GraphBatch Java API load + the same story, embedded
├── .gitignore                  # data/
└── README.md
```

## Data

- `USA-road-d.FLA.gr.gz` (lengths, tenths of a meter), `USA-road-t.FLA.gr.gz` (travel times: the same arcs in the same
  order) and `USA-road-d.FLA.co.gz` (coordinates, millionths of a degree), downloaded once into `data/` (gitignored,
  cached in CI).
- `km` = length / 10,000; `minutes` = travel time x 0.00006 (millionths of an hour: the four road classes then drive at
  40/60/80/100 km/h; the unit is not stated by DIMACS).
- Vertices are loaded in DIMACS order with `refMode=ordinal&ordinalBase=1`, so edges name their junctions by DIMACS id.
- Arcs are directed, as in DIMACS; queries use `OUT`, so the hierarchy's directed metric (prepared from the start) answers.

## Readiness

`setup.sh` polls `schema:graphAnalyticalViews` until both hierarchies are `READY` (about 7 seconds after the view is
created). Queries before that are answered exactly by bidirectional Dijkstra.

## Query Patterns

| # | Pattern | Expected result |
|---|---------|-----------------|
| 1 | `shortestPath()` | 1,064 road segments |
| 2 | `dijkstra()` by `minutes` | 1,501 junctions, about 3 s |
| 3 | `astar()` (`lat`/`lon`, `dFactor` 57) | same 1,501 junctions, about 6 s |
| 4 | `cchShortestPath()` + `algo.cch.shortestPath` | same route, 498.0 minutes, about 2 ms |
| 5 | CCH by `km` vs by `minutes` | 742.2 km / 679.1 min vs 788.6 km / 498.0 min |
| 6 | Cypher `SET` on the Turnpike segment 702459 -> 702911 to 240 min, restore to 6.3009 | 500.1 min, 825.7 km via I-10 and I-95 |
| 7 | `schema:graphAnalyticalViews` | both hierarchies `READY`, 0 fallbacks |
