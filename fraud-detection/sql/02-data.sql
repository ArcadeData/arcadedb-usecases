-- ── Fraud Ring Accounts (A–E) ────────────────────────────────────────────────
INSERT INTO Account SET id = 'acct-A', name = 'Alice', full_name = 'Alice M. Johnson', ssn = '111-22-3333', credit_limit = 10000.0, balance = 8500.0;
INSERT INTO Account SET id = 'acct-B', name = 'Bob', full_name = 'Bob K. Williams', ssn = '222-33-4444', credit_limit = 10000.0, balance = 9200.0;
INSERT INTO Account SET id = 'acct-C', name = 'Carol', full_name = 'Carol P. Davis', ssn = '333-44-5555', credit_limit = 10000.0, balance = 8800.0;
INSERT INTO Account SET id = 'acct-D', name = 'Dan', full_name = 'Daniel R. Miller', ssn = '444-55-6666', credit_limit = 10000.0, balance = 9100.0;
INSERT INTO Account SET id = 'acct-E', name = 'Eve', full_name = 'Eve S. Wilson', ssn = '555-66-7777', credit_limit = 10000.0, balance = 8700.0;
-- ── Synthetic Identity Pair (F–G) ───────────────────────────────────────────
INSERT INTO Account SET id = 'acct-F', name = 'Robert', full_name = 'Robert J. Smith', ssn = '123-45-6789', credit_limit = 15000.0, balance = 12000.0;
INSERT INTO Account SET id = 'acct-G', name = 'Rob', full_name = 'Rob Smith Jr.', ssn = '123-45-6789', credit_limit = 8000.0, balance = 5000.0;
-- ── Velocity Attacker (H) ───────────────────────────────────────────────────
INSERT INTO Account SET id = 'acct-H', name = 'Hank', full_name = 'Hank T. Brown', ssn = '666-77-8888', credit_limit = 5000.0, balance = 200.0;
-- ── Legitimate Accounts (L1–L3) ─────────────────────────────────────────────
INSERT INTO Account SET id = 'acct-L1', name = 'Liam', full_name = 'Liam O. Garcia', ssn = '777-88-9999', credit_limit = 20000.0, balance = 15000.0;
INSERT INTO Account SET id = 'acct-L2', name = 'Lisa', full_name = 'Lisa N. Chen', ssn = '888-99-0000', credit_limit = 25000.0, balance = 22000.0;
INSERT INTO Account SET id = 'acct-L3', name = 'Luke', full_name = 'Luke W. Taylor', ssn = '999-00-1111', credit_limit = 18000.0, balance = 16500.0;
-- ── Customers (one per account) ─────────────────────────────────────────────
INSERT INTO Customer SET id = 'acct-A', baseline_behavior = 'normal', recent_behavior = 'suspicious', profile_embedding = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2];
INSERT INTO Customer SET id = 'acct-B', baseline_behavior = 'normal', recent_behavior = 'suspicious', profile_embedding = [0.88, 0.82, 0.72, 0.58, 0.48, 0.42, 0.32, 0.22];
INSERT INTO Customer SET id = 'acct-C', baseline_behavior = 'normal', recent_behavior = 'suspicious', profile_embedding = [0.91, 0.79, 0.68, 0.62, 0.52, 0.38, 0.28, 0.18];
INSERT INTO Customer SET id = 'acct-D', baseline_behavior = 'normal', recent_behavior = 'suspicious', profile_embedding = [0.87, 0.83, 0.73, 0.57, 0.47, 0.43, 0.33, 0.23];
INSERT INTO Customer SET id = 'acct-E', baseline_behavior = 'normal', recent_behavior = 'suspicious', profile_embedding = [0.92, 0.78, 0.69, 0.61, 0.51, 0.39, 0.29, 0.19];
INSERT INTO Customer SET id = 'acct-F', baseline_behavior = 'normal', recent_behavior = 'normal', profile_embedding = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.1];
INSERT INTO Customer SET id = 'acct-G', baseline_behavior = 'normal', recent_behavior = 'normal', profile_embedding = [0.32, 0.38, 0.52, 0.58, 0.72, 0.78, 0.88, 0.12];
INSERT INTO Customer SET id = 'acct-H', baseline_behavior = 'normal', recent_behavior = 'anomalous', profile_embedding = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
INSERT INTO Customer SET id = 'acct-L1', baseline_behavior = 'normal', recent_behavior = 'normal', profile_embedding = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];
INSERT INTO Customer SET id = 'acct-L2', baseline_behavior = 'normal', recent_behavior = 'normal', profile_embedding = [0.4, 0.6, 0.4, 0.6, 0.4, 0.6, 0.4, 0.6];
INSERT INTO Customer SET id = 'acct-L3', baseline_behavior = 'normal', recent_behavior = 'normal', profile_embedding = [0.6, 0.4, 0.6, 0.4, 0.6, 0.4, 0.6, 0.4];
-- ── Devices ─────────────────────────────────────────────────────────────────
INSERT INTO Device SET id = 'dev-shared', fingerprint = 'fp-AABBCCDD';
INSERT INTO Device SET id = 'dev-F', fingerprint = 'fp-FF001122';
INSERT INTO Device SET id = 'dev-G', fingerprint = 'fp-GG334455';
INSERT INTO Device SET id = 'dev-H', fingerprint = 'fp-HH667788';
INSERT INTO Device SET id = 'dev-L1', fingerprint = 'fp-L1AABB00';
INSERT INTO Device SET id = 'dev-L2', fingerprint = 'fp-L2CCDD00';
INSERT INTO Device SET id = 'dev-L3', fingerprint = 'fp-L3EEFF00';
-- ── Phones ──────────────────────────────────────────────────────────────────
INSERT INTO Phone SET number = '555-000-RING';
INSERT INTO Phone SET number = '555-111-FFFF';
INSERT INTO Phone SET number = '555-222-GGGG';
INSERT INTO Phone SET number = '555-333-HHHH';
INSERT INTO Phone SET number = '555-444-LLL1';
INSERT INTO Phone SET number = '555-555-LLL2';
INSERT INTO Phone SET number = '555-666-LLL3';
-- ── Addresses ───────────────────────────────────────────────────────────────
INSERT INTO Address SET street = '100 Ring Road', city = 'Fraudville', zip = '00001';
INSERT INTO Address SET street = '200 Synth Ave', city = 'Faketown', zip = '00002';
INSERT INTO Address SET street = '300 Velocity Blvd', city = 'Speedcity', zip = '00003';
INSERT INTO Address SET street = '400 Legit Lane', city = 'Realville', zip = '10001';
INSERT INTO Address SET street = '500 Honest St', city = 'Trustburg', zip = '10002';
INSERT INTO Address SET street = '600 Genuine Dr', city = 'Goodtown', zip = '10003';
-- ── Emails ──────────────────────────────────────────────────────────────────
INSERT INTO Email SET address = 'alice@example.com';
INSERT INTO Email SET address = 'bob@example.com';
INSERT INTO Email SET address = 'carol@example.com';
INSERT INTO Email SET address = 'dan@example.com';
INSERT INTO Email SET address = 'eve@example.com';
INSERT INTO Email SET address = 'robert@example.com';
INSERT INTO Email SET address = 'rob@example.com';
INSERT INTO Email SET address = 'hank@example.com';
INSERT INTO Email SET address = 'liam@example.com';
INSERT INTO Email SET address = 'lisa@example.com';
INSERT INTO Email SET address = 'luke@example.com';
-- ── Beneficiaries ───────────────────────────────────────────────────────────
INSERT INTO Beneficiary SET id = 'ben-shell1', name = 'Shell Corp Alpha';
INSERT INTO Beneficiary SET id = 'ben-shell2', name = 'Shell Corp Beta';
INSERT INTO Beneficiary SET id = 'ben-legit1', name = 'Acme Supplies';
-- ── USES_DEVICE edges (fraud ring shares dev-shared) ────────────────────────
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-A') TO (SELECT FROM Device WHERE id = 'dev-shared');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-B') TO (SELECT FROM Device WHERE id = 'dev-shared');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-C') TO (SELECT FROM Device WHERE id = 'dev-shared');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-D') TO (SELECT FROM Device WHERE id = 'dev-shared');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-E') TO (SELECT FROM Device WHERE id = 'dev-shared');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-F') TO (SELECT FROM Device WHERE id = 'dev-F');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-G') TO (SELECT FROM Device WHERE id = 'dev-G');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-H') TO (SELECT FROM Device WHERE id = 'dev-H');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-L1') TO (SELECT FROM Device WHERE id = 'dev-L1');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-L2') TO (SELECT FROM Device WHERE id = 'dev-L2');
CREATE EDGE USES_DEVICE FROM (SELECT FROM Account WHERE id = 'acct-L3') TO (SELECT FROM Device WHERE id = 'dev-L3');
-- ── HAS_PHONE edges (fraud ring shares phone-shared) ────────────────────────
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-A') TO (SELECT FROM Phone WHERE number = '555-000-RING');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-B') TO (SELECT FROM Phone WHERE number = '555-000-RING');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-C') TO (SELECT FROM Phone WHERE number = '555-000-RING');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-D') TO (SELECT FROM Phone WHERE number = '555-000-RING');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-E') TO (SELECT FROM Phone WHERE number = '555-000-RING');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-F') TO (SELECT FROM Phone WHERE number = '555-111-FFFF');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-G') TO (SELECT FROM Phone WHERE number = '555-222-GGGG');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-H') TO (SELECT FROM Phone WHERE number = '555-333-HHHH');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-L1') TO (SELECT FROM Phone WHERE number = '555-444-LLL1');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-L2') TO (SELECT FROM Phone WHERE number = '555-555-LLL2');
CREATE EDGE HAS_PHONE FROM (SELECT FROM Account WHERE id = 'acct-L3') TO (SELECT FROM Phone WHERE number = '555-666-LLL3');
-- ── HAS_ADDRESS edges (F and G share same address) ──────────────────────────
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-A') TO (SELECT FROM Address WHERE street = '100 Ring Road');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-B') TO (SELECT FROM Address WHERE street = '100 Ring Road');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-C') TO (SELECT FROM Address WHERE street = '100 Ring Road');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-D') TO (SELECT FROM Address WHERE street = '100 Ring Road');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-E') TO (SELECT FROM Address WHERE street = '100 Ring Road');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-F') TO (SELECT FROM Address WHERE street = '200 Synth Ave');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-G') TO (SELECT FROM Address WHERE street = '200 Synth Ave');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-H') TO (SELECT FROM Address WHERE street = '300 Velocity Blvd');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-L1') TO (SELECT FROM Address WHERE street = '400 Legit Lane');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-L2') TO (SELECT FROM Address WHERE street = '500 Honest St');
CREATE EDGE HAS_ADDRESS FROM (SELECT FROM Account WHERE id = 'acct-L3') TO (SELECT FROM Address WHERE street = '600 Genuine Dr');
-- ── HAS_EMAIL edges ─────────────────────────────────────────────────────────
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-A') TO (SELECT FROM Email WHERE address = 'alice@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-B') TO (SELECT FROM Email WHERE address = 'bob@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-C') TO (SELECT FROM Email WHERE address = 'carol@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-D') TO (SELECT FROM Email WHERE address = 'dan@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-E') TO (SELECT FROM Email WHERE address = 'eve@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-F') TO (SELECT FROM Email WHERE address = 'robert@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-G') TO (SELECT FROM Email WHERE address = 'rob@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-H') TO (SELECT FROM Email WHERE address = 'hank@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-L1') TO (SELECT FROM Email WHERE address = 'liam@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-L2') TO (SELECT FROM Email WHERE address = 'lisa@example.com');
CREATE EDGE HAS_EMAIL FROM (SELECT FROM Account WHERE id = 'acct-L3') TO (SELECT FROM Email WHERE address = 'luke@example.com');
-- ── BENEFICIARY_OF edges ────────────────────────────────────────────────────
CREATE EDGE BENEFICIARY_OF FROM (SELECT FROM Account WHERE id = 'acct-A') TO (SELECT FROM Beneficiary WHERE id = 'ben-shell1');
CREATE EDGE BENEFICIARY_OF FROM (SELECT FROM Account WHERE id = 'acct-B') TO (SELECT FROM Beneficiary WHERE id = 'ben-shell1');
CREATE EDGE BENEFICIARY_OF FROM (SELECT FROM Account WHERE id = 'acct-C') TO (SELECT FROM Beneficiary WHERE id = 'ben-shell2');
CREATE EDGE BENEFICIARY_OF FROM (SELECT FROM Account WHERE id = 'acct-L1') TO (SELECT FROM Beneficiary WHERE id = 'ben-legit1');
-- ── TRANSFERRED_TO edges (circular: A→B→C→D→E→A) ───────────────────────────
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-A') TO (SELECT FROM Account WHERE id = 'acct-B') SET amount = 9000.0, ts = '2026-02-05T10:00:00Z';
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-B') TO (SELECT FROM Account WHERE id = 'acct-C') SET amount = 8500.0, ts = '2026-02-10T14:30:00Z';
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-C') TO (SELECT FROM Account WHERE id = 'acct-D') SET amount = 9200.0, ts = '2026-02-15T09:15:00Z';
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-D') TO (SELECT FROM Account WHERE id = 'acct-E') SET amount = 8800.0, ts = '2026-02-20T16:45:00Z';
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-E') TO (SELECT FROM Account WHERE id = 'acct-A') SET amount = 9500.0, ts = '2026-02-25T11:20:00Z';
-- Normal transfers for legitimate accounts
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-L1') TO (SELECT FROM Account WHERE id = 'acct-L2') SET amount = 500.0, ts = '2026-02-18T08:00:00Z';
CREATE EDGE TRANSFERRED_TO FROM (SELECT FROM Account WHERE id = 'acct-L2') TO (SELECT FROM Account WHERE id = 'acct-L3') SET amount = 250.0, ts = '2026-02-22T12:00:00Z';
-- ── Transactions (velocity attack for H — 10 txns in 5 minutes) ─────────────
INSERT INTO Transaction SET id = 'txn-H01', account_id = 'acct-H', amount = 499.99, merchant = 'QuickMart', behavior_embedding = [0.9, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.9], ts = '2026-03-01T13:00:00Z';
INSERT INTO Transaction SET id = 'txn-H02', account_id = 'acct-H', amount = 489.50, merchant = 'FastShop', behavior_embedding = [0.85, 0.15, 0.1, 0.1, 0.1, 0.1, 0.15, 0.85], ts = '2026-03-01T13:00:30Z';
INSERT INTO Transaction SET id = 'txn-H03', account_id = 'acct-H', amount = 475.00, merchant = 'SpeedBuy', behavior_embedding = [0.88, 0.12, 0.1, 0.1, 0.1, 0.1, 0.12, 0.88], ts = '2026-03-01T13:01:00Z';
INSERT INTO Transaction SET id = 'txn-H04', account_id = 'acct-H', amount = 450.00, merchant = 'RushStore', behavior_embedding = [0.92, 0.08, 0.1, 0.1, 0.1, 0.1, 0.08, 0.92], ts = '2026-03-01T13:01:30Z';
INSERT INTO Transaction SET id = 'txn-H05', account_id = 'acct-H', amount = 510.00, merchant = 'QuickMart', behavior_embedding = [0.87, 0.13, 0.1, 0.1, 0.1, 0.1, 0.13, 0.87], ts = '2026-03-01T13:02:00Z';
INSERT INTO Transaction SET id = 'txn-H06', account_id = 'acct-H', amount = 495.00, merchant = 'FastShop', behavior_embedding = [0.91, 0.09, 0.1, 0.1, 0.1, 0.1, 0.09, 0.91], ts = '2026-03-01T13:02:30Z';
INSERT INTO Transaction SET id = 'txn-H07', account_id = 'acct-H', amount = 520.00, merchant = 'SpeedBuy', behavior_embedding = [0.86, 0.14, 0.1, 0.1, 0.1, 0.1, 0.14, 0.86], ts = '2026-03-01T13:03:00Z';
INSERT INTO Transaction SET id = 'txn-H08', account_id = 'acct-H', amount = 480.00, merchant = 'RushStore', behavior_embedding = [0.93, 0.07, 0.1, 0.1, 0.1, 0.1, 0.07, 0.93], ts = '2026-03-01T13:03:30Z';
INSERT INTO Transaction SET id = 'txn-H09', account_id = 'acct-H', amount = 465.00, merchant = 'QuickMart', behavior_embedding = [0.89, 0.11, 0.1, 0.1, 0.1, 0.1, 0.11, 0.89], ts = '2026-03-01T13:04:00Z';
INSERT INTO Transaction SET id = 'txn-H10', account_id = 'acct-H', amount = 505.00, merchant = 'FastShop', behavior_embedding = [0.9, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.9], ts = '2026-03-01T13:04:30Z';
-- Normal transactions for legitimate accounts (behavior close to profile)
INSERT INTO Transaction SET id = 'txn-L1-01', account_id = 'acct-L1', amount = 45.00, merchant = 'Grocery Store', behavior_embedding = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5], ts = '2026-02-28T09:00:00Z';
INSERT INTO Transaction SET id = 'txn-L1-02', account_id = 'acct-L1', amount = 120.00, merchant = 'Gas Station', behavior_embedding = [0.48, 0.52, 0.5, 0.5, 0.5, 0.5, 0.48, 0.52], ts = '2026-02-28T14:00:00Z';
INSERT INTO Transaction SET id = 'txn-L2-01', account_id = 'acct-L2', amount = 85.00, merchant = 'Restaurant', behavior_embedding = [0.4, 0.6, 0.4, 0.6, 0.4, 0.6, 0.4, 0.6], ts = '2026-02-27T18:30:00Z';
INSERT INTO Transaction SET id = 'txn-L3-01', account_id = 'acct-L3', amount = 200.00, merchant = 'Department Store', behavior_embedding = [0.6, 0.4, 0.6, 0.4, 0.6, 0.4, 0.6, 0.4], ts = '2026-02-26T11:00:00Z';
-- Transactions for fraud ring (amounts for correlation query)
INSERT INTO Transaction SET id = 'txn-A01', account_id = 'acct-A', amount = 9000.0, merchant = 'Transfer', behavior_embedding = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2], ts = '2026-02-05T10:00:00Z';
INSERT INTO Transaction SET id = 'txn-A02', account_id = 'acct-A', amount = 8500.0, merchant = 'Transfer', behavior_embedding = [0.88, 0.82, 0.72, 0.58, 0.48, 0.42, 0.32, 0.22], ts = '2026-02-10T14:00:00Z';
INSERT INTO Transaction SET id = 'txn-A03', account_id = 'acct-A', amount = 9200.0, merchant = 'Transfer', behavior_embedding = [0.91, 0.79, 0.68, 0.62, 0.52, 0.38, 0.28, 0.18], ts = '2026-02-15T09:00:00Z';
INSERT INTO Transaction SET id = 'txn-B01', account_id = 'acct-B', amount = 8500.0, merchant = 'Transfer', behavior_embedding = [0.88, 0.82, 0.72, 0.58, 0.48, 0.42, 0.32, 0.22], ts = '2026-02-10T14:30:00Z';
INSERT INTO Transaction SET id = 'txn-B02', account_id = 'acct-B', amount = 9200.0, merchant = 'Transfer', behavior_embedding = [0.87, 0.83, 0.73, 0.57, 0.47, 0.43, 0.33, 0.23], ts = '2026-02-15T09:30:00Z';
INSERT INTO Transaction SET id = 'txn-B03', account_id = 'acct-B', amount = 8800.0, merchant = 'Transfer', behavior_embedding = [0.92, 0.78, 0.69, 0.61, 0.51, 0.39, 0.29, 0.19], ts = '2026-02-20T16:00:00Z';
-- ── Deposits (structuring pattern for fraud ring) ───────────────────────────
INSERT INTO Deposit SET account_id = 'acct-A', amount = 9500.0, ts = '2026-02-05T08:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-A', amount = 9800.0, ts = '2026-02-05T10:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-A', amount = 9200.0, ts = '2026-02-05T14:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-B', amount = 8500.0, ts = '2026-02-06T09:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-B', amount = 9100.0, ts = '2026-02-06T11:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-B', amount = 8800.0, ts = '2026-02-06T15:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-C', amount = 9900.0, ts = '2026-02-07T08:30:00Z';
INSERT INTO Deposit SET account_id = 'acct-C', amount = 9700.0, ts = '2026-02-07T12:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-C', amount = 8600.0, ts = '2026-02-07T16:30:00Z';
-- Normal deposits for legitimate accounts
INSERT INTO Deposit SET account_id = 'acct-L1', amount = 3000.0, ts = '2026-02-15T09:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-L2', amount = 5500.0, ts = '2026-02-20T10:00:00Z';
INSERT INTO Deposit SET account_id = 'acct-L3', amount = 1200.0, ts = '2026-02-25T11:00:00Z';
