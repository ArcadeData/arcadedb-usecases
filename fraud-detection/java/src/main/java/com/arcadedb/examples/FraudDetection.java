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

  // Query 2: Synthetic Identity Resolution (Full-Text)
  private static void runQuery2SyntheticIdentity(RemoteDatabase db) {
    printHeader("Query 2: Synthetic Identity Resolution (Full-Text)",
        "Find accounts with matching SSN but fuzzy-similar names.");

    String sql =
        """
            SELECT a.id, b.id AS b_id, a.full_name, b.full_name AS b_full_name
            FROM Account AS a, Account AS b
            WHERE a.ssn = b.ssn
              AND a.id < b.id
              AND a.full_name.similarity(b.full_name) BETWEEN 0.4 AND 0.9""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | %-10s | %-20s | %s%n",
            r.getProperty("id"),
            r.getProperty("b_id"),
            r.getProperty("full_name"),
            r.getProperty("b_full_name"));
      }
    }
  }

  // Query 3: Circular Money Flow (Graph Cycles)
  private static void runQuery3CircularFlow(RemoteDatabase db) {
    printHeader("Query 3: Circular Money Flow (Graph Cycles)",
        "Detect circular transfer paths returning to origin within 30 days.");

    String cypher =
        """
            MATCH path = (origin:Account)-[:TRANSFERRED_TO*3..6]->(origin)
            WHERE all(t IN relationships(path)
              WHERE t.ts > datetime() - duration('P30D'))
            RETURN origin.id, [n IN nodes(path) | n.id] AS chain""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  origin: %-10s | chain: %s%n",
            r.getProperty("origin.id"),
            r.getProperty("chain"));
      }
    }
  }

  // Query 4: Structuring Detection (Time-Series)
  private static void runQuery4Structuring(RemoteDatabase db) {
    printHeader("Query 4: Structuring Detection (Time-Series)",
        "Flag accounts making 3+ deposits per day in the $8,000-$9,999 range.");

    String sql =
        """
            SELECT time_bucket('1d', ts) AS day, account_id, count(*) AS deposit_count
            FROM Deposit
            WHERE amount BETWEEN 8000 AND 9999
            GROUP BY day, account_id
            HAVING deposit_count >= 3""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  day: %-12s | account: %-10s | deposits: %s%n",
            r.getProperty("day"),
            r.getProperty("account_id"),
            r.getProperty("deposit_count"));
      }
    }
  }

  // Query 5: Behavioral Anomaly (Vector Distance)
  private static void runQuery5BehavioralAnomaly(RemoteDatabase db) {
    printHeader("Query 5: Behavioral Anomaly (Vector Distance)",
        "Detect transactions whose behavioral embedding deviates from the customer profile.");

    String sql =
        """
            SELECT t.id, t.amount, t.merchant,
                   vectorDistance(t.behavior_embedding, c.profile_embedding) AS deviation
            FROM Transaction t
            JOIN Customer c ON t.account_id = c.id
            WHERE vectorDistance(t.behavior_embedding, c.profile_embedding) > 0.7
            ORDER BY deviation DESC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | $%-10.2f | %-15s | deviation: %s%n",
            r.getProperty("id"),
            ((Number) r.getProperty("amount")).doubleValue(),
            r.getProperty("merchant"),
            r.getProperty("deviation"));
      }
    }
  }

  // Query 6: Velocity Attack Detection (Time-Series)
  private static void runQuery6VelocityAttack(RemoteDatabase db) {
    printHeader("Query 6: Velocity Attack Detection (Time-Series)",
        "Detect accounts with abnormally high transaction rates in a 5-minute window.");

    String sql =
        """
            SELECT account_id, count(*) AS txn_count, min(ts) AS first_txn, max(ts) AS last_txn
            FROM Transaction
            WHERE ts BETWEEN '2026-03-01T13:00:00Z' AND '2026-03-01T13:05:00Z'
            GROUP BY account_id
            HAVING txn_count > 5""";

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
        "Detect coordinated transfer amounts between two accounts.");

    String sql =
        """
            SELECT a.account_id AS account_a, b.account_id AS account_b,
                   avg(a.amount) AS avg_a, avg(b.amount) AS avg_b,
                   count(*) AS matching_txns
            FROM Transaction a, Transaction b
            WHERE a.account_id = 'acct-A' AND b.account_id = 'acct-B'
              AND a.ts >= '2026-02-01T00:00:00Z'
              AND b.ts >= '2026-02-01T00:00:00Z'""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s <-> %s | avg_a: %s | avg_b: %s | matching: %s%n",
            r.getProperty("account_a"),
            r.getProperty("account_b"),
            r.getProperty("avg_a"),
            r.getProperty("avg_b"),
            r.getProperty("matching_txns"));
      }
    }
  }

  // Query 8: Multi-Model Investigation (Combined)
  private static void runQuery8MultiModel(RemoteDatabase db) {
    printHeader("Query 8: Multi-Model Investigation (Combined)",
        "Composite risk score blending graph connectivity, velocity, and behavioral deviation.");

    String sql =
        """
            SELECT a.id, a.name,
                   (SELECT count(*) FROM (
                     MATCH {type: Account, where: (id = a.id)}
                           .bothE('USES_DEVICE','HAS_PHONE','HAS_ADDRESS'){}
                           .bothV(){where: (id != a.id), as: linked}
                     RETURN linked
                   )) AS shared_identifiers,
                   (SELECT count(*) FROM Transaction WHERE account_id = a.id) AS txn_count,
                   c.recent_behavior
            FROM Account a
            JOIN Customer c ON a.id = c.id
            WHERE c.recent_behavior IN ['suspicious', 'anomalous']
            ORDER BY shared_identifiers DESC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | %-10s | shared: %-5s | txns: %-5s | behavior: %s%n",
            r.getProperty("id"),
            r.getProperty("name"),
            r.getProperty("shared_identifiers"),
            r.getProperty("txn_count"),
            r.getProperty("recent_behavior"));
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
