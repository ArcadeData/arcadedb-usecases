package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class SupplyChain {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "SupplyChain";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1MultiTierDiscovery(db), "Query 1");
      tryRun(() -> runQuery2BlastRadius(db), "Query 2");
      tryRun(() -> runQuery3DisruptionDetection(db), "Query 3");
      tryRun(() -> runQuery4AlternativeSourcing(db), "Query 4");
      tryRun(() -> runQuery5Traceability(db), "Query 5");
    }
    System.out.println("\nAll queries complete.");
  }

  private static void tryRun(Runnable r, String name) {
    try {
      r.run();
    } catch (Exception e) {
      System.err.println("[" + name + " FAILED] " + e.getMessage());
    }
  }

  // Query 1: Multi-Tier Supplier Discovery
  private static void runQuery1MultiTierDiscovery(RemoteDatabase db) {
    printHeader("Query 1: Multi-Tier Supplier Discovery",
        "Find all suppliers (up to 4 tiers) feeding into Widget Pro X.");

    String cypher =
        """
            MATCH (p:Product {sku: 'WIDGET-PRO-X'})
                  <-[:CONTAINS]-(c:Component)
                  <-[:SUPPLIES*1..4]-(s:Supplier)
            RETURN DISTINCT s.name, s.country, s.risk_score
            ORDER BY s.risk_score DESC""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | %-15s | risk: %s%n",
            r.getProperty("s.name"),
            r.getProperty("s.country"),
            r.getProperty("s.risk_score"));
      }
    }
  }

  // Query 2: Blast Radius Analysis
  private static void runQuery2BlastRadius(RemoteDatabase db) {
    printHeader("Query 2: Blast Radius Analysis",
        "If Shenzhen Micro Ltd is disrupted, which products are affected?");

    String cypher =
        """
            MATCH (s:Supplier {name: 'Shenzhen Micro Ltd'})
                  -[:SUPPLIES]->(c:Component)
                  -[:CONTAINS]->(p:Product)
            OPTIONAL MATCH (c)<-[:ALTERNATIVE_FOR]-(alt:Supplier)
            RETURN c.name AS component, p.name AS product, collect(alt.name) AS alternatives""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-20s | alternatives: %s%n",
            r.getProperty("component"),
            r.getProperty("product"),
            r.getProperty("alternatives"));
      }
    }
  }

  // Query 3: Delivery Disruption Detection
  private static void runQuery3DisruptionDetection(RemoteDatabase db) {
    printHeader("Query 3: Delivery Disruption Detection",
        "Identify suppliers with delivery issues from DeliveryMetric records.");

    String sql =
        """
            SELECT supplierId,
                   avg(lead_time_hrs) AS avg_lead_time,
                   sum(CASE WHEN delayed = true THEN 1 ELSE 0 END) AS total_delayed,
                   count(*) AS total_deliveries
            FROM DeliveryMetric
            GROUP BY supplierId
            ORDER BY total_delayed DESC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | avg: %6.0f hrs | delayed: %s/%s%n",
            r.getProperty("supplierId"),
            ((Number) r.getProperty("avg_lead_time")).doubleValue(),
            r.getProperty("total_delayed"),
            r.getProperty("total_deliveries"));
      }
    }
  }

  // Query 4: Vector-Based Alternative Sourcing
  private static void runQuery4AlternativeSourcing(RemoteDatabase db) {
    printHeader("Query 4: Vector-Based Alternative Sourcing",
        "Find suppliers with capabilities similar to Shenzhen Micro Ltd [0.9, 0.2, 0.1, 0.1].");

    String sql =
        """
            SELECT name, country, risk_score
            FROM Supplier
            WHERE status = 'active'
            ORDER BY vectorNeighbors('Supplier[capability_vec]', [0.9, 0.2, 0.1, 0.1], 10) DESC
            LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | %-15s | risk: %.2f%n",
            r.getProperty("name"),
            r.getProperty("country"),
            ((Number) r.getProperty("risk_score")).doubleValue());
      }
    }
  }

  // Query 5: End-to-End Batch Traceability
  private static void runQuery5Traceability(RemoteDatabase db) {
    printHeader("Query 5: End-to-End Batch Traceability",
        "Trace all raw materials in batch BATCH-2026-0218 through the assembly chain.");

    String cypher =
        """
            MATCH (p:Product {batch: 'BATCH-2026-0218'})
                  <-[:ASSEMBLED_FROM*1..8]-(material)
            RETURN material.name, material.origin, material.certification, material.lot""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | origin: %-10s | cert: %-10s | lot: %s%n",
            r.getProperty("material.name"),
            r.getProperty("material.origin"),
            r.getProperty("material.certification"),
            r.getProperty("material.lot"));
      }
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }
}
