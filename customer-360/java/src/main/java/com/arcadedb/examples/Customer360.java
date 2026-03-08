package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class Customer360 {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "Customer360";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1IdentityResolution(db), "Query 1");
      tryRun(() -> runQuery2FuzzyDedup(db), "Query 2");
      tryRun(() -> runQuery3Customer360View(db), "Query 3");
      tryRun(() -> runQuery4ChurnRisk(db), "Query 4");
      tryRun(() -> runQuery5CrossSell(db), "Query 5");
      tryRun(() -> runQuery6JourneyPath(db), "Query 6");
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

  // Query 1: Identity Resolution — Transitive Link Discovery (SQL MATCH)
  private static void runQuery1IdentityResolution(RemoteDatabase db) {
    printHeader("Query 1: Identity Resolution — Transitive Link Discovery",
        "Find all identifiers belonging to the same person as alice@example.com.");

    String sql = """
        SELECT linked.identifierType AS type, linked.identifierValue AS value
        FROM (
          MATCH {type: Identifier, where: (identifierValue = 'alice@example.com')}
                .out('OBSERVED_IN'){}.in('OBSERVED_IN'){}
                .out('OBSERVED_IN'){}.in('OBSERVED_IN'){}
                .out('OBSERVED_IN'){}.in('OBSERVED_IN'){as: linked}
          RETURN DISTINCT linked
        )""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-15s | %s%n",
            r.getProperty("type"),
            r.getProperty("value"));
      }
    }
  }

  // Query 2: Fuzzy Name Matching for Deduplication (OpenCypher)
  private static void runQuery2FuzzyDedup(RemoteDatabase db) {
    printHeader("Query 2: Fuzzy Deduplication",
        "Find probable duplicate customers by shared phone number.");

    String cypher = """
        MATCH (a:Customer), (b:Customer)
        WHERE a.phone = b.phone AND a.id < b.id
        RETURN a.id AS id_a, a.name AS name_a,
               b.id AS id_b, b.name AS name_b,
               a.phone AS phone""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s %-20s | %-5s %-20s | phone: %s%n",
            r.getProperty("id_a"),
            r.getProperty("name_a"),
            r.getProperty("id_b"),
            r.getProperty("name_b"),
            r.getProperty("phone"));
      }
    }
  }

  // Query 3: Complete Customer 360 View (OpenCypher)
  private static void runQuery3Customer360View(RemoteDatabase db) {
    printHeader("Query 3: Complete Customer 360 View",
        "Unified profile for c1: household, purchases, open tickets, lifetime value.");

    // Profile basics
    try (ResultSet rs = db.query("sql", "SELECT name, lifetimeValue FROM Customer WHERE id = 'c1'")) {
      if (rs.hasNext()) {
        Result r = rs.next();
        System.out.println("  Customer:     " + r.getProperty("name"));
        System.out.printf("  LTV:          $%.2f%n", ((Number) r.getProperty("lifetimeValue")).doubleValue());
      }
    }
    // Household members
    System.out.print("  Household:    [");
    try (ResultSet rs = db.query("cypher",
        "MATCH (c:Customer {id: 'c1'})-[:MEMBER_OF]->(h:Household)<-[:MEMBER_OF]-(m:Customer) WHERE m <> c RETURN m.name AS name")) {
      boolean first = true;
      while (rs.hasNext()) {
        if (!first) System.out.print(", ");
        System.out.print((String) rs.next().getProperty("name"));
        first = false;
      }
    }
    System.out.println("]");
    // Purchased products
    System.out.print("  Purchases:    [");
    try (ResultSet rs = db.query("cypher",
        "MATCH (c:Customer {id: 'c1'})-[:PURCHASED]->(p:Product) RETURN DISTINCT p.name AS name")) {
      boolean first = true;
      while (rs.hasNext()) {
        if (!first) System.out.print(", ");
        System.out.print((String) rs.next().getProperty("name"));
        first = false;
      }
    }
    System.out.println("]");
    // Open tickets
    System.out.print("  Open tickets: [");
    try (ResultSet rs = db.query("cypher",
        "MATCH (c:Customer {id: 'c1'})-[:OPENED]->(t:Ticket) WHERE t.status = 'open' RETURN t.subject AS subject")) {
      boolean first = true;
      while (rs.hasNext()) {
        if (!first) System.out.print(", ");
        System.out.print((String) rs.next().getProperty("subject"));
        first = false;
      }
    }
    System.out.println("]");
  }

  // Query 4: Churn Risk Scoring (SQL MATCH)
  private static void runQuery4ChurnRisk(RemoteDatabase db) {
    printHeader("Query 4: Churn Risk Scoring",
        "Score active customers by churned-neighbor ratio in their social network.");

    String sql = """
        SELECT c.id, c.name,
               count(neighbor) AS total_neighbors,
               sum(CASE WHEN neighbor.status = 'churned' THEN 1 ELSE 0 END) AS churned_neighbors
        FROM (
          MATCH {type: Customer, where: (status = 'active'), as: c}
                .bothE('REFERRED', 'CONNECTED_TO'){}
                .bothV(){as: neighbor, where: ($currentMatch != c)}
          RETURN c, neighbor
        )
        GROUP BY c.id, c.name
        ORDER BY churned_neighbors DESC""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s %-20s | neighbors: %s | churned: %s%n",
            r.getProperty("c.id"),
            r.getProperty("c.name"),
            r.getProperty("total_neighbors"),
            r.getProperty("churned_neighbors"));
      }
    }
  }

  // Query 5: Cross-Sell via Household & Collaborative Filtering (OpenCypher)
  private static void runQuery5CrossSell(RemoteDatabase db) {
    printHeader("Query 5: Cross-Sell Recommendations",
        "Products for c1 via household member purchases and collaborative filtering.");

    String cypher = """
        MATCH (c:Customer {id: 'c1'})
        OPTIONAL MATCH (c)-[:MEMBER_OF]->(:Household)<-[:MEMBER_OF]-(hm:Customer)-[:PURCHASED]->(hp:Product)
        WHERE NOT (c)-[:PURCHASED]->(hp)
        OPTIONAL MATCH (c)-[:PURCHASED]->(:Product)<-[:PURCHASED]-(sim:Customer)-[:PURCHASED]->(sp:Product)
        WHERE NOT (c)-[:PURCHASED]->(sp)
        WITH c, collect(DISTINCT hp) + collect(DISTINCT sp) AS candidates
        UNWIND candidates AS rec
        RETURN DISTINCT rec.name AS product,
               rec.category AS category,
               rec.price AS price""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-15s | $%.2f%n",
            r.getProperty("product"),
            r.getProperty("category"),
            ((Number) r.getProperty("price")).doubleValue());
      }
    }
  }

  // Query 6: Journey Path Analysis (OpenCypher)
  private static void runQuery6JourneyPath(RemoteDatabase db) {
    printHeader("Query 6: Journey Path Analysis",
        "Most common conversion paths: ad_click -> page_view -> purchase.");

    String cypher = """
        MATCH (c:Customer)-[:INTERACTED]->(e1:Event {eventType: 'ad_click'})
              -[:FOLLOWED_BY]->(e2:Event {eventType: 'page_view'})
              -[:FOLLOWED_BY]->(e3:Event {eventType: 'purchase'})
        RETURN e1.channel AS entry_channel,
               e2.page AS landing_page,
               count(*) AS conversions
        ORDER BY conversions DESC
        LIMIT 20""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-15s | %-15s | conversions: %s%n",
            r.getProperty("entry_channel"),
            r.getProperty("landing_page"),
            r.getProperty("conversions"));
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
