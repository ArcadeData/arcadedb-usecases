#!/usr/bin/env python3
"""IAM — all seven query patterns using OpenCypher via Bolt where possible,
falling back to SQL (via PostgreSQL wire protocol) for document-type and vector queries."""

import os

from neo4j import GraphDatabase
import psycopg


HOST      = os.environ.get('ARCADEDB_HOST', 'localhost')
BOLT_PORT = int(os.environ.get('ARCADEDB_BOLT_PORT', '7687'))
PG_PORT   = int(os.environ.get('ARCADEDB_PG_PORT', '5432'))
DB_NAME   = 'IAM'
USER      = os.environ.get('ARCADEDB_USER', 'root')
PASSWORD  = os.environ.get('ARCADEDB_PASS', 'arcadedb')


def print_header(title, description):
    print('\n' + '=' * 70)
    print('  ' + title)
    print('  ' + description)
    print('=' * 70)


def try_run(fn, name):
    try:
        fn()
    except Exception as e:
        print(f'[{name} FAILED] {e}')


# Query 1: Permission Resolution (OpenCypher via Bolt)
def run_query1(driver):
    print_header('Query 1: Permission Resolution',
                 "Discover all resources alice@company.com can access through any chain.")

    cypher = """
        MATCH (u:Identity {email: 'alice@company.com'})
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission)
              -[:APPLIES_TO]->(res:Resource)
        RETURN res.name AS resource, p.action AS action,
               r.name AS via_role, g.name AS via_group
        ORDER BY resource, action
    """
    with driver.session(database=DB_NAME) as session:
        for r in session.run(cypher):
            print(f'  {str(r["resource"]):20s} | {str(r["action"]):8s} | '
                  f'role: {str(r["via_role"]):12s} | group: {r["via_group"]}')


# Query 2: Shadow Admin Detection (OpenCypher via Bolt)
def run_query2(driver):
    print_header('Query 2: Shadow Admin Detection',
                 'Find contractors/service accounts with admin on critical resources.')

    cypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..5]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission {action: 'admin'})
              -[:APPLIES_TO]->(res:Resource {classification: 'critical'})
        WHERE u.identityType IN ['contractor', 'service_account']
        RETURN u.email AS identity, u.identityType AS identity_type,
               res.name AS critical_resource, r.name AS via_role
        ORDER BY identity
    """
    with driver.session(database=DB_NAME) as session:
        for r in session.run(cypher):
            print(f'  {str(r["identity"]):30s} | {str(r["identity_type"]):16s} | '
                  f'{str(r["critical_resource"]):20s} | via: {r["via_role"]}')


# Query 3: SOX Compliance Audit (OpenCypher for graph, SQL for AccessLog)
def run_query3(driver, pg_cur):
    print_header('Query 3: SOX Compliance Audit',
                 'Track access to SOX-governed resources with policy lineage.')

    # Step 1: SOX-governed resources via Cypher
    print('  --- SOX-governed resources (OpenCypher) ---')
    cypher = """
        MATCH (res:Resource)-[:GOVERNED_BY]->(pol:Policy {name: 'SOX-Compliance'})
        RETURN res.name AS resource, pol.name AS policy
    """
    sox_resources = []
    with driver.session(database=DB_NAME) as session:
        for r in session.run(cypher):
            sox_resources.append(r['resource'])
            print(f'    {str(r["resource"]):20s} | policy: {r["policy"]}')

    # Step 2: Access logs for SOX-scoped resources (SQL — document type)
    print('  --- Access logs for SOX-scoped resources (SQL) ---')
    resource_list = ', '.join(f"'{r}'" for r in sox_resources)
    pg_cur.execute(f"""
        SELECT identityEmail, action, resourceName, recordedAt, source_ip
        FROM AccessLog
        WHERE resourceName IN [{resource_list}]
          AND recordedAt > '2025-12-01 00:00:00'
        ORDER BY recordedAt DESC
    """)
    for row in pg_cur.fetchall():
        print(f'    {str(row[0]):25s} | {str(row[1]):8s} | {str(row[2]):15s} | {row[3]} | {row[4]}')


# Query 4: Separation of Duties Violation (OpenCypher via Bolt)
def run_query4(driver):
    print_header('Query 4: Separation of Duties Violation',
                 'Find users who can both approve AND execute on the same resource.')

    approve_cypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission {action: 'approve'})
              -[:APPLIES_TO]->(res:Resource)
        RETURN u.email AS identity, res.name AS resource, r.name AS role
    """
    execute_cypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission {action: 'execute'})
              -[:APPLIES_TO]->(res:Resource)
        RETURN u.email AS identity, res.name AS resource, r.name AS role
    """

    with driver.session(database=DB_NAME) as session:
        approvers = [(r['identity'], r['resource'], r['role']) for r in session.run(approve_cypher)]
        executors = [(r['identity'], r['resource'], r['role']) for r in session.run(execute_cypher)]

    for a_id, a_res, a_role in approvers:
        for e_id, e_res, e_role in executors:
            if a_id == e_id and a_res == e_res:
                print(f'  VIOLATION: {str(a_id):25s} | {str(a_res):15s} | '
                      f'approve via: {str(a_role):10s} | execute via: {e_role}')


# Query 5: Dormant Access Detection (OpenCypher for graph, SQL for AccessLog)
def run_query5(driver, pg_cur):
    print_header('Query 5: Dormant Access Detection',
                 'Find identities with permissions but no access in the last 90 days.')

    # Step 1: All identities with granted permissions (OpenCypher)
    cypher = """
        MATCH (u:Identity)
              -[:MEMBER_OF*1..3]->(g:`Group`)
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission)
              -[:APPLIES_TO]->(res:Resource)
        RETURN DISTINCT u.email AS identity, res.name AS resource
        ORDER BY identity
    """
    granted_identities = set()
    with driver.session(database=DB_NAME) as session:
        for r in session.run(cypher):
            granted_identities.add(r['identity'])

    # Step 2: Identities with recent access (SQL — document type)
    pg_cur.execute("""
        SELECT DISTINCT identityEmail
        FROM AccessLog
        WHERE recordedAt > '2025-12-06 00:00:00'
        ORDER BY identityEmail
    """)
    recent_identities = {row[0] for row in pg_cur.fetchall()}

    # Dormant = granted minus recent
    dormant = sorted(granted_identities - recent_identities)
    print('  Dormant identities (have permissions but no recent access):')
    for identity in dormant:
        print(f'    {identity}')


# Query 6: Behavioral Anomaly Detection (SQL — vectorNeighbors is ArcadeDB-only)
def run_query6(pg_cur):
    print_header('Query 6: Behavioral Anomaly Detection',
                 "Rank employees by similarity to a 'normal' session pattern. (SQL — vectorNeighbors)")

    pg_cur.execute("""
        SELECT email, department, identityType
        FROM Identity
        WHERE identityType = 'employee'
        ORDER BY vectorNeighbors('Identity[access_pattern_vec]', [0.5, 0.5, 0.3, 0.1, 0.2, 0.1, 0.1, 0.1], 10) DESC
        LIMIT 10
    """)
    for rank, row in enumerate(pg_cur.fetchall(), 1):
        print(f'  {rank}. {str(row[0]):25s} | {str(row[1]):15s} | {row[2]}')


# Query 7: Impact Analysis — What-If (OpenCypher via Bolt)
def run_query7(driver):
    print_header('Query 7: Impact Analysis (What-If)',
                 'What happens if we remove the Platform-Admins group?')

    # Step 1: Permissions granted through Platform-Admins
    print('  --- Permissions granted through Platform-Admins ---')
    perms_cypher = """
        MATCH (g:`Group` {name: 'Platform-Admins'})
              -[:HAS_ROLE]->(r:Role)
              -[:GRANTS]->(p:Permission)
              -[:APPLIES_TO]->(res:Resource)
        RETURN r.name AS role, p.action AS action, res.name AS resource
        ORDER BY resource
    """
    with driver.session(database=DB_NAME) as session:
        for r in session.run(perms_cypher):
            print(f'    {str(r["role"]):10s} | {str(r["action"]):8s} | {r["resource"]}')

    # Step 2: Identities affected (members of Platform-Admins, direct or transitive)
    print('  --- Identities affected ---')
    members_cypher = """
        MATCH (member:Identity)-[:MEMBER_OF*1..3]->(g:`Group` {name: 'Platform-Admins'})
        RETURN DISTINCT member.email AS identity
        ORDER BY identity
    """
    with driver.session(database=DB_NAME) as session:
        for r in session.run(members_cypher):
            print(f'    {r["identity"]}')


def main():
    bolt_uri = f'bolt://{HOST}:{BOLT_PORT}'
    driver = GraphDatabase.driver(bolt_uri, auth=(USER, PASSWORD))
    print(f'Connected to ArcadeDB via Bolt on port {BOLT_PORT}')

    pg_conn = psycopg.connect(
        host=HOST,
        port=PG_PORT,
        dbname=DB_NAME,
        user=USER,
        password=PASSWORD,
        autocommit=True,
    )
    print(f'Connected to ArcadeDB via PostgreSQL protocol on port {PG_PORT}')

    try:
        with pg_conn.cursor() as pg_cur:
            try_run(lambda: run_query1(driver), 'Query 1')
            try_run(lambda: run_query2(driver), 'Query 2')
            try_run(lambda: run_query3(driver, pg_cur), 'Query 3')
            try_run(lambda: run_query4(driver), 'Query 4')
            try_run(lambda: run_query5(driver, pg_cur), 'Query 5')
            try_run(lambda: run_query6(pg_cur), 'Query 6')
            try_run(lambda: run_query7(driver), 'Query 7')
    finally:
        pg_conn.close()
        driver.close()

    print('\nAll queries complete.')


if __name__ == '__main__':
    main()
