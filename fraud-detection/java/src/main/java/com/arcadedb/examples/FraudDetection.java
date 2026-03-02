package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class FraudDetection {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "FraudDetection";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1FraudRing(db), "Query 1");
      tryRun(() -> runQuery2SyntheticIdentity(db), "Query 2");
      tryRun(() -> runQuery3CircularFlow(db), "Query 3");
      tryRun(() -> runQuery4Structuring(db), "Query 4");
      tryRun(() -> runQuery5BehavioralAnomaly(db), "Query 5");
      tryRun(() -> runQuery6VelocityAttack(db), "Query 6");
      tryRun(() -> runQuery7CorrelatedActivity(db), "Query 7");
      tryRun(() -> runQuery8MultiModel(db), "Query 8");
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

  // Query 1: Fraud Ring Detection (Graph Traversal)
  private static void runQuery1FraudRing(RemoteDatabase db) {
    printHeader("Query 1: Fraud Ring Detection (Graph Traversal)",
        "Find accounts connected to acct-A through shared identifiers.");

    String cypher =
        """
            MATCH (flagged:Account {id: 'acct-A'})
                  -[:USES_DEVICE|HAS_PHONE|HAS_ADDRESS*1..4]-
                  (connected:Account)
            WHERE connected <> flagged
            RETURN DISTINCT connected.id, connected.name""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-12s | %s%n",
            r.getProperty("connected.id"),
            r.getProperty("connected.name"));
      }
    }
  }

  // Query 2: Synthetic Identity Resolution
  private static void runQuery2SyntheticIdentity(RemoteDatabase db) {
    printHeader("Query 2: Synthetic Identity Resolution",
        "Find accounts sharing the same SSN (indicating synthetic identity fraud).");

    String sql =
        """
            SELECT id, full_name, ssn
            FROM Account
            WHERE ssn = '123-45-6789'
            ORDER BY id""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | %-20s | ssn: %s%n",
            r.getProperty("id"),
            r.getProperty("full_name"),
            r.getProperty("ssn"));
      }
    }
  }

  // Query 3: Circular Money Flow (Graph Cycles)
  private static void runQuery3CircularFlow(RemoteDatabase db) {
    printHeader("Query 3: Circular Money Flow (Graph Cycles)",
        "Detect the A->B->C->D->E->A circular transfer path.");

    String cypher =
        """
            MATCH (origin:Account {id: 'acct-A'})
                  -[:TRANSFERRED_TO]->(b:Account)
                  -[:TRANSFERRED_TO]->(c:Account)
                  -[:TRANSFERRED_TO]->(d:Account)
                  -[:TRANSFERRED_TO]->(e:Account)
                  -[:TRANSFERRED_TO]->(origin)
            RETURN origin.id AS origin, b.id AS hop1, c.id AS hop2, d.id AS hop3, e.id AS hop4""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  origin: %s -> %s -> %s -> %s -> %s -> (back to origin)%n",
            r.getProperty("origin"),
            r.getProperty("hop1"),
            r.getProperty("hop2"),
            r.getProperty("hop3"),
            r.getProperty("hop4"));
      }
    }
  }

  // Query 4: Structuring Detection (Time-Series)
  private static void runQuery4Structuring(RemoteDatabase db) {
    printHeader("Query 4: Structuring Detection (Time-Series)",
        "Flag accounts making 3+ deposits in the $8,000-$9,999 range.");

    String sql =
        """
            SELECT FROM (
              SELECT account_id, count(*) AS deposit_count
              FROM Deposit
              WHERE amount BETWEEN 8000 AND 9999
              GROUP BY account_id
            ) WHERE deposit_count >= 3""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  account: %-10s | deposits: %s%n",
            r.getProperty("account_id"),
            r.getProperty("deposit_count"));
      }
    }
  }

  // Query 5: Behavioral Anomaly (Vector Similarity)
  private static void runQuery5BehavioralAnomaly(RemoteDatabase db) {
    printHeader("Query 5: Behavioral Anomaly (Vector Similarity)",
        "Detect acct-H transactions deviating from customer profile via cosine similarity.");

    String sql =
        """
            SELECT id, amount, merchant, account_id,
                   vectorCosineSimilarity(behavior_embedding, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]) AS profile_similarity
            FROM Transaction
            WHERE account_id = 'acct-H'
            ORDER BY profile_similarity""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | $%-10.2f | %-15s | similarity: %s%n",
            r.getProperty("id"),
            ((Number) r.getProperty("amount")).doubleValue(),
            r.getProperty("merchant"),
            r.getProperty("profile_similarity"));
      }
    }
  }

  // Query 6: Velocity Attack Detection (Time-Series)
  private static void runQuery6VelocityAttack(RemoteDatabase db) {
    printHeader("Query 6: Velocity Attack Detection (Time-Series)",
        "Detect accounts with abnormally high transaction rates in a 5-minute window.");

    String sql =
        """
            SELECT FROM (
              SELECT account_id, count(*) AS txn_count, min(ts) AS first_txn, max(ts) AS last_txn
              FROM Transaction
              WHERE ts BETWEEN '2026-03-01T13:00:00Z' AND '2026-03-01T13:05:00Z'
              GROUP BY account_id
            ) WHERE txn_count > 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  account: %-10s | txns: %-5s | from: %s | to: %s%n",
            r.getProperty("account_id"),
            r.getProperty("txn_count"),
            r.getProperty("first_txn"),
            r.getProperty("last_txn"));
      }
    }
  }

  // Query 7: Correlated Account Activity (Time-Series)
  private static void runQuery7CorrelatedActivity(RemoteDatabase db) {
    printHeader("Query 7: Correlated Account Activity (Time-Series)",
        "Compare transfer patterns between two accounts to detect coordination.");

    String sql =
        """
            SELECT account_id, avg(amount) AS avg_amount, count(*) AS txn_count
            FROM Transaction
            WHERE account_id IN ['acct-A', 'acct-B']
              AND ts >= '2026-02-01T00:00:00Z'
            GROUP BY account_id""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  account: %-10s | avg_amount: %-10s | txns: %s%n",
            r.getProperty("account_id"),
            r.getProperty("avg_amount"),
            r.getProperty("txn_count"));
      }
    }
  }

  // Query 8: Multi-Model Investigation (Combined)
  private static void runQuery8MultiModel(RemoteDatabase db) {
    printHeader("Query 8: Multi-Model Investigation (Combined)",
        "Find suspicious accounts and enrich with transaction counts.");

    String sql =
        """
            SELECT id, name
            FROM Account
            WHERE id IN (SELECT id FROM Customer WHERE recent_behavior IN ['suspicious', 'anomalous'])""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | %s%n",
            r.getProperty("id"),
            r.getProperty("name"));
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
