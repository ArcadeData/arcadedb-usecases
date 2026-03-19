package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;
import org.neo4j.driver.*;
import org.neo4j.driver.Record;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * IAM — all seven query patterns using OpenCypher via Bolt where possible,
 * falling back to SQL (via HTTP) for document-type and vector queries.
 */
public class IamCypher {

  private static final String HOST      = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    HTTP_PORT = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String BOLT_PORT = System.getenv().getOrDefault("ARCADEDB_BOLT_PORT", "7687");
  private static final String DB_NAME   = "IAM";
  private static final String USER      = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD  = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    String uri = "bolt://" + HOST + ":" + BOLT_PORT;
    try (Driver driver = GraphDatabase.driver(uri, AuthTokens.basic(USER, PASSWORD));
         RemoteDatabase db = new RemoteDatabase(HOST, HTTP_PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1PermissionResolution(driver), "Query 1");
      tryRun(() -> runQuery2ShadowAdminDetection(driver), "Query 2");
      tryRun(() -> runQuery3SoxComplianceAudit(driver, db), "Query 3");
      tryRun(() -> runQuery4SeparationOfDuties(driver), "Query 4");
      tryRun(() -> runQuery5DormantAccess(driver, db), "Query 5");
      tryRun(() -> runQuery6BehavioralAnomaly(db), "Query 6");
      tryRun(() -> runQuery7ImpactAnalysis(driver), "Query 7");
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

  // Query 1: Permission Resolution (OpenCypher via Bolt)
  private static void runQuery1PermissionResolution(Driver driver) {
    printHeader("Query 1: Permission Resolution",
        "Discover all resources alice@company.com can access through any chain.");

    String cypher = """
        MATCH (u:Identity {email: 'alice@company.com'})
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission)
              -[:APPLIES_TO]->(res:Resource)
        RETURN res.name AS resource, p.action AS action,
               r.name AS via_role, g.name AS via_group
        ORDER BY resource, action""";

    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      List<Record> records = session.run(cypher).list();
      for (Record r : records) {
        System.out.printf("  %-20s | %-8s | role: %-12s | group: %s%n",
            r.get("resource").asString(),
            r.get("action").asString(),
            r.get("via_role").asString(),
            r.get("via_group").asString());
      }
    }
  }

  // Query 2: Shadow Admin Detection (OpenCypher via Bolt)
  private static void runQuery2ShadowAdminDetection(Driver driver) {
    printHeader("Query 2: Shadow Admin Detection",
        "Find contractors/service accounts with admin on critical resources.");

    String cypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..5]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission {action: 'admin'})
              -[:APPLIES_TO]->(res:Resource {classification: 'critical'})
        WHERE u.identityType IN ['contractor', 'service_account']
        RETURN u.email AS identity, u.identityType AS identity_type,
               res.name AS critical_resource, r.name AS via_role
        ORDER BY identity""";

    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      List<Record> records = session.run(cypher).list();
      for (Record r : records) {
        System.out.printf("  %-30s | %-16s | %-20s | via: %s%n",
            r.get("identity").asString(),
            r.get("identity_type").asString(),
            r.get("critical_resource").asString(),
            r.get("via_role").asString());
      }
    }
  }

  // Query 3: SOX Compliance Audit (OpenCypher for graph, SQL for AccessLog)
  private static void runQuery3SoxComplianceAudit(Driver driver, RemoteDatabase db) {
    printHeader("Query 3: SOX Compliance Audit",
        "Track access to SOX-governed resources with policy lineage.");

    // Step 1: SOX-governed resources via Cypher
    System.out.println("  --- SOX-governed resources (OpenCypher) ---");
    String cypher = """
        MATCH (res:Resource)-[:GOVERNED_BY]->(pol:Policy {name: 'SOX-Compliance'})
        RETURN res.name AS resource, pol.name AS policy""";

    List<String> soxResources = new ArrayList<>();
    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      List<Record> records = session.run(cypher).list();
      for (Record r : records) {
        String resource = r.get("resource").asString();
        soxResources.add(resource);
        System.out.printf("    %-20s | policy: %s%n",
            resource, r.get("policy").asString());
      }
    }

    // Step 2: Filter AccessLog by SOX-governed resources (SQL — document type)
    System.out.println("  --- Access logs for SOX-scoped resources (SQL) ---");
    String resourceList = soxResources.stream()
        .map(n -> "'" + n.replace("'", "''") + "'")
        .collect(java.util.stream.Collectors.joining(", "));

    String logSql = String.format("""
        SELECT identityEmail, action, resourceName, recordedAt, source_ip
        FROM AccessLog
        WHERE resourceName IN [%s]
          AND recordedAt > '2025-12-01 00:00:00'
        ORDER BY recordedAt DESC""", resourceList);

    try (ResultSet rs = db.query("sql", logSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    %-25s | %-8s | %-15s | %s | %s%n",
            r.getProperty("identityEmail"),
            r.getProperty("action"),
            r.getProperty("resourceName"),
            r.getProperty("recordedAt"),
            r.getProperty("source_ip"));
      }
    }
  }

  // Query 4: Separation of Duties Violation (OpenCypher via Bolt)
  private static void runQuery4SeparationOfDuties(Driver driver) {
    printHeader("Query 4: Separation of Duties Violation",
        "Find users who can both approve AND execute on the same resource.");

    record IdentityResource(String identity, String resource, String role) {}

    String approverCypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission {action: 'approve'})
              -[:APPLIES_TO]->(res:Resource)
        RETURN u.email AS identity, res.name AS resource, r.name AS role""";

    String executorCypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission {action: 'execute'})
              -[:APPLIES_TO]->(res:Resource)
        RETURN u.email AS identity, res.name AS resource, r.name AS role""";

    List<IdentityResource> approvers = new ArrayList<>();
    List<IdentityResource> executors = new ArrayList<>();

    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      for (Record r : session.run(approverCypher).list()) {
        approvers.add(new IdentityResource(
            r.get("identity").asString(), r.get("resource").asString(), r.get("role").asString()));
      }
      for (Record r : session.run(executorCypher).list()) {
        executors.add(new IdentityResource(
            r.get("identity").asString(), r.get("resource").asString(), r.get("role").asString()));
      }
    }

    for (IdentityResource a : approvers) {
      for (IdentityResource e : executors) {
        if (a.identity().equals(e.identity()) && a.resource().equals(e.resource())) {
          System.out.printf("  VIOLATION: %-25s | %-15s | approve via: %-10s | execute via: %s%n",
              a.identity(), a.resource(), a.role(), e.role());
        }
      }
    }
  }

  // Query 5: Dormant Access Detection (OpenCypher for graph, SQL for AccessLog)
  private static void runQuery5DormantAccess(Driver driver, RemoteDatabase db) {
    printHeader("Query 5: Dormant Access Detection",
        "Find identities with permissions but no access in the last 90 days.");

    // Step 1: All identities with granted permissions (OpenCypher)
    String cypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission)
              -[:APPLIES_TO]->(res:Resource)
        RETURN DISTINCT u.email AS identity, res.name AS resource
        ORDER BY identity""";

    Set<String> grantedIdentities = new HashSet<>();
    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      for (Record r : session.run(cypher).list()) {
        grantedIdentities.add(r.get("identity").asString());
      }
    }

    // Step 2: Identities with recent access (SQL — document type)
    String recentSql = """
        SELECT DISTINCT identityEmail
        FROM AccessLog
        WHERE recordedAt > '2025-12-06 00:00:00'
        ORDER BY identityEmail""";

    Set<String> recentIdentities = new HashSet<>();
    try (ResultSet rs = db.query("sql", recentSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        recentIdentities.add(r.getProperty("identityEmail"));
      }
    }

    // Dormant = granted minus recent
    Set<String> dormant = new HashSet<>(grantedIdentities);
    dormant.removeAll(recentIdentities);

    System.out.println("  Dormant identities (have permissions but no recent access):");
    for (String identity : dormant.stream().sorted().toList()) {
      System.out.printf("    %s%n", identity);
    }
  }

  // Query 6: Behavioral Anomaly Detection (SQL — vectorNeighbors is ArcadeDB-only)
  private static void runQuery6BehavioralAnomaly(RemoteDatabase db) {
    printHeader("Query 6: Behavioral Anomaly Detection",
        "Rank employees by similarity to a 'normal' session pattern. (SQL — vectorNeighbors)");

    String sql = """
        SELECT email, department, identityType
        FROM Identity
        WHERE identityType = 'employee'
        ORDER BY vectorNeighbors('Identity[access_pattern_vec]', [0.5, 0.5, 0.3, 0.1, 0.2, 0.1, 0.1, 0.1], 10) DESC
        LIMIT 10""";

    try (ResultSet rs = db.query("sql", sql)) {
      int rank = 1;
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %d. %-25s | %-15s | %s%n",
            rank++,
            r.getProperty("email"),
            r.getProperty("department"),
            r.getProperty("identityType"));
      }
    }
  }

  // Query 7: Impact Analysis — What-If (OpenCypher via Bolt)
  private static void runQuery7ImpactAnalysis(Driver driver) {
    printHeader("Query 7: Impact Analysis (What-If)",
        "What happens if we remove the Platform-Admins group?");

    // Step 1: Permissions granted through Platform-Admins
    System.out.println("  --- Permissions granted through Platform-Admins ---");
    String permsCypher = """
        MATCH (g:`Group` {name: 'Platform-Admins'})
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission)
              -[:APPLIES_TO]->(res:Resource)
        RETURN r.name AS role, p.action AS action, res.name AS resource
        ORDER BY resource""";

    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      for (Record r : session.run(permsCypher).list()) {
        System.out.printf("    %-10s | %-8s | %s%n",
            r.get("role").asString(),
            r.get("action").asString(),
            r.get("resource").asString());
      }
    }

    // Step 2: Identities affected (members of Platform-Admins, direct or transitive)
    System.out.println("  --- Identities affected ---");
    String membersCypher = """
        MATCH (member:Identity)-[:MEMBER_OF*1..3]->(g:`Group` {name: 'Platform-Admins'})
        RETURN DISTINCT member.email AS identity
        ORDER BY identity""";

    try (Session session = driver.session(SessionConfig.forDatabase(DB_NAME))) {
      for (Record r : session.run(membersCypher).list()) {
        System.out.printf("    %s%n", r.get("identity").asString());
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
