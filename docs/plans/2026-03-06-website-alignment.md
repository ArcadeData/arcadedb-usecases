# Website Alignment Plan

Improve use case queries to match the aspirational examples on arcadedb.com, based on
review feedback from [arcadedb-website PR #7](https://github.com/ArcadeData/arcadedb-website/pull/7).

## Context

The website PR replaced code snippets with working queries from this repo. Gemini reviewer
identified 9 places where the replacement weakened the examples — losing multi-model
combinations, temporal analysis, personalization, or business context that the website
sections describe. This plan addresses each gap by enhancing the **repo implementations**
so the website can reference richer, still-working queries.

---

## 1. recommendation-engine

### 1a. Hybrid Recommendations (HIGH)
**Problem:** "The Multi-Model Advantage: All Three in One Query" section only uses graph
(collaborative filtering). The vector and time-series components were removed.

**Current query (Query 4):** SQL MATCH — graph-only collaborative filtering for shows.

**Fix:** Add a new query that combines all three models in a two-step approach (ArcadeDB
can't do cross-model subqueries in a single statement):
- Step 1: Get collaborative-filtering candidates via graph traversal (Cypher)
- Step 2: Re-rank candidates by vector similarity to user's embedding + boost by
  trending score from ProductInteraction time-series data

**Schema change needed:** None — User already has `embedding`, ProductInteraction has
`purchaseCount`/`ts`.

**Files to update:** `queries/queries.sh`, Java, README

### 1b. Personalized Category Ranking (MEDIUM)
**Problem:** Query 5 uses hardcoded vector `[0.9, 0.1, 0.1, 0.1]` instead of the user's
actual preference vector, so ranking isn't truly "personalized."

**Current query:** `ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 30)`

**Fix:** Use `vectorCosineSimilarity()` with a subquery to fetch the user's embedding:
```sql
SELECT name, category, price
FROM Product
WHERE category = 'Electronics' AND inStock = true
ORDER BY vectorCosineSimilarity(
  embedding,
  (SELECT embedding FROM User WHERE id = 'u1' LIMIT 1)
) DESC
LIMIT 30
```

**Verification needed:** Confirm `vectorCosineSimilarity()` accepts a subquery as the
second argument in ArcadeDB 26.3.1. If not, use two-step approach.

**Files to update:** `queries/queries.sh`, Java, README

---

## 2. fraud-detection

### 2a. Structuring Detection with Temporal Analysis (MEDIUM)
**Problem:** Query 4 checks total deposits across all time. The website section describes
detecting structuring within a 24-hour period — temporal bucketing is key to this
fraud pattern.

**Current query:** Simple `GROUP BY account_id` with `count(*) >= 3`.

**Fix:** Add time-bucketing to detect same-day structuring:
```sql
SELECT FROM (
  SELECT account_id,
         ts.timeBucket('1d', ts) AS day,
         count(*) AS deposit_count
  FROM Deposit
  WHERE amount BETWEEN 8000 AND 9999
  GROUP BY account_id, day
) WHERE deposit_count >= 3
```

**Verification needed:** Confirm `ts.timeBucket()` works on DATETIME fields in a
DOCUMENT type (not just time-series data). The Deposit type uses DATETIME for `ts`.
If `ts.timeBucket()` only works with epoch-ms, convert Deposit.ts to epoch-ms format.

**Data impact:** Deposits for acct-A are all on 2026-02-05, acct-B on 2026-02-06,
acct-C on 2026-02-07 — so daily bucketing will correctly detect 3 deposits/day.

**Files to update:** `queries/queries.sh`, Java, README

### 2b. Behavioral Anomaly with Customer Profile Vector (MEDIUM)
**Problem:** Query 5 uses hardcoded vector `[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]`
instead of comparing against the customer's actual `profile_embedding`.

**Current query:** `vectorCosineSimilarity(behavior_embedding, [0.1, ...])`

**Fix:** Use subquery to fetch the customer's profile:
```sql
SELECT id, amount, merchant, account_id,
       vectorCosineSimilarity(
         behavior_embedding,
         (SELECT profile_embedding FROM Customer WHERE id = 'acct-H' LIMIT 1)
       ) AS profile_similarity
FROM Transaction
WHERE account_id = 'acct-H'
ORDER BY profile_similarity
```

**Verification needed:** Same as 1b — confirm subquery works as second arg to
`vectorCosineSimilarity()`.

**Files to update:** `queries/queries.sh`, Java, README

---

## 3. knowledge-graphs

### 3a. Full-Text Search + Graph Context (MEDIUM)
**Problem:** Query 3 only does full-text search. The website section "Full-Text Search
Meets Graph Context" expects a follow-up graph expansion to find authors/concepts.

**Current query:** `SEARCH_INDEX('Paper[abstract]', 'distributed AND consensus')` only.

**Fix:** Add a second step that expands full-text results into the graph:
```cypher
MATCH (p:Paper)<-[:CO_AUTHORED]-(a:Researcher)
WHERE SEARCH_INDEX(p.abstract, 'distributed AND consensus') = true
RETURN p.title, a.name
```

Or as a two-step query:
- Step 1: Full-text search (existing Query 3)
- Step 2: Graph expansion — find co-authors of matching papers

**Verification needed:** Confirm `SEARCH_INDEX()` works inside a Cypher `WHERE` clause.
If not, use hardcoded paper IDs from step 1 (same pattern as Query 5's GraphRAG hybrid).

**Files to update:** `queries/queries.sh`, Java, README

---

## 4. graph-rag

### 4a. Triple Hybrid: Vector + Graph + Full-Text (MEDIUM)
**Problem:** Query 4 ("Composite Scoring") only combines vector + graph (entity count).
The website section "Triple Hybrid" expects vector + graph + full-text.

**Current query:** Vector search + `out('MENTIONS').size()` — no full-text component.

**Fix:** Add full-text filtering to the composite query:
```sql
SELECT content, source,
       out('MENTIONS').size() AS entity_count
FROM Chunk
WHERE content CONTAINSTEXT 'knowledge graph'
ORDER BY vectorNeighbors('Chunk[embedding]', [0.9, 0.2, 0.1, 0.1], 10) DESC
LIMIT 10
```

This combines: vector similarity (ordering), graph context (entity_count), and
full-text filtering (CONTAINSTEXT).

**Verification needed:** Confirm `CONTAINSTEXT` and `vectorNeighbors` can coexist in the
same query. If not, use `SEARCH_INDEX` or restructure as multi-step.

**Files to update:** `queries/queries.sh`, Java, README

---

## 5. supply-chain

### 5a. Blast Radius with Revenue Impact (MEDIUM)
**Problem:** Query 2 returns only component/product/alternatives. The website describes
including `revenue_at_risk` to quantify business impact.

**Current query:** Returns `c.name, p.name, collect(alt.name)`.

**Fix:** Add `p.revenue_annual` to the RETURN clause:
```cypher
MATCH (s:Supplier {name: 'Shenzhen Micro Ltd'})
      -[:SUPPLIES]->(c:Component)
      -[:CONTAINS]->(p:Product)
OPTIONAL MATCH (c)<-[:ALTERNATIVE_FOR]-(alt:Supplier)
RETURN c.name AS component, p.name AS product,
       p.revenue_annual AS revenue_at_risk,
       collect(alt.name) AS alternatives
```

**Schema change needed:** None — Product already has `revenue_annual`.

**Files to update:** `queries/queries.sh`, Java, JS, README

### 5b. Inventory Intelligence (MEDIUM)
**Problem:** Website "Inventory Intelligence" section has duplicated queries from other
sections. Needs a unique query analyzing components at risk based on inventory.

**Fix:** Add a new query that combines warehouse stock data with supplier risk:
```sql
SELECT w.name AS warehouse, w.stock_weeks,
       p.name AS product, p.revenue_annual
FROM (
  MATCH {type: Warehouse, where: (stock_weeks < 5)}{as: w}
        .in('STORED_AT'){as: p}
  RETURN w, p
)
ORDER BY w.stock_weeks ASC
```

This identifies products in warehouses with low stock — a genuine inventory intelligence
query using graph traversal + document properties.

**Files to update:** `queries/queries.sh`, Java, JS, README

### 5c. Recall Simulation (MEDIUM)
**Problem:** Website "End-to-end traceability" section lost the recall simulation query
that traces downstream from a raw material to affected products and customers.

**Fix:** Add a recall simulation query:
```cypher
MATCH (rm:RawMaterial {lot: 'LOT-2026-001'})
      -[:ASSEMBLED_FROM*1..4]->(p:Product)
      -[:SHIPPED_TO]->(c:Customer)
RETURN rm.name AS material, p.name AS product,
       p.sku AS sku, c.customerId AS customer
```

**Files to update:** `queries/queries.sh`, Java, JS, README

---

## 6. realtime-analytics

No review comments targeted this use case's queries. The existing queries already use
`ts.timeBucket()`, `ts.rate()`, `ts.percentile()`, and `ts.interpolate()` correctly.
No changes needed.

---

## 7. New use cases (NOT in scope for this plan)

Three website pages have no repo implementation:
- `customer-360.html`
- `ai-ml-feature-store.html`
- `iam.html`

These would be entirely new use cases, not query improvements. Track separately.

---

## Implementation Strategy

### Ordering
1. **supply-chain** (5a, 5b, 5c) — smallest blast radius, PR #28 is already open
2. **fraud-detection** (2a, 2b) — needs verification of `ts.timeBucket()` on DOCUMENT types
3. **recommendation-engine** (1a, 1b) — needs verification of subquery in vectorCosineSimilarity
4. **knowledge-graphs** (3a) — needs verification of SEARCH_INDEX in Cypher WHERE
5. **graph-rag** (4a) — needs verification of CONTAINSTEXT + vectorNeighbors combo

### Verification approach
Items 2a, 2b, 1b, 3a, 4a all depend on ArcadeDB 26.3.1 supporting specific syntax
combinations. Before implementing, spin up a local ArcadeDB instance and test each
query pattern. If a pattern fails, fall back to multi-step queries (which always work).

### Per-use-case checklist
For each change:
- [ ] Update `queries/queries.sh` (curl)
- [ ] Update Java source
- [ ] Update JS source (supply-chain only)
- [ ] Update README query descriptions
- [ ] Run CI to verify
- [ ] Update website PR queries to match

### Branching
- One branch per use case: `feat/website-alignment-<use-case>`
- Or a single branch `feat/website-alignment` with per-use-case commits
