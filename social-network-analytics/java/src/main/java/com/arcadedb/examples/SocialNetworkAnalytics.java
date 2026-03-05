package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

public class SocialNetworkAnalytics {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "SocialNetwork";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1TrendingDashboard(db), "Query 1");
      tryRun(() -> runQuery2EngagementTimeSeries(db), "Query 2");
      tryRun(() -> runQuery3InfluenceLeaderboard(db), "Query 3");
      tryRun(() -> runQuery4ViralSpreadChain(db), "Query 4");
      tryRun(() -> runQuery5CommunityOverlap(db), "Query 5");
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

  // Query 1: Trending Content Dashboard (Materialized View — PERIODIC)
  private static void runQuery1TrendingDashboard(RemoteDatabase db) {
    printHeader("Query 1: Trending Content Dashboard (Materialized View — PERIODIC)",
        "Read pre-computed trending scores from the TrendingPosts materialized view.");

    String sql =
        """
            SELECT postRid, totalLikes, totalShares, totalComments, score
            FROM TrendingPosts
            ORDER BY score DESC
            LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-25s | likes: %-5s | shares: %-5s | comments: %-5s | score: %s%n",
            r.getProperty("postRid"),
            r.getProperty("totalLikes"),
            r.getProperty("totalShares"),
            r.getProperty("totalComments"),
            r.getProperty("score"));
      }
    }
  }

  // Query 2: Engagement Time-Series
  private static void runQuery2EngagementTimeSeries(RemoteDatabase db) {
    printHeader("Query 2: Engagement Time-Series",
        "Drill into the viral post's engagement growth over time.");

    String sql =
        """
            SELECT timestamp, likes, shares, comments
            FROM EngagementMetric
            WHERE postRid = 'ai-trends-2026'
            ORDER BY timestamp""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %s | likes: %-5s | shares: %-5s | comments: %s%n",
            r.getProperty("timestamp"),
            r.getProperty("likes"),
            r.getProperty("shares"),
            r.getProperty("comments"));
      }
    }
  }

  // Query 3: Influence Leaderboard (Materialized View — MANUAL)
  private static void runQuery3InfluenceLeaderboard(RemoteDatabase db) {
    printHeader("Query 3: Influence Leaderboard (Materialized View — MANUAL)",
        "Refresh and query the InfluenceScores view for top users by follower count.");

    // Manual refresh before querying
    db.command("sql", "REFRESH MATERIALIZED VIEW InfluenceScores");
    System.out.println("  InfluenceScores refreshed.");
    System.out.println();

    String sql =
        """
            SELECT userName, handle, followers
            FROM InfluenceScores
            ORDER BY followers DESC
            LIMIT 5""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-10s | @%-10s | followers: %s%n",
            r.getProperty("userName"),
            r.getProperty("handle"),
            r.getProperty("followers"));
      }
    }
  }

  // Query 4: Viral Spread Chain (OpenCypher — Graph Traversal)
  private static void runQuery4ViralSpreadChain(RemoteDatabase db) {
    printHeader("Query 4: Viral Spread Chain (OpenCypher — Graph Traversal)",
        "Trace how the AI Trends post spread: author -> sharers -> their followers.");

    String cypher =
        """
            MATCH (author:User)-[:CREATED]->(p:Post)<-[:SHARED]-(sharer:User)<-[:FOLLOWS]-(audience:User)
            WHERE p.title = 'AI Trends in 2026'
            RETURN author.name AS author, sharer.name AS sharer, collect(DISTINCT audience.name) AS reachedAudience""";

    try (ResultSet rs = db.query("opencypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  author: %-10s | sharer: %-10s | reached: %s%n",
            r.getProperty("author"),
            r.getProperty("sharer"),
            r.getProperty("reachedAudience"));
      }
    }
  }

  // Query 5: Community Overlap (OpenCypher — Graph Traversal)
  private static void runQuery5CommunityOverlap(RemoteDatabase db) {
    printHeader("Query 5: Community Overlap (OpenCypher — Graph Traversal)",
        "Find users in the same group who also follow each other.");

    String cypher =
        """
            MATCH (a:User)-[:MEMBER_OF]->(g:Group)<-[:MEMBER_OF]-(b:User)
            WHERE (a)-[:FOLLOWS]->(b) AND id(a) < id(b)
            RETURN g.name AS group, a.name AS user1, b.name AS user2
            ORDER BY g.name""";

    try (ResultSet rs = db.query("opencypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  group: %-15s | %s -> follows -> %s%n",
            r.getProperty("group"),
            r.getProperty("user1"),
            r.getProperty("user2"));
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
