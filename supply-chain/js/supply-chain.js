const { Client } = require('pg');

const HOST     = process.env.ARCADEDB_HOST    || 'localhost';
const PG_PORT  = process.env.ARCADEDB_PG_PORT || '5432';
const DB_NAME  = 'SupplyChain';
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

// Query 1: Multi-Tier Supplier Discovery (SQL MATCH — Postgres protocol only supports SQL)
async function runQuery1(client) {
  printHeader('Query 1: Multi-Tier Supplier Discovery',
    'Find all suppliers (up to 4 tiers) feeding into Widget Pro X.');

  const sql = `
    SELECT DISTINCT name, country, risk_score
    FROM (
      MATCH {type: Product, where: (sku = 'WIDGET-PRO-X')}
            .in('CONTAINS'){as: c}
            .in('SUPPLIES'){as: s, while: ($depth < 4)}
      RETURN s.name AS name, s.country AS country, s.risk_score AS risk_score
    )
    ORDER BY risk_score DESC`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.name).padEnd(25)} | ${String(row.country).padEnd(15)} | risk: ${row.risk_score}`);
  }
}

// Query 2: Blast Radius Analysis (two SQL MATCH queries — no OPTIONAL MATCH in SQL)
async function runQuery2(client) {
  printHeader('Query 2: Blast Radius Analysis',
    'If Shenzhen Micro Ltd is disrupted, which products are affected?');

  const sqlAffected = `
    SELECT component, product
    FROM (
      MATCH {type: Supplier, where: (name = 'Shenzhen Micro Ltd')}
            .out('SUPPLIES'){as: c}
            .out('CONTAINS'){as: p}
      RETURN c.name AS component, p.name AS product
    )`;

  const sqlAlternatives = `
    SELECT alternative, component
    FROM (
      MATCH {type: Supplier, where: (name = 'Shenzhen Micro Ltd')}
            .out('SUPPLIES'){as: c}
            .in('ALTERNATIVE_FOR'){as: alt}
      RETURN alt.name AS alternative, c.name AS component
    )`;

  const affected = await client.query(sqlAffected);
  const alternatives = await client.query(sqlAlternatives);

  const altMap = {};
  for (const row of alternatives.rows) {
    const comp = row.component;
    if (!altMap[comp]) altMap[comp] = [];
    altMap[comp].push(row.alternative);
  }

  for (const row of affected.rows) {
    const alts = altMap[row.component] || [];
    console.log(`  ${String(row.component).padEnd(20)} | ${String(row.product).padEnd(20)} | alternatives: [${alts.join(', ')}]`);
  }
}

// Query 3: Delivery Disruption Detection (pure SQL — identical to shell/Java)
async function runQuery3(client) {
  printHeader('Query 3: Delivery Disruption Detection',
    'Identify suppliers with delivery issues from DeliveryMetric records.');

  const sql = `
    SELECT supplierId,
           avg(lead_time_hrs) AS avg_lead_time,
           sum(CASE WHEN delayed = true THEN 1 ELSE 0 END) AS total_delayed,
           count(*) AS total_deliveries
    FROM DeliveryMetric
    GROUP BY supplierId
    ORDER BY total_delayed DESC`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    const supplier = String(row.supplierid || row.supplierId);
    const avgTime = Number(row.avg_lead_time).toFixed(0);
    console.log(`  ${supplier.padEnd(25)} | avg: ${avgTime.padStart(6)} hrs | delayed: ${row.total_delayed}/${row.total_deliveries}`);
  }
}

// Query 4: Vector-Based Alternative Sourcing (pure SQL — identical to shell/Java)
async function runQuery4(client) {
  printHeader('Query 4: Vector-Based Alternative Sourcing',
    'Find suppliers with capabilities similar to Shenzhen Micro Ltd [0.9, 0.2, 0.1, 0.1].');

  const sql = `
    SELECT name, country, risk_score
    FROM Supplier
    WHERE status = 'active'
    ORDER BY vectorNeighbors('Supplier[capability_vec]', [0.9, 0.2, 0.1, 0.1], 10) DESC
    LIMIT 5`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.name).padEnd(25)} | ${String(row.country).padEnd(15)} | risk: ${row.risk_score}`);
  }
}

// Query 5: End-to-End Batch Traceability (SQL MATCH)
async function runQuery5(client) {
  printHeader('Query 5: End-to-End Batch Traceability',
    'Trace all raw materials in batch BATCH-2026-0218 through the assembly chain.');

  const sql = `
    SELECT name, origin, certification, lot
    FROM (
      MATCH {type: Product, where: (batchId = 'BATCH-2026-0218')}
            .in('ASSEMBLED_FROM'){as: material, while: ($depth < 8)}
      RETURN material.name AS name, material.origin AS origin,
             material.certification AS certification, material.lot AS lot
    )`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.name).padEnd(25)} | origin: ${String(row.origin || '-').padEnd(10)} | cert: ${String(row.certification || '-').padEnd(10)} | lot: ${row.lot || '-'}`);
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
    await tryRun(() => runQuery1(client), 'Query 1');
    await tryRun(() => runQuery2(client), 'Query 2');
    await tryRun(() => runQuery3(client), 'Query 3');
    await tryRun(() => runQuery4(client), 'Query 4');
    await tryRun(() => runQuery5(client), 'Query 5');
  } finally {
    await client.end();
  }
  console.log('\nAll queries complete.');
}

main();
