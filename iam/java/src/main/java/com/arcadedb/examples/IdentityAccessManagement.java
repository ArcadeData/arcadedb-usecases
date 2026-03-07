package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class IdentityAccessManagement {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "IAM";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1PermissionResolution(db), "Query 1");
      tryRun(() -> runQuery2ShadowAdminDetection(db), "Query 2");
      tryRun(() -> runQuery3SoxComplianceAudit(db), "Query 3");
      tryRun(() -> runQuery4SeparationOfDuties(db), "Query 4");
      tryRun(() -> runQuery5DormantAccess(db), "Query 5");
      tryRun(() -> runQuery6BehavioralAnomaly(db), "Query 6");
      tryRun(() -> runQuery7ImpactAnalysis(db), "Query 7");
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

  // Query 1: Permission Resolution
  private static void runQuery1PermissionResolution(RemoteDatabase db) {
    printHeader("Query 1: Permission Resolution",
        "Discover all resources alice@company.com can access through any chain.");

    String sql =
        """
            SELECT resource, action, via_role, via_group
            FROM (
              MATCH {type: Identity, where: (email = 'alice@company.com'), as: u}
                    .out('MEMBER_OF'){while: ($depth < 3), as: g}
                    .out('HAS_ROLE'){as: r}
                    .out('GRANTS'){as: p}
                    .out('APPLIES_TO'){as: res}
              RETURN res.name AS resource, p.action AS action,
                     r.name AS via_role, g.name AS via_group
            )
            ORDER BY resource, action""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | %-8s | role: %-12s | group: %s%n",
            r.getProperty("resource"),
            r.getProperty("action"),
            r.getProperty("via_role"),
            r.getProperty("via_group"));
      }
    }
  }

  // Query 2: Shadow Admin Detection
  private static void runQuery2ShadowAdminDetection(RemoteDatabase db) {
    printHeader("Query 2: Shadow Admin Detection",
        "Find contractors/service accounts with admin on critical resources.");

    String sql =
        """
            SELECT identity, identity_type, critical_resource, via_role
            FROM (
              MATCH {type: Identity, where: (identityType IN ['contractor', 'service_account']), as: u}
                    .out('MEMBER_OF'){while: ($depth < 5)}
                    .out('HAS_ROLE'){as: r}
                    .out('GRANTS'){where: (action = 'admin')}
                    .out('APPLIES_TO'){as: res, where: (classification = 'critical')}
              RETURN u.email AS identity, u.identityType AS identity_type,
                     res.name AS critical_resource, r.name AS via_role
            )
            ORDER BY identity""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-30s | %-16s | %-20s | via: %s%n",
            r.getProperty("identity"),
            r.getProperty("identity_type"),
            r.getProperty("critical_resource"),
            r.getProperty("via_role"));
      }
    }
  }

  // Query 3: SOX Compliance Audit
  private static void runQuery3SoxComplianceAudit(RemoteDatabase db) {
    printHeader("Query 3: SOX Compliance Audit",
        "Track access to SOX-governed resources with policy lineage.");

    // Step 1: Get SOX-governed resources via GOVERNED_BY edge
    System.out.println("  --- SOX-governed resources ---");
    String govSql =
        """
            SELECT resource, policy
            FROM (
              MATCH {type: Resource, as: res}
                    .out('GOVERNED_BY'){as: pol, where: (name = 'SOX-Compliance')}
              RETURN res.name AS resource, pol.name AS policy
            )""";

    List<String> soxResources = new ArrayList<>();
    try (ResultSet rs = db.query("sql", govSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String resource = r.getProperty("resource");
        soxResources.add(resource);
        System.out.printf("    %-20s | policy: %s%n",
            resource, r.getProperty("policy"));
      }
    }

    // Step 2: Filter AccessLog by SOX-governed resources
    System.out.println("  --- Access logs for SOX-scoped resources ---");
    String resourceList = soxResources.stream()
        .map(n -> "'" + n.replace("'", "''") + "'")
        .collect(java.util.stream.Collectors.joining(", "));

    String logSql = String.format(
        """
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

  // Query 4: Separation of Duties Violation
  private static void runQuery4SeparationOfDuties(RemoteDatabase db) {
    printHeader("Query 4: Separation of Duties Violation",
        "Find users who can both approve AND execute on the same resource.");

    // Step 1: Get identities with approve permission
    String approveSql =
        """
            SELECT identity, resource, role
            FROM (
              MATCH {type: Identity, as: u}
                    .out('MEMBER_OF'){while: ($depth < 3)}
                    .out('HAS_ROLE'){as: r}
                    .out('GRANTS'){where: (action = 'approve')}
                    .out('APPLIES_TO'){as: res}
              RETURN u.email AS identity, res.name AS resource, r.name AS role
            )""";

    record IdentityResource(String identity, String resource, String role) {}
    List<IdentityResource> approvers = new ArrayList<>();
    try (ResultSet rs = db.query("sql", approveSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        approvers.add(new IdentityResource(
            r.getProperty("identity"), r.getProperty("resource"), r.getProperty("role")));
      }
    }

    // Step 2: Get identities with execute permission
    String executeSql =
        """
            SELECT identity, resource, role
            FROM (
              MATCH {type: Identity, as: u}
                    .out('MEMBER_OF'){while: ($depth < 3)}
                    .out('HAS_ROLE'){as: r}
                    .out('GRANTS'){where: (action = 'execute')}
                    .out('APPLIES_TO'){as: res}
              RETURN u.email AS identity, res.name AS resource, r.name AS role
            )""";

    List<IdentityResource> executors = new ArrayList<>();
    try (ResultSet rs = db.query("sql", executeSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        executors.add(new IdentityResource(
            r.getProperty("identity"), r.getProperty("resource"), r.getProperty("role")));
      }
    }

    // Find violations: same identity + same resource in both lists
    for (IdentityResource a : approvers) {
      for (IdentityResource e : executors) {
        if (a.identity().equals(e.identity()) && a.resource().equals(e.resource())) {
          System.out.printf("  VIOLATION: %-25s | %-15s | approve via: %-10s | execute via: %s%n",
              a.identity(), a.resource(), a.role(), e.role());
        }
      }
    }
  }

  // Query 5: Dormant Access Detection
  private static void runQuery5DormantAccess(RemoteDatabase db) {
    printHeader("Query 5: Dormant Access Detection",
        "Find identities with permissions but no access in the last 90 days.");

    // Step 1: All identities with granted permissions
    String grantedSql =
        """
            SELECT DISTINCT identity, resource
            FROM (
              MATCH {type: Identity, as: u}
                    .out('MEMBER_OF'){while: ($depth < 3)}
                    .out('HAS_ROLE'){}
                    .out('GRANTS'){}
                    .out('APPLIES_TO'){as: res}
              RETURN u.email AS identity, res.name AS resource
            )
            ORDER BY identity""";

    Set<String> grantedIdentities = new HashSet<>();
    try (ResultSet rs = db.query("sql", grantedSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        grantedIdentities.add(r.getProperty("identity"));
      }
    }

    // Step 2: Identities with recent access
    String recentSql =
        """
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

  // Query 6: Behavioral Anomaly Detection
  private static void runQuery6BehavioralAnomaly(RemoteDatabase db) {
    printHeader("Query 6: Behavioral Anomaly Detection",
        "Rank employees by similarity to a 'normal' session pattern.");

    String sql =
        """
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

  // Query 7: Impact Analysis (What-If)
  private static void runQuery7ImpactAnalysis(RemoteDatabase db) {
    printHeader("Query 7: Impact Analysis (What-If)",
        "What happens if we remove the Platform-Admins group?");

    // Step 1: Permissions granted through Platform-Admins
    System.out.println("  --- Permissions granted through Platform-Admins ---");
    String permsSql =
        """
            SELECT role, action, resource
            FROM (
              MATCH {type: `Group`, where: (name = 'Platform-Admins'), as: target}
                    .out('HAS_ROLE'){as: r}
                    .out('GRANTS'){as: p}
                    .out('APPLIES_TO'){as: res}
              RETURN r.name AS role, p.action AS action, res.name AS resource
            )
            ORDER BY resource""";

    try (ResultSet rs = db.query("sql", permsSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    %-10s | %-8s | %s%n",
            r.getProperty("role"),
            r.getProperty("action"),
            r.getProperty("resource"));
      }
    }

    // Step 2: Identities affected (members of Platform-Admins, direct or transitive)
    System.out.println("  --- Identities affected ---");
    String membersSql =
        """
            SELECT identity
            FROM (
              MATCH {type: `Group`, where: (name = 'Platform-Admins')}
                    .in('MEMBER_OF'){as: member, while: ($depth < 3)}
              RETURN member.email AS identity
            )
            WHERE identity IS NOT NULL
            ORDER BY identity""";

    Set<String> seen = new HashSet<>();
    try (ResultSet rs = db.query("sql", membersSql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String identity = r.getProperty("identity");
        if (seen.add(identity)) {
          System.out.printf("    %s%n", identity);
        }
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
