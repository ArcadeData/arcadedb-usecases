package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class FeatureStore {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "FeatureStore";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      System.out.println("========== FRAUD DOMAIN ==========");
      tryRun(() -> runQuery1AccountGraphFeatures(db), "Query 1");
      tryRun(() -> runQuery2DistanceToFlagged(db), "Query 2");
      tryRun(() -> runQuery3BehaviorSimilarity(db), "Query 3");
      tryRun(() -> runQuery4TransactionVelocity(db), "Query 4");
      tryRun(() -> runQuery5SharedDeviceNetwork(db), "Query 5");

      System.out.println("\n========== RECOMMENDATION DOMAIN ==========");
      tryRun(() -> runQuery6CollaborativeFiltering(db), "Query 6");
      tryRun(() -> runQuery7ProductEmbeddingSearch(db), "Query 7");
      tryRun(() -> runQuery8CategoryVectorSearch(db), "Query 8");

      System.out.println("\n========== MAINTENANCE DOMAIN ==========");
      tryRun(() -> runQuery9EquipmentDependencyChain(db), "Query 9");
      tryRun(() -> runQuery10SensorAnomalyDetection(db), "Query 10");

      System.out.println("\n========== CROSS-DOMAIN ==========");
      tryRun(() -> runQuery11FeatureVectorAssembly(db), "Query 11");
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

  // ── Query 1: Account Graph Features (SQL MATCH) ────────────────────────────
  private static void runQuery1AccountGraphFeatures(RemoteDatabase db) {
    printHeader("Query 1: Account Graph Features (SQL MATCH)",
        "Compute graph topology features for account a4.");

    String sql =
        """
            SELECT inDeg, outDeg, counterparties
            FROM (
              MATCH {type: Account, where: (accountId = 'a4'), as: acct}
              RETURN acct.in('TRANSFERRED').size() AS inDeg,
                     acct.out('TRANSFERRED').size() AS outDeg,
                     acct.both('TRANSFERRED').size() AS counterparties
            )""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  inDeg: " + r.getProperty("inDeg")
            + " | outDeg: " + r.getProperty("outDeg")
            + " | counterparties: " + r.getProperty("counterparties"));
      }
    }
  }

  // ── Query 2: Distance to Flagged Account (SQL MATCH) ───────────────────────
  private static void runQuery2DistanceToFlagged(RemoteDatabase db) {
    printHeader("Query 2: Distance to Flagged Account (SQL MATCH)",
        "Find shortest path from a4 to nearest flagged account via transfers.");

    String sql =
        """
            SELECT accountId AS flaggedId, depth
            FROM (
              MATCH {type: Account, where: (accountId = 'a4')}
                    .both('TRANSFERRED'){while: ($depth < 4), as: hop}
              RETURN hop.accountId AS accountId, hop.flagged AS flagged, $depth AS depth
            )
            WHERE flagged = true
            ORDER BY depth ASC
            LIMIT 1""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  flagged: " + r.getProperty("flaggedId")
            + " | depth: " + r.getProperty("depth"));
      }
    }
  }

  // ── Query 3: Behavior Similarity Search (SQL) ──────────────────────────────
  private static void runQuery3BehaviorSimilarity(RemoteDatabase db) {
    printHeader("Query 3: Behavior Similarity Search (SQL)",
        "Find accounts with behavior vectors similar to flagged a6 [0.9,0.8,0.1,0.2].");

    String sql =
        """
            SELECT accountId, accountType, flagged
            FROM Account
            ORDER BY vectorNeighbors('Account[behaviorVec]', [0.9, 0.8, 0.1, 0.2], 10) DESC
            LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  " + r.getProperty("accountId")
            + " | type: " + r.getProperty("accountType")
            + " | flagged: " + r.getProperty("flagged"));
      }
    }
  }

  // ── Query 4: Transaction Velocity (SQL) ────────────────────────────────────
  private static void runQuery4TransactionVelocity(RemoteDatabase db) {
    printHeader("Query 4: Transaction Velocity (SQL)",
        "Aggregate TransactionMetric for velocity features per account.");

    String sql =
        """
            SELECT accountId,
                   sum(txCount) AS totalTx,
                   sum(totalAmount) AS totalAmount,
                   avg(totalAmount) AS avgBucketAmount
            FROM TransactionMetric
            GROUP BY accountId
            ORDER BY totalTx DESC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  " + r.getProperty("accountId")
            + " | totalTx: " + r.getProperty("totalTx")
            + " | totalAmount: " + r.getProperty("totalAmount")
            + " | avgBucket: " + r.getProperty("avgBucketAmount"));
      }
    }
  }

  // ── Query 5: Shared Device Network (Cypher) ────────────────────────────────
  private static void runQuery5SharedDeviceNetwork(RemoteDatabase db) {
    printHeader("Query 5: Shared Device Network (Cypher)",
        "Find accounts sharing devices with flagged accounts.");

    String cypher =
        """
            MATCH (flagged:Account {flagged: true})
                  -[:LINKED_DEVICE]-(suspect:Account)
            WHERE suspect.flagged = false
            RETURN DISTINCT suspect.accountId, suspect.accountType,
                   flagged.accountId AS linkedToFlagged""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  " + r.getProperty("suspect.accountId")
            + " | type: " + r.getProperty("suspect.accountType")
            + " | linked to: " + r.getProperty("linkedToFlagged"));
      }
    }
  }

  // ── Query 6: Collaborative Filtering (Cypher) ──────────────────────────────
  private static void runQuery6CollaborativeFiltering(RemoteDatabase db) {
    printHeader("Query 6: Collaborative Filtering (Cypher)",
        "Find products to recommend to u1 based on shared purchases.");

    String cypher =
        """
            MATCH (me:User {userId: 'u1'})
                  -[:PURCHASED]->(p:Product)
                  <-[:PURCHASED]-(other:User)
                  -[:PURCHASED]->(rec:Product)
            WHERE rec <> p
              AND NOT (me)-[:PURCHASED]->(rec)
            RETURN rec.name, rec.category, count(DISTINCT other) AS score
            ORDER BY score DESC LIMIT 10""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  " + r.getProperty("rec.name")
            + " | " + r.getProperty("rec.category")
            + " | score: " + r.getProperty("score"));
      }
    }
  }

  // ── Query 7: Product Embedding Search (SQL) ────────────────────────────────
  private static void runQuery7ProductEmbeddingSearch(RemoteDatabase db) {
    printHeader("Query 7: Product Embedding Search (SQL)",
        "Find products similar to Laptop embedding [0.9,0.1,0.1,0.1].");

    String sql =
        """
            SELECT name, category, price
            FROM Product
            ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 10) DESC
            LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-12s | $%-8.2f%n",
            r.getProperty("name"),
            r.getProperty("category"),
            ((Number) r.getProperty("price")).doubleValue());
      }
    }
  }

  // ── Query 8: Category Vector Search (SQL) ───────────────────────────────────
  private static void runQuery8CategoryVectorSearch(RemoteDatabase db) {
    printHeader("Query 8: Category Vector Search (SQL)",
        "Rank Electronics products by similarity to u1 preference [0.9,0.1,0.1,0.1].");

    String sql =
        """
            SELECT name, price
            FROM Product
            WHERE category = 'Electronics'
            ORDER BY vectorNeighbors('Product[embedding]', [0.9, 0.1, 0.1, 0.1], 20) DESC
            LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | $%-8.2f%n",
            r.getProperty("name"),
            ((Number) r.getProperty("price")).doubleValue());
      }
    }
  }

  // ── Query 9: Equipment Dependency Chain (SQL MATCH) ────────────────────────
  private static void runQuery9EquipmentDependencyChain(RemoteDatabase db) {
    printHeader("Query 9: Equipment Dependency Chain (SQL MATCH)",
        "Find all downstream equipment affected if eq1 fails.");

    String sql =
        """
            SELECT name, failureRate, criticality, depth
            FROM (
              MATCH {type: Equipment, where: (equipmentId = 'eq1')}
                    .inE('DEPENDS_ON'){while: ($depth < 5), as: e}
                    .outV(){as: dep}
              RETURN dep.name AS name, dep.failureRate AS failureRate,
                     e.criticality AS criticality, $depth AS depth
            )
            ORDER BY depth ASC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  " + r.getProperty("name")
            + " | failureRate: " + r.getProperty("failureRate")
            + " | criticality: " + r.getProperty("criticality")
            + " | depth: " + r.getProperty("depth"));
      }
    }
  }

  // ── Query 10: Sensor Anomaly Detection (SQL) ──────────────────────────────
  private static void runQuery10SensorAnomalyDetection(RemoteDatabase db) {
    printHeader("Query 10: Sensor Anomaly Detection (SQL)",
        "Find equipment with anomalous sensor readings.");

    String sql =
        """
            SELECT equipmentId,
                   avg(temperature) AS avgTemp,
                   max(vibration) AS maxVibration,
                   avg(pressure) AS avgPressure
            FROM SensorReading
            GROUP BY equipmentId
            ORDER BY avgTemp DESC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-15s | avgTemp: %6.1f | maxVib: %4.1f | avgPressure: %4.1f%n",
            r.getProperty("equipmentId"),
            ((Number) r.getProperty("avgTemp")).doubleValue(),
            ((Number) r.getProperty("maxVibration")).doubleValue(),
            ((Number) r.getProperty("avgPressure")).doubleValue());
      }
    }
  }

  // ── Query 11: Feature Vector Assembly (Multi-step) ─────────────────────────
  private static void runQuery11FeatureVectorAssembly(RemoteDatabase db) {
    printHeader("Query 11: Feature Vector Assembly (Multi-step)",
        "Assemble a fraud feature vector for account a4.");

    // Step 1: Graph features
    System.out.println("  --- Step 1: Graph features (degree + counterparties) ---");
    String graphSql =
        """
            SELECT inDeg, outDeg, counterparties
            FROM (
              MATCH {type: Account, where: (accountId = 'a4'), as: acct}
              RETURN acct.in('TRANSFERRED').size() AS inDeg,
                     acct.out('TRANSFERRED').size() AS outDeg,
                     acct.both('TRANSFERRED').size() AS counterparties
            )""";

    try (ResultSet rs = db.query("sql", graphSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("    inDeg: " + r.getProperty("inDeg")
            + " | outDeg: " + r.getProperty("outDeg")
            + " | counterparties: " + r.getProperty("counterparties"));
      }
    }

    // Step 2: Vector features
    System.out.println("  --- Step 2: Vector features (similarity rank to known fraud) ---");
    String vectorSql =
        """
            SELECT accountId, flagged
            FROM Account
            ORDER BY vectorNeighbors('Account[behaviorVec]', [0.7, 0.6, 0.2, 0.3], 10) DESC
            LIMIT 5""";

    try (ResultSet rs = db.query("sql", vectorSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("    " + r.getProperty("accountId")
            + " | flagged: " + r.getProperty("flagged"));
      }
    }

    // Step 3: Time-series features
    System.out.println("  --- Step 3: Time-series features (transaction velocity) ---");
    String tsSql =
        """
            SELECT sum(txCount) AS totalTx,
                   sum(totalAmount) AS totalAmount,
                   avg(totalAmount) AS avgBucketAmount
            FROM TransactionMetric
            WHERE accountId = 'a4'""";

    try (ResultSet rs = db.query("sql", tsSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("    totalTx: " + r.getProperty("totalTx")
            + " | totalAmount: " + r.getProperty("totalAmount")
            + " | avgBucket: " + r.getProperty("avgBucketAmount"));
      }
    }

    // Step 4: Store feature snapshot
    System.out.println("  --- Step 4: Store feature snapshot ---");
    String insertSql =
        """
            INSERT INTO FeatureSnapshot SET entityId = 'a4', entityType = 'Account',
              featureVector = [8, 6, 3, 67, 145000, 0.87],
              computedAt = '2026-03-23 00:00:00', modelVersion = 'fraud-v2.2'""";

    db.command("sql", insertSql);
    System.out.println("    (Snapshot stored)");

    // Verify
    System.out.println("  --- Verify: Feature snapshots for a4 ---");
    String verifySql =
        """
            SELECT entityId, modelVersion, computedAt
            FROM FeatureSnapshot
            WHERE entityId = 'a4'
            ORDER BY computedAt DESC""";

    try (ResultSet rs = db.query("sql", verifySql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("    " + r.getProperty("entityId")
            + " | version: " + r.getProperty("modelVersion")
            + " | computed: " + r.getProperty("computedAt"));
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
