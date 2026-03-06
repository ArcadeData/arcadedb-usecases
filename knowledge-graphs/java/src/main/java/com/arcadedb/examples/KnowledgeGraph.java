package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class KnowledgeGraph {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "KnowledgeGraph";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1CoauthorshipNetwork(db), "Query 1");
      tryRun(() -> runQuery2SemanticSearch(db), "Query 2");
      tryRun(() -> runQuery3FullTextSearch(db), "Query 3");
      tryRun(() -> runQuery4TrendingPapers(db), "Query 4");
      tryRun(() -> runQuery5GraphRag(db), "Query 5");
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

  // Query 1: Co-authorship Network — Graph Traversal (Cypher)
  private static void runQuery1CoauthorshipNetwork(RemoteDatabase db) {
    printHeader("Query 1: Co-authorship Network (Graph Traversal)",
        "Find researchers reachable from Alice (r1) within 2 co-authorship hops.");

    String cypher =
        """
            MATCH (me:Researcher {id: 'r1'})
                  -[:CO_AUTHORED]->(p:Paper)
                  <-[:CO_AUTHORED]-(colleague:Researcher)
                  -[:CO_AUTHORED]->(collab:Paper)
             WHERE colleague.id <> 'r1'
               AND NOT (me)-[:CO_AUTHORED]->(collab)
             RETURN colleague.name, collab.title, count(DISTINCT p) AS shared_papers
             ORDER BY shared_papers DESC LIMIT 10""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-50s | shared: %s%n",
            r.getProperty("colleague.name"),
            r.getProperty("collab.title"),
            r.getProperty("shared_papers"));
      }
    }
  }

  // Query 2: Semantic Paper Search — Vector Similarity (SQL)
  private static void runQuery2SemanticSearch(RemoteDatabase db) {
    printHeader("Query 2: Semantic Paper Search (Vector Similarity)",
        "Find papers semantically similar to the embedding [0.8, 0.2, 0.1, 0.1].");

    String sql =
        """
            SELECT id, title, year
             FROM Paper
             ORDER BY vectorNeighbors('Paper[embedding]', [0.8, 0.2, 0.1, 0.1], 10) DESC
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s | %d | %s%n",
            r.getProperty("id"),
            ((Number) r.getProperty("year")).intValue(),
            r.getProperty("title"));
      }
    }
  }

  // Query 3: Full-Text Search Meets Graph Context
  private static void runQuery3FullTextSearch(RemoteDatabase db) {
    printHeader("Query 3: Full-Text Search Meets Graph Context",
        "Find papers matching 'distributed AND consensus', then expand to co-authors.");

    // Step 1: Full-text search
    System.out.println("  --- Step 1: Full-text search ---");
    String sql =
        """
            SELECT id, title, year
             FROM Paper
             WHERE SEARCH_INDEX('Paper[abstract]', 'distributed AND consensus') = true
             LIMIT 10""";

    java.util.List<String> paperIds = new java.util.ArrayList<>();
    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String id = r.getProperty("id");
        paperIds.add(id);
        System.out.printf("    %-5s | %d | %s%n",
            id,
            ((Number) r.getProperty("year")).intValue(),
            r.getProperty("title"));
      }
    }

    if (paperIds.isEmpty()) {
      System.out.println("  No papers found.");
      return;
    }

    // Step 2: Graph expansion — co-authors of matching papers
    System.out.println("  --- Step 2: Graph expansion — co-authors ---");
    String idList = paperIds.stream()
        .map(id -> "'" + id.replace("'", "''") + "'")
        .collect(java.util.stream.Collectors.joining(", "));

    String graphSql = String.format(
        """
            SELECT paper, author
             FROM (
              MATCH {type: Paper, as: p, where: (id IN [%s])}
                    .in('CO_AUTHORED'){as: a}
              RETURN p.title AS paper, a.name AS author
             )""", idList);

    try (ResultSet rs = db.query("sql", graphSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    %-50s | %s%n",
            r.getProperty("paper"),
            r.getProperty("author"));
      }
    }
  }

  // Query 4: Trending Papers — Time-Series Aggregation (SQL)
  private static void runQuery4TrendingPapers(RemoteDatabase db) {
    printHeader("Query 4: Trending Papers (Time-Series)",
        "Rank papers by cumulative citation activity.");

    String sql =
        """
            SELECT paperId, sum(citationCount) AS totalCitations
             FROM PaperActivity
             GROUP BY paperId
             ORDER BY totalCitations DESC
             LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-5s | totalCitations: %s%n",
            r.getProperty("paperId"),
            r.getProperty("totalCitations"));
      }
    }
  }

  // Query 5: GraphRAG Hybrid — Vector Seed + Citation Graph Expansion (SQL)
  private static void runQuery5GraphRag(RemoteDatabase db) {
    printHeader("Query 5: GraphRAG Hybrid (Vector Seed + Citation Expansion)",
        "Discover topics connected via citation graph to papers most similar to [0.8, 0.2, 0.1, 0.1].");

    String sql =
        """
            SELECT topic.name AS topic, count(*) AS connections
             FROM (
              MATCH {type: Paper, where: (id IN ['p2', 'p8', 'p4'])}
                    .out('CITES'){as: cited}
                    .out('COVERS'){as: topic}
              RETURN topic
             )
             GROUP BY topic
             ORDER BY connections DESC
             LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | connections: %s%n",
            r.getProperty("topic"),
            r.getProperty("connections"));
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
