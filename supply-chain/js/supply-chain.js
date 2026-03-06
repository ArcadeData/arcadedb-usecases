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
    SELECT component, product, revenue_at_risk
    FROM (
      MATCH {type: Supplier, where: (name = 'Shenzhen Micro Ltd')}
            .out('SUPPLIES'){as: c}
            .out('CONTAINS'){as: p}
      RETURN c.name AS component, p.name AS product, p.revenue_annual AS revenue_at_risk
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
    const rev = Number(row.revenue_at_risk || 0).toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
    console.log(`  ${String(row.component).padEnd(20)} | ${String(row.product).padEnd(20)} | revenue: ${rev.padStart(12)} | alternatives: [${alts.join(', ')}]`);
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

// Query 6: Inventory Intelligence (pure SQL MATCH)
async function runQuery6(client) {
  printHeader('Query 6: Inventory Intelligence',
    'Identify products in warehouses with low stock (< 5 weeks).');

  const sql = `
    SELECT warehouse, stock_weeks, product, revenue_annual
    FROM (
      MATCH {type: Warehouse, where: (stock_weeks < 5)}{as: w}
            .in('STORED_AT'){as: p}
      RETURN w.name AS warehouse, w.stock_weeks AS stock_weeks,
             p.name AS product, p.revenue_annual AS revenue_annual
    )
    ORDER BY stock_weeks ASC`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    const rev = Number(row.revenue_annual || 0).toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
    console.log(`  ${String(row.warehouse).padEnd(15)} | ${String(row.stock_weeks).padStart(2)} weeks | ${String(row.product).padEnd(20)} | revenue: ${rev}`);
  }
}

// Query 7: Recall Simulation (SQL MATCH — Cypher not available over PostgreSQL protocol)
// Data path: RawMaterial -> Component -> Product (2 ASSEMBLED_FROM hops), then SHIPPED_TO -> Customer
async function runQuery7(client) {
  printHeader('Query 7: Recall Simulation',
    'Trace downstream from raw material lot LOT-2026-001 to affected products and customers.');

  const sql = `
    SELECT material, product, sku, customer
    FROM (
      MATCH {type: RawMaterial, where: (lot = 'LOT-2026-001')}{as: rm}
            .out('ASSEMBLED_FROM'){as: comp}
            .out('ASSEMBLED_FROM'){as: p}
            .out('SHIPPED_TO'){as: c}
      RETURN rm.name AS material, p.name AS product,
             p.sku AS sku, c.customerId AS customer
    )`;

  const res = await client.query(sql);
  for (const row of res.rows) {
    console.log(`  ${String(row.material).padEnd(20)} | ${String(row.product).padEnd(20)} | sku: ${String(row.sku).padEnd(15)} | customer: ${row.customer}`);
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
    await tryRun(() => runQuery6(client), 'Query 6');
    await tryRun(() => runQuery7(client), 'Query 7');
  } finally {
    await client.end();
  }
  console.log('\nAll queries complete.');
}

main();
