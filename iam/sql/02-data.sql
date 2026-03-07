-- ── Identities ──────────────────────────────────────────────────────────────
INSERT INTO Identity SET email = 'alice@company.com', identityType = 'employee', department = 'Engineering', title = 'Senior Developer', access_pattern_vec = [0.8, 0.7, 0.3, 0.1, 0.2, 0.1, 0.1, 0.1]
INSERT INTO Identity SET email = 'bob@company.com', identityType = 'contractor', department = 'External', title = 'Contractor', access_pattern_vec = [0.3, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
INSERT INTO Identity SET email = 'carol@company.com', identityType = 'employee', department = 'Finance', title = 'Finance Manager', access_pattern_vec = [0.2, 0.1, 0.9, 0.8, 0.7, 0.6, 0.5, 0.9]
INSERT INTO Identity SET email = 'dave@company.com', identityType = 'employee', department = 'Security', title = 'Security Analyst', access_pattern_vec = [0.4, 0.3, 0.6, 0.5, 0.3, 0.2, 0.1, 0.1]
INSERT INTO Identity SET email = 'eve@company.com', identityType = 'employee', department = 'Engineering', title = 'Platform Engineer', access_pattern_vec = [0.9, 0.8, 0.4, 0.2, 0.3, 0.1, 0.1, 0.1]
INSERT INTO Identity SET email = 'svc-deploy@company.com', identityType = 'service_account', department = 'Engineering', title = 'CI/CD Service', access_pattern_vec = [0.7, 0.6, 0.1, 0.1, 0.9, 0.1, 0.1, 0.1]
INSERT INTO Identity SET email = 'svc-backup@company.com', identityType = 'service_account', department = 'Operations', title = 'Backup Service', access_pattern_vec = [0.1, 0.1, 0.1, 0.1, 0.1, 0.8, 0.7, 0.1]
INSERT INTO Identity SET email = 'frank@company.com', identityType = 'contractor', department = 'External', title = 'Contractor', access_pattern_vec = [0.2, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
-- ── Groups ──────────────────────────────────────────────────────────────────
INSERT INTO `Group` SET name = 'Engineering', description = 'Engineering department'
INSERT INTO `Group` SET name = 'Platform-Admins', description = 'Infrastructure administrators'
INSERT INTO `Group` SET name = 'Finance', description = 'Finance department'
INSERT INTO `Group` SET name = 'Security', description = 'Security operations'
INSERT INTO `Group` SET name = 'Contractors', description = 'External contractors'
-- ── Roles ───────────────────────────────────────────────────────────────────
INSERT INTO Role SET name = 'Admin', description = 'Full administrative access'
INSERT INTO Role SET name = 'Developer', description = 'Development read/write access'
INSERT INTO Role SET name = 'Auditor', description = 'Read-only compliance auditing'
INSERT INTO Role SET name = 'Approver', description = 'Financial approval authority'
INSERT INTO Role SET name = 'Executor', description = 'Financial execution authority'
INSERT INTO Role SET name = 'Viewer', description = 'Read-only basic access'
-- ── Permissions ─────────────────────────────────────────────────────────────
INSERT INTO Permission SET action = 'admin'
INSERT INTO Permission SET action = 'approve'
INSERT INTO Permission SET action = 'execute'
INSERT INTO Permission SET action = 'read'
INSERT INTO Permission SET action = 'write'
INSERT INTO Permission SET action = 'deploy'
-- ── Resources ───────────────────────────────────────────────────────────────
INSERT INTO Resource SET name = 'Production-DB', classification = 'critical', data_sensitivity = 'high', compliance_scope = 'SOX'
INSERT INTO Resource SET name = 'Payment-API', classification = 'critical', data_sensitivity = 'high', compliance_scope = 'SOX'
INSERT INTO Resource SET name = 'Customer-Data', classification = 'critical', data_sensitivity = 'high', compliance_scope = 'GDPR'
INSERT INTO Resource SET name = 'CI-Pipeline', classification = 'internal', data_sensitivity = 'medium', compliance_scope = ''
INSERT INTO Resource SET name = 'Audit-System', classification = 'internal', data_sensitivity = 'medium', compliance_scope = 'SOX'
INSERT INTO Resource SET name = 'Internal-Wiki', classification = 'public', data_sensitivity = 'low', compliance_scope = ''
-- ── Policies ────────────────────────────────────────────────────────────────
INSERT INTO Policy SET name = 'SOX-Compliance', policyType = 'regulatory', description = 'Sarbanes-Oxley financial controls'
INSERT INTO Policy SET name = 'Data-Privacy', policyType = 'regulatory', description = 'GDPR data protection requirements'
INSERT INTO Policy SET name = 'Least-Privilege', policyType = 'operational', description = 'Minimum necessary access policy'
-- ── MEMBER_OF edges (Identity -> Group) ────────────────────────────────────
-- Alice and Eve are in Engineering
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'alice@company.com') TO (SELECT FROM `Group` WHERE name = 'Engineering')
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'eve@company.com') TO (SELECT FROM `Group` WHERE name = 'Engineering')
-- Eve is also in Platform-Admins
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'eve@company.com') TO (SELECT FROM `Group` WHERE name = 'Platform-Admins')
-- Carol is in Finance
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'carol@company.com') TO (SELECT FROM `Group` WHERE name = 'Finance')
-- Dave is in Security
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'dave@company.com') TO (SELECT FROM `Group` WHERE name = 'Security')
-- Bob and Frank are in Contractors
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'bob@company.com') TO (SELECT FROM `Group` WHERE name = 'Contractors')
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'frank@company.com') TO (SELECT FROM `Group` WHERE name = 'Contractors')
-- Contractors group is a member of Engineering (nested!) — creates the shadow admin path for Bob
CREATE EDGE MEMBER_OF FROM (SELECT FROM `Group` WHERE name = 'Contractors') TO (SELECT FROM `Group` WHERE name = 'Engineering')
-- Engineering group is a member of Platform-Admins (nested!) — deepens the chain
CREATE EDGE MEMBER_OF FROM (SELECT FROM `Group` WHERE name = 'Engineering') TO (SELECT FROM `Group` WHERE name = 'Platform-Admins')
-- svc-deploy direct membership in Engineering
CREATE EDGE MEMBER_OF FROM (SELECT FROM Identity WHERE email = 'svc-deploy@company.com') TO (SELECT FROM `Group` WHERE name = 'Engineering')
-- ── HAS_ROLE edges (Group/Identity -> Role) ────────────────────────────────
-- Platform-Admins group has Admin role
CREATE EDGE HAS_ROLE FROM (SELECT FROM `Group` WHERE name = 'Platform-Admins') TO (SELECT FROM Role WHERE name = 'Admin')
-- Engineering group has Developer role
CREATE EDGE HAS_ROLE FROM (SELECT FROM `Group` WHERE name = 'Engineering') TO (SELECT FROM Role WHERE name = 'Developer')
-- Finance group has both Approver and Executor roles (creates SoD violation for Carol)
CREATE EDGE HAS_ROLE FROM (SELECT FROM `Group` WHERE name = 'Finance') TO (SELECT FROM Role WHERE name = 'Approver')
CREATE EDGE HAS_ROLE FROM (SELECT FROM `Group` WHERE name = 'Finance') TO (SELECT FROM Role WHERE name = 'Executor')
-- Security group has Auditor role
CREATE EDGE HAS_ROLE FROM (SELECT FROM `Group` WHERE name = 'Security') TO (SELECT FROM Role WHERE name = 'Auditor')
-- svc-deploy has Developer role directly
CREATE EDGE HAS_ROLE FROM (SELECT FROM Identity WHERE email = 'svc-deploy@company.com') TO (SELECT FROM Role WHERE name = 'Developer')
-- svc-backup has Viewer role directly
CREATE EDGE HAS_ROLE FROM (SELECT FROM Identity WHERE email = 'svc-backup@company.com') TO (SELECT FROM Role WHERE name = 'Viewer')
-- Contractors group has Viewer role
CREATE EDGE HAS_ROLE FROM (SELECT FROM `Group` WHERE name = 'Contractors') TO (SELECT FROM Role WHERE name = 'Viewer')
-- ── GRANTS edges (Role -> Permission) ──────────────────────────────────────
-- Admin grants admin permission
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Admin') TO (SELECT FROM Permission WHERE action = 'admin')
-- Developer grants read, write, deploy
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Developer') TO (SELECT FROM Permission WHERE action = 'read')
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Developer') TO (SELECT FROM Permission WHERE action = 'write')
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Developer') TO (SELECT FROM Permission WHERE action = 'deploy')
-- Auditor grants read
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Auditor') TO (SELECT FROM Permission WHERE action = 'read')
-- Approver grants approve
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Approver') TO (SELECT FROM Permission WHERE action = 'approve')
-- Executor grants execute
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Executor') TO (SELECT FROM Permission WHERE action = 'execute')
-- Viewer grants read
CREATE EDGE GRANTS FROM (SELECT FROM Role WHERE name = 'Viewer') TO (SELECT FROM Permission WHERE action = 'read')
-- ── APPLIES_TO edges (Permission -> Resource) ──────────────────────────────
-- admin permission applies to Production-DB, Payment-API, Customer-Data
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'admin') TO (SELECT FROM Resource WHERE name = 'Production-DB')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'admin') TO (SELECT FROM Resource WHERE name = 'Payment-API')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'admin') TO (SELECT FROM Resource WHERE name = 'Customer-Data')
-- read permission applies to all resources
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'read') TO (SELECT FROM Resource WHERE name = 'Production-DB')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'read') TO (SELECT FROM Resource WHERE name = 'Payment-API')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'read') TO (SELECT FROM Resource WHERE name = 'Customer-Data')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'read') TO (SELECT FROM Resource WHERE name = 'CI-Pipeline')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'read') TO (SELECT FROM Resource WHERE name = 'Audit-System')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'read') TO (SELECT FROM Resource WHERE name = 'Internal-Wiki')
-- write permission applies to Production-DB, CI-Pipeline
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'write') TO (SELECT FROM Resource WHERE name = 'Production-DB')
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'write') TO (SELECT FROM Resource WHERE name = 'CI-Pipeline')
-- deploy permission applies to CI-Pipeline
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'deploy') TO (SELECT FROM Resource WHERE name = 'CI-Pipeline')
-- approve permission applies to Payment-API
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'approve') TO (SELECT FROM Resource WHERE name = 'Payment-API')
-- execute permission applies to Payment-API
CREATE EDGE APPLIES_TO FROM (SELECT FROM Permission WHERE action = 'execute') TO (SELECT FROM Resource WHERE name = 'Payment-API')
-- ── GOVERNED_BY edges (Resource -> Policy) ─────────────────────────────────
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Production-DB') TO (SELECT FROM Policy WHERE name = 'SOX-Compliance')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Payment-API') TO (SELECT FROM Policy WHERE name = 'SOX-Compliance')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Audit-System') TO (SELECT FROM Policy WHERE name = 'SOX-Compliance')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Customer-Data') TO (SELECT FROM Policy WHERE name = 'Data-Privacy')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Production-DB') TO (SELECT FROM Policy WHERE name = 'Least-Privilege')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Payment-API') TO (SELECT FROM Policy WHERE name = 'Least-Privilege')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'Customer-Data') TO (SELECT FROM Policy WHERE name = 'Least-Privilege')
CREATE EDGE GOVERNED_BY FROM (SELECT FROM Resource WHERE name = 'CI-Pipeline') TO (SELECT FROM Policy WHERE name = 'Least-Privilege')
-- ── AccessLog entries (time-series audit trail) ────────────────────────────
-- Recent activity (last 90 days)
INSERT INTO AccessLog SET identityEmail = 'alice@company.com', resourceName = 'Production-DB', action = 'write', source_ip = '10.0.1.10', recordedAt = '2026-03-05 09:15:00'
INSERT INTO AccessLog SET identityEmail = 'alice@company.com', resourceName = 'CI-Pipeline', action = 'deploy', source_ip = '10.0.1.10', recordedAt = '2026-03-04 14:30:00'
INSERT INTO AccessLog SET identityEmail = 'alice@company.com', resourceName = 'Production-DB', action = 'read', source_ip = '10.0.1.10', recordedAt = '2026-03-01 10:00:00'
INSERT INTO AccessLog SET identityEmail = 'carol@company.com', resourceName = 'Payment-API', action = 'approve', source_ip = '10.0.2.20', recordedAt = '2026-03-05 11:00:00'
INSERT INTO AccessLog SET identityEmail = 'carol@company.com', resourceName = 'Payment-API', action = 'execute', source_ip = '10.0.2.20', recordedAt = '2026-03-05 11:05:00'
INSERT INTO AccessLog SET identityEmail = 'dave@company.com', resourceName = 'Audit-System', action = 'read', source_ip = '10.0.3.30', recordedAt = '2026-03-04 16:00:00'
INSERT INTO AccessLog SET identityEmail = 'dave@company.com', resourceName = 'Production-DB', action = 'read', source_ip = '10.0.3.30', recordedAt = '2026-03-03 10:00:00'
INSERT INTO AccessLog SET identityEmail = 'eve@company.com', resourceName = 'Production-DB', action = 'admin', source_ip = '10.0.1.50', recordedAt = '2026-03-05 08:00:00'
INSERT INTO AccessLog SET identityEmail = 'eve@company.com', resourceName = 'Customer-Data', action = 'admin', source_ip = '10.0.1.50', recordedAt = '2026-03-02 13:00:00'
INSERT INTO AccessLog SET identityEmail = 'svc-deploy@company.com', resourceName = 'CI-Pipeline', action = 'deploy', source_ip = '10.0.10.1', recordedAt = '2026-03-05 06:00:00'
INSERT INTO AccessLog SET identityEmail = 'svc-deploy@company.com', resourceName = 'CI-Pipeline', action = 'deploy', source_ip = '10.0.10.1', recordedAt = '2026-03-04 06:00:00'
INSERT INTO AccessLog SET identityEmail = 'svc-deploy@company.com', resourceName = 'CI-Pipeline', action = 'deploy', source_ip = '10.0.10.1', recordedAt = '2026-03-03 06:00:00'
-- Older activity (outside 90-day window for dormant detection)
INSERT INTO AccessLog SET identityEmail = 'bob@company.com', resourceName = 'Internal-Wiki', action = 'read', source_ip = '192.168.1.100', recordedAt = '2025-09-15 10:00:00'
INSERT INTO AccessLog SET identityEmail = 'frank@company.com', resourceName = 'Internal-Wiki', action = 'read', source_ip = '192.168.1.101', recordedAt = '2025-08-20 14:00:00'
INSERT INTO AccessLog SET identityEmail = 'svc-backup@company.com', resourceName = 'Production-DB', action = 'read', source_ip = '10.0.10.2', recordedAt = '2025-10-01 02:00:00'
