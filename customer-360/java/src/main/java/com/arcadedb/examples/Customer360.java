package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.grpc.RemoteGrpcDatabase;
import com.arcadedb.remote.grpc.RemoteGrpcServer;

import java.util.List;

public class Customer360 {

  private static final String HOST      = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    GRPC_PORT = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_GRPC_PORT", "50051"));
  private static final int    HTTP_PORT = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME   = "Customer360";
  private static final String USER      = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD  = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    RemoteGrpcServer server = new RemoteGrpcServer(HOST, GRPC_PORT, USER, PASSWORD, true, List.of());

    try (RemoteGrpcDatabase db = new RemoteGrpcDatabase(server, HOST, GRPC_PORT, HTTP_PORT, DB_NAME, USER, PASSWORD)) {
      db.setTimeout(60_000);

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

  // Query 1: Identity Resolution — Transitive Link Discovery (OpenCypher)
  private static void runQuery1IdentityResolution(RemoteGrpcDatabase db) {
    printHeader("Query 1: Identity Resolution — Transitive Link Discovery",
        "Find all identifiers belonging to the same person as alice@example.com via gRPC.");

    String cypher = """
        MATCH (id:Identifier {identifierValue: 'alice@example.com'})
              -[:OBSERVED_IN]->(session:Session)
              <-[:OBSERVED_IN]-(other:Identifier)
        WITH DISTINCT other
        MATCH (other)-[:OBSERVED_IN*1..3]-(transitive:Identifier)
        RETURN DISTINCT transitive.identifierType AS type,
               transitive.identifierValue AS value""";

    try (ResultSet rs = db.query("opencypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-15s | %s%n",
            r.getProperty("type"),
            r.getProperty("value"));
      }
    }
  }

  // Query 2: Fuzzy Name Matching for Deduplication (SQL)
  private static void runQuery2FuzzyDedup(RemoteGrpcDatabase db) {
    printHeader("Query 2: Fuzzy Deduplication",
        "Find probable duplicate customers by shared phone number.");

    String sql = """
        SELECT a.id AS id_a, a.name AS name_a,
               b.id AS id_b, b.name AS name_b,
               a.phone AS phone
        FROM Customer a, Customer b
        WHERE a.id < b.id
          AND a.phone = b.phone""";

    try (ResultSet rs = db.query("SQL", sql)) {
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
  private static void runQuery3Customer360View(RemoteGrpcDatabase db) {
    printHeader("Query 3: Complete Customer 360 View",
        "Unified profile for c1: household, purchases, open tickets, lifetime value.");

    String cypher = """
        MATCH (c:Customer {id: 'c1'})
        OPTIONAL MATCH (c)-[:MEMBER_OF]->(h:Household)<-[:MEMBER_OF]-(member:Customer)
        WHERE member <> c
        OPTIONAL MATCH (c)-[p:PURCHASED]->(prod:Product)
        OPTIONAL MATCH (c)-[:OPENED]->(t:Ticket)
        WHERE t.status = 'open'
        RETURN c.name AS customer,
               c.lifetimeValue AS ltv,
               collect(DISTINCT member.name) AS household_members,
               collect(DISTINCT prod.name) AS purchased_products,
               collect(DISTINCT t.subject) AS open_tickets""";

    try (ResultSet rs = db.query("opencypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  Customer:     %s%n", r.getProperty("customer"));
        System.out.printf("  LTV:          $%.2f%n", ((Number) r.getProperty("ltv")).doubleValue());
        System.out.printf("  Household:    %s%n", r.getProperty("household_members"));
        System.out.printf("  Purchases:    %s%n", r.getProperty("purchased_products"));
        System.out.printf("  Open tickets: %s%n", r.getProperty("open_tickets"));
      }
    }
  }

  // Query 4: Churn Risk Scoring (SQL MATCH)
  private static void runQuery4ChurnRisk(RemoteGrpcDatabase db) {
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

    try (ResultSet rs = db.query("SQL", sql)) {
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
  private static void runQuery5CrossSell(RemoteGrpcDatabase db) {
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

    try (ResultSet rs = db.query("opencypher", cypher)) {
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
  private static void runQuery6JourneyPath(RemoteGrpcDatabase db) {
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

    try (ResultSet rs = db.query("opencypher", cypher)) {
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
