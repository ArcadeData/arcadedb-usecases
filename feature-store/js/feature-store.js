const { Client } = require('pg');

const HOST     = process.env.ARCADEDB_HOST    || 'localhost';
const PG_PORT  = process.env.ARCADEDB_PG_PORT || '5432';
const DB_NAME  = 'FeatureStore';
const USER     = process.env.ARCADEDB_USER    || 'root';
const PASSWORD = process.env.ARCADEDB_PASS    || 'arcadedb';

function printHeader(title, description) {
  console.log('\n' + '='.repeat(70));
  console.log('  ' + title);
  console.log('  ' + description);
  console.log('='.repeat(70));
}

async function tryRun(fn, name) {
  try {
    await fn();
  } catch (e) {
    console.error('[' + name + ' FAILED] ' + e.message);
  }
}

// ── Query 1: Account Graph Features (SQL MATCH) ─────────────────────────────
async function runQuery1(client) {
  printHeader('Query 1: Account Graph Features (SQL MATCH)',
    'Compute graph topology features for account a4.');

  const sql = `
    SELECT inDeg, outDeg, counterparties
    FROM (
      MATCH {type: Account, where: (accountId = 'a4'), as: acct}
      RETURN acct.in('TRANSFERRED').size() AS inDeg,
             acct.out('TRANSFERRED').size() AS outDeg,
             acct.both('TRANSFERRED').size() AS counterparties
    )`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  inDeg: ${row.indeg} | outDeg: ${row.outdeg} | counterparties: ${row.counterparties}`);
  }
}

// ── Query 2: Distance to Flagged Account (SQL MATCH) ────────────────────────
async function runQuery2(client) {
  printHeader('Query 2: Distance to Flagged Account (SQL MATCH)',
    'Find shortest path from a4 to nearest flagged account via transfers.');

  const sql = `
    SELECT flaggedId, depth
    FROM (
      MATCH {type: Account, where: (accountId = 'a4')}
            .both('TRANSFERRED'){while: ($depth < 4), as: hop}
            {type: Account, where: (flagged = true), as: flagged}
      RETURN flagged.accountId AS flaggedId, $depth AS depth
    )
    ORDER BY depth ASC
    LIMIT 1`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  flagged: ${row.flaggedid} | depth: ${row.depth}`);
  }
}

// ── Query 3: Behavior Similarity Search (SQL) ───────────────────────────────
async function runQuery3(client) {
  printHeader('Query 3: Behavior Similarity Search (SQL)',
    'Find accounts with behavior vectors similar to flagged a6 [0.9,0.8,0.1,0.2].');

  const sql = `
    SELECT accountId, accountType, flagged
    FROM Account
    ORDER BY vectorNeighbors('Account[behaviorVec]', [0.9, 0.8, 0.1, 0.2], 10) DESC
    LIMIT 5`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.accountid).padEnd(5)} | type: ${String(row.accounttype).padEnd(10)} | flagged: ${row.flagged}`);
  }
}

// ── Query 4: Transaction Velocity (SQL) ─────────────────────────────────────
async function runQuery4(client) {
  printHeader('Query 4: Transaction Velocity (SQL)',
    'Aggregate TransactionMetric for velocity features per account.');

  const sql = `
    SELECT accountId,
           sum(txCount) AS totalTx,
           sum(totalAmount) AS totalAmount,
           avg(totalAmount) AS avgBucketAmount
    FROM TransactionMetric
    GROUP BY accountId
    ORDER BY totalTx DESC`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.accountid).padEnd(5)} | totalTx: ${String(row.totaltx).padStart(4)} | totalAmount: ${String(row.totalamount).padStart(10)} | avgBucket: ${row.avgbucketamount}`);
  }
}

// ── Query 5: Shared Device Network (Cypher via {cypher} prefix) ─────────────
async function runQuery5(client) {
  printHeader('Query 5: Shared Device Network (Cypher)',
    'Find accounts sharing devices with flagged accounts.');

  const sql = `{cypher} MATCH (flagged:Account {flagged: true})
      -[:LINKED_DEVICE]-(suspect:Account)
    WHERE suspect.flagged = false
    RETURN DISTINCT suspect.accountId, suspect.accountType,
           flagged.accountId AS linkedToFlagged`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    const accountId = row['suspect.accountid'] || row['suspect.accountId'];
    const accountType = row['suspect.accounttype'] || row['suspect.accountType'];
    const linked = row['linkedtoflagged'] || row['linkedToFlagged'];
    console.log(`  ${accountId} | type: ${accountType} | linked to: ${linked}`);
  }
}

// ── Query 6: Collaborative Filtering (Cypher via {cypher} prefix) ───────────
async function runQuery6(client) {
  printHeader('Query 6: Collaborative Filtering (Cypher)',
    'Find products to recommend to u1 based on shared purchases.');

  const sql = `{cypher} MATCH (me:User {userId: 'u1'})
      -[:PURCHASED]->(p:Product)
      <-[:PURCHASED]-(other:User)
      -[:PURCHASED]->(rec:Product)
    WHERE rec <> p
      AND NOT (me)-[:PURCHASED]->(rec)
    RETURN rec.name, rec.category, count(DISTINCT other) AS score
    ORDER BY score DESC LIMIT 10`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    const name = row['rec.name'];
    const category = row['rec.category'];
    console.log(`  ${String(name).padEnd(20)} | ${String(category).padEnd(12)} | score: ${row.score}`);
  }
}

// ── Query 7: Product Embedding Search (SQL) ─────────────────────────────────
async function runQuery7(client) {
  printHeader('Query 7: Product Embedding Search (SQL)',
    'Find products similar to Laptop embedding [0.9,0.1,0.1,0.1].');

  const sql = `
    SELECT name, category, price
    FROM Product
    ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 10) DESC
    LIMIT 5`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.name).padEnd(20)} | ${String(row.category).padEnd(12)} | $${row.price}`);
  }
}

// ── Query 8: Personalized Ranking (Cypher via {cypher} prefix) ──────────────
async function runQuery8(client) {
  printHeader('Query 8: Personalized Ranking (SQL)',
    'Rank Electronics products for u1 by preference vector similarity.');

  const sql = `
    SELECT name, price
    FROM Product
    WHERE category = 'Electronics'
    ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 20) DESC
    LIMIT 10`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.name).padEnd(20)} | $${row.price}`);
  }
}

// ── Query 9: Equipment Dependency Chain (SQL MATCH) ─────────────────────────
async function runQuery9(client) {
  printHeader('Query 9: Equipment Dependency Chain (SQL MATCH)',
    'Find all downstream equipment affected if eq1 fails.');

  const sql = `
    SELECT name, failureRate, criticality
    FROM (
      MATCH {type: Equipment, where: (equipmentId = 'eq1')}
            .in('DEPENDS_ON'){as: dep}
      RETURN dep.name AS name, dep.failureRate AS failureRate,
             dep.out('DEPENDS_ON')[0].criticality AS criticality
    )`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.name).padEnd(20)} | failureRate: ${row.failurerate} | criticality: ${row.criticality}`);
  }
}

// ── Query 10: Sensor Anomaly Detection (SQL) ────────────────────────────────
async function runQuery10(client) {
  printHeader('Query 10: Sensor Anomaly Detection (SQL)',
    'Find equipment with anomalous sensor readings.');

  const sql = `
    SELECT equipmentId,
           avg(temperature) AS avgTemp,
           max(vibration) AS maxVibration,
           avg(pressure) AS avgPressure
    FROM SensorReading
    GROUP BY equipmentId
    ORDER BY avgTemp DESC`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.equipmentid).padEnd(5)} | avgTemp: ${Number(row.avgtemp).toFixed(1).padStart(6)} | maxVib: ${Number(row.maxvibration).toFixed(1).padStart(4)} | avgPressure: ${Number(row.avgpressure).toFixed(1)}`);
  }
}

// ── Query 11: Feature Vector Assembly (Multi-step) ──────────────────────────
async function runQuery11(client) {
  printHeader('Query 11: Feature Vector Assembly (Multi-step)',
    'Assemble a fraud feature vector for account a4.');

  // Step 1: Graph features
  console.log('  --- Step 1: Graph features (degree + counterparties) ---');
  const graphSql = `
    SELECT inDeg, outDeg, counterparties
    FROM (
      MATCH {type: Account, where: (accountId = 'a4'), as: acct}
      RETURN acct.in('TRANSFERRED').size() AS inDeg,
             acct.out('TRANSFERRED').size() AS outDeg,
             acct.both('TRANSFERRED').size() AS counterparties
    )`;

  const graphRes = await client.query(graphSql);
  for (const row of graphRes.rows) {
    console.log(`    inDeg: ${row.indeg} | outDeg: ${row.outdeg} | counterparties: ${row.counterparties}`);
  }

  // Step 2: Vector features
  console.log('  --- Step 2: Vector features (similarity rank to known fraud) ---');
  const vectorSql = `
    SELECT accountId, flagged
    FROM Account
    ORDER BY vectorNeighbors('Account[behaviorVec]', [0.7, 0.6, 0.2, 0.3], 10) DESC
    LIMIT 5`;

  const vectorRes = await client.query(vectorSql);
  for (const row of vectorRes.rows) {
    console.log(`    ${row.accountid} | flagged: ${row.flagged}`);
  }

  // Step 3: Time-series features
  console.log('  --- Step 3: Time-series features (transaction velocity) ---');
  const tsSql = `
    SELECT sum(txCount) AS totalTx,
           sum(totalAmount) AS totalAmount,
           avg(totalAmount) AS avgBucketAmount
    FROM TransactionMetric
    WHERE accountId = 'a4'`;

  const tsRes = await client.query(tsSql);
  for (const row of tsRes.rows) {
    console.log(`    totalTx: ${row.totaltx} | totalAmount: ${row.totalamount} | avgBucket: ${row.avgbucketamount}`);
  }

  // Step 4: Store feature snapshot
  console.log('  --- Step 4: Store feature snapshot ---');
  const insertSql = `
    INSERT INTO FeatureSnapshot SET entityId = 'a4', entityType = 'Account',
      featureVector = [8, 6, 3, 67, 145000, 0.87],
      computedAt = '2026-03-23 00:00:00', modelVersion = 'fraud-v2.2'`;

  await client.query(insertSql);
  console.log('    (Snapshot stored)');

  // Verify
  console.log('  --- Verify: Feature snapshots for a4 ---');
  const verifySql = `
    SELECT entityId, modelVersion, computedAt
    FROM FeatureSnapshot
    WHERE entityId = 'a4'
    ORDER BY computedAt DESC`;

  const verifyRes = await client.query(verifySql);
  for (const row of verifyRes.rows) {
    console.log(`    ${row.entityid} | version: ${row.modelversion} | computed: ${row.computedat}`);
  }
}

async function main() {
  const client = new Client({
    host: HOST,
    port: parseInt(PG_PORT),
    database: DB_NAME,
    user: USER,
    password: PASSWORD,
  });

  await client.connect();
  console.log('Connected to ArcadeDB via PostgreSQL protocol on port ' + PG_PORT);

  try {
    console.log('========== FRAUD DOMAIN ==========');
    await tryRun(() => runQuery1(client), 'Query 1');
    await tryRun(() => runQuery2(client), 'Query 2');
    await tryRun(() => runQuery3(client), 'Query 3');
    await tryRun(() => runQuery4(client), 'Query 4');
    await tryRun(() => runQuery5(client), 'Query 5');

    console.log('\n========== RECOMMENDATION DOMAIN ==========');
    await tryRun(() => runQuery6(client), 'Query 6');
    await tryRun(() => runQuery7(client), 'Query 7');
    await tryRun(() => runQuery8(client), 'Query 8');

    console.log('\n========== MAINTENANCE DOMAIN ==========');
    await tryRun(() => runQuery9(client), 'Query 9');
    await tryRun(() => runQuery10(client), 'Query 10');

    console.log('\n========== CROSS-DOMAIN ==========');
    await tryRun(() => runQuery11(client), 'Query 11');
  } finally {
    await client.end();
  }
  console.log('\nAll queries complete.');
}

main();
