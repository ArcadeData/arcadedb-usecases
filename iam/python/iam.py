#!/usr/bin/env python3
"""IAM — all seven query patterns via PostgreSQL wire protocol (psycopg)."""

import os
import psycopg


HOST     = os.environ.get('ARCADEDB_HOST', 'localhost')
PG_PORT  = int(os.environ.get('ARCADEDB_PG_PORT', '5432'))
DB_NAME  = 'IAM'
USER     = os.environ.get('ARCADEDB_USER', 'root')
PASSWORD = os.environ.get('ARCADEDB_PASS', 'arcadedb')


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


# Query 1: Permission Resolution
def run_query1(cur):
    print_header('Query 1: Permission Resolution',
                 "Discover all resources alice@company.com can access through any chain.")

    cur.execute("""
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
        ORDER BY resource, action
    """)
    for row in cur.fetchall():
        print(f'  {str(row[0]):20s} | {str(row[1]):8s} | role: {str(row[2]):12s} | group: {row[3]}')


# Query 2: Shadow Admin Detection
def run_query2(cur):
    print_header('Query 2: Shadow Admin Detection',
                 'Find contractors/service accounts with admin on critical resources.')

    cur.execute("""
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
        ORDER BY identity
    """)
    for row in cur.fetchall():
        print(f'  {str(row[0]):30s} | {str(row[1]):16s} | {str(row[2]):20s} | via: {row[3]}')


# Query 3: SOX Compliance Audit
def run_query3(cur):
    print_header('Query 3: SOX Compliance Audit',
                 'Track access to SOX-governed resources with policy lineage.')

    # Step 1: SOX-governed resources via GOVERNED_BY edge
    print('  --- SOX-governed resources ---')
    cur.execute("""
        SELECT resource, policy
        FROM (
          MATCH {type: Resource, as: res}
                .out('GOVERNED_BY'){as: pol, where: (name = 'SOX-Compliance')}
          RETURN res.name AS resource, pol.name AS policy
        )
    """)
    sox_resources = []
    for row in cur.fetchall():
        sox_resources.append(row[0])
        print(f'    {str(row[0]):20s} | policy: {row[1]}')

    # Step 2: Access logs for SOX-scoped resources
    print('  --- Access logs for SOX-scoped resources ---')
    resource_list = ', '.join(f"'{r}'" for r in sox_resources)
    cur.execute(f"""
        SELECT identityEmail, action, resourceName, recordedAt, source_ip
        FROM AccessLog
        WHERE resourceName IN [{resource_list}]
          AND recordedAt > '2025-12-01 00:00:00'
        ORDER BY recordedAt DESC
    """)
    for row in cur.fetchall():
        print(f'    {str(row[0]):25s} | {str(row[1]):8s} | {str(row[2]):15s} | {row[3]} | {row[4]}')


# Query 4: Separation of Duties Violation
def run_query4(cur):
    print_header('Query 4: Separation of Duties Violation',
                 'Find users who can both approve AND execute on the same resource.')

    # Step 1: Identities with approve permission
    cur.execute("""
        SELECT identity, resource, role
        FROM (
          MATCH {type: Identity, as: u}
                .out('MEMBER_OF'){while: ($depth < 3)}
                .out('HAS_ROLE'){as: r}
                .out('GRANTS'){where: (action = 'approve')}
                .out('APPLIES_TO'){as: res}
          RETURN u.email AS identity, res.name AS resource, r.name AS role
        )
    """)
    approvers = [(row[0], row[1], row[2]) for row in cur.fetchall()]

    # Step 2: Identities with execute permission
    cur.execute("""
        SELECT identity, resource, role
        FROM (
          MATCH {type: Identity, as: u}
                .out('MEMBER_OF'){while: ($depth < 3)}
                .out('HAS_ROLE'){as: r}
                .out('GRANTS'){where: (action = 'execute')}
                .out('APPLIES_TO'){as: res}
          RETURN u.email AS identity, res.name AS resource, r.name AS role
        )
    """)
    executors = [(row[0], row[1], row[2]) for row in cur.fetchall()]

    # Find violations: same identity + same resource in both lists
    for a_id, a_res, a_role in approvers:
        for e_id, e_res, e_role in executors:
            if a_id == e_id and a_res == e_res:
                print(f'  VIOLATION: {str(a_id):25s} | {str(a_res):15s} | approve via: {str(a_role):10s} | execute via: {e_role}')


# Query 5: Dormant Access Detection
def run_query5(cur):
    print_header('Query 5: Dormant Access Detection',
                 'Find identities with permissions but no access in the last 90 days.')

    # Step 1: All identities with granted permissions
    cur.execute("""
        SELECT DISTINCT identity, resource
        FROM (
          MATCH {type: Identity, as: u}
                .out('MEMBER_OF'){while: ($depth < 3)}
                .out('HAS_ROLE'){}
                .out('GRANTS'){}
                .out('APPLIES_TO'){as: res}
          RETURN u.email AS identity, res.name AS resource
        )
        ORDER BY identity
    """)
    granted_identities = set()
    for row in cur.fetchall():
        granted_identities.add(row[0])

    # Step 2: Identities with recent access
    cur.execute("""
        SELECT DISTINCT identityEmail
        FROM AccessLog
        WHERE recordedAt > '2025-12-06 00:00:00'
        ORDER BY identityEmail
    """)
    recent_identities = {row[0] for row in cur.fetchall()}

    # Dormant = granted minus recent
    dormant = sorted(granted_identities - recent_identities)
    print('  Dormant identities (have permissions but no recent access):')
    for identity in dormant:
        print(f'    {identity}')


# Query 6: Behavioral Anomaly Detection
def run_query6(cur):
    print_header('Query 6: Behavioral Anomaly Detection',
                 "Rank employees by similarity to a 'normal' session pattern.")

    cur.execute("""
        SELECT email, department, identityType
        FROM Identity
        WHERE identityType = 'employee'
        ORDER BY vectorNeighbors('Identity[access_pattern_vec]', [0.5, 0.5, 0.3, 0.1, 0.2, 0.1, 0.1, 0.1], 10) DESC
        LIMIT 10
    """)
    for rank, row in enumerate(cur.fetchall(), 1):
        print(f'  {rank}. {str(row[0]):25s} | {str(row[1]):15s} | {row[2]}')


# Query 7: Impact Analysis (What-If)
def run_query7(cur):
    print_header('Query 7: Impact Analysis (What-If)',
                 'What happens if we remove the Platform-Admins group?')

    cur.execute("""
        SELECT identity, role, action, resource
        FROM (
          MATCH {type: Identity, as: u}
                .out('MEMBER_OF'){while: ($depth < 3), where: (name = 'Platform-Admins')}{as: target}
                .out('HAS_ROLE'){as: r}
                .out('GRANTS'){as: p}
                .out('APPLIES_TO'){as: res}
          RETURN u.email AS identity, r.name AS role,
                 p.action AS action, res.name AS resource
        )
        ORDER BY identity, resource
    """)
    for row in cur.fetchall():
        print(f'  {str(row[0]):30s} | {str(row[1]):10s} | {str(row[2]):8s} | {row[3]}')


def main():
    conn = psycopg.connect(
        host=HOST,
        port=PG_PORT,
        dbname=DB_NAME,
        user=USER,
        password=PASSWORD,
        autocommit=True,
    )
    print(f'Connected to ArcadeDB via PostgreSQL protocol on port {PG_PORT}')

    try:
        with conn.cursor() as cur:
            try_run(lambda: run_query1(cur), 'Query 1')
            try_run(lambda: run_query2(cur), 'Query 2')
            try_run(lambda: run_query3(cur), 'Query 3')
            try_run(lambda: run_query4(cur), 'Query 4')
            try_run(lambda: run_query5(cur), 'Query 5')
            try_run(lambda: run_query6(cur), 'Query 6')
            try_run(lambda: run_query7(cur), 'Query 7')
    finally:
        conn.close()

    print('\nAll queries complete.')


if __name__ == '__main__':
    main()
