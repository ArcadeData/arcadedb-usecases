-- === Fraud Domain: Accounts ===
-- a1-a3: legit, a4-a5: suspicious, a6: flagged
INSERT INTO Account SET accountId = 'a1', accountType = 'personal', signupSource = 'organic', flagged = false, behaviorVec = [0.1, 0.2, 0.8, 0.9];
INSERT INTO Account SET accountId = 'a2', accountType = 'personal', signupSource = 'referral', flagged = false, behaviorVec = [0.2, 0.1, 0.9, 0.8];
INSERT INTO Account SET accountId = 'a3', accountType = 'business', signupSource = 'organic', flagged = false, behaviorVec = [0.1, 0.3, 0.7, 0.9];
INSERT INTO Account SET accountId = 'a4', accountType = 'personal', signupSource = 'ad_campaign', flagged = false, behaviorVec = [0.7, 0.6, 0.2, 0.3];
INSERT INTO Account SET accountId = 'a5', accountType = 'personal', signupSource = 'ad_campaign', flagged = false, behaviorVec = [0.8, 0.7, 0.2, 0.1];
INSERT INTO Account SET accountId = 'a6', accountType = 'personal', signupSource = 'unknown', flagged = true, behaviorVec = [0.9, 0.8, 0.1, 0.2];
-- Merchants
INSERT INTO Merchant SET merchantId = 'm1', category = 'grocery', riskTier = 'low';
INSERT INTO Merchant SET merchantId = 'm2', category = 'electronics', riskTier = 'low';
INSERT INTO Merchant SET merchantId = 'm3', category = 'gambling', riskTier = 'high';
INSERT INTO Merchant SET merchantId = 'm4', category = 'crypto', riskTier = 'high';
-- TRANSFERRED edges (money flows; a4-a6 form a circular pattern)
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a2') SET amount = 500.00, recordedAt = '2026-03-01 10:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a2') TO (SELECT FROM Account WHERE accountId = 'a3') SET amount = 200.00, recordedAt = '2026-03-02 11:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a3') SET amount = 150.00, recordedAt = '2026-03-03 09:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a6') SET amount = 3000.00, recordedAt = '2026-03-10 02:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a6') TO (SELECT FROM Account WHERE accountId = 'a5') SET amount = 2800.00, recordedAt = '2026-03-10 02:30:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Account WHERE accountId = 'a4') SET amount = 2500.00, recordedAt = '2026-03-10 03:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a5') SET amount = 1500.00, recordedAt = '2026-03-11 04:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a6') TO (SELECT FROM Account WHERE accountId = 'a4') SET amount = 4000.00, recordedAt = '2026-03-12 01:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a3') TO (SELECT FROM Account WHERE accountId = 'a1') SET amount = 100.00, recordedAt = '2026-03-05 14:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a2') TO (SELECT FROM Account WHERE accountId = 'a1') SET amount = 250.00, recordedAt = '2026-03-06 16:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Account WHERE accountId = 'a6') SET amount = 1800.00, recordedAt = '2026-03-13 05:00:00';
CREATE EDGE TRANSFERRED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a4') SET amount = 300.00, recordedAt = '2026-03-08 12:00:00';
-- LINKED_DEVICE edges (a4 and a5 share devices with flagged a6)
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a6') SET deviceId = 'dev-001';
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Account WHERE accountId = 'a6') SET deviceId = 'dev-002';
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Account WHERE accountId = 'a5') SET deviceId = 'dev-003';
CREATE EDGE LINKED_DEVICE FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Account WHERE accountId = 'a2') SET deviceId = 'dev-004';
-- TRANSACTED edges (account -> merchant)
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Merchant WHERE merchantId = 'm1') SET amount = 85.50, recordedAt = '2026-03-01 09:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a1') TO (SELECT FROM Merchant WHERE merchantId = 'm2') SET amount = 450.00, recordedAt = '2026-03-02 14:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a2') TO (SELECT FROM Merchant WHERE merchantId = 'm1') SET amount = 62.30, recordedAt = '2026-03-03 10:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Merchant WHERE merchantId = 'm3') SET amount = 5000.00, recordedAt = '2026-03-10 22:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a4') TO (SELECT FROM Merchant WHERE merchantId = 'm4') SET amount = 8000.00, recordedAt = '2026-03-11 01:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a5') TO (SELECT FROM Merchant WHERE merchantId = 'm3') SET amount = 3500.00, recordedAt = '2026-03-12 23:00:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a6') TO (SELECT FROM Merchant WHERE merchantId = 'm4') SET amount = 12000.00, recordedAt = '2026-03-10 00:30:00';
CREATE EDGE TRANSACTED FROM (SELECT FROM Account WHERE accountId = 'a3') TO (SELECT FROM Merchant WHERE merchantId = 'm2') SET amount = 320.00, recordedAt = '2026-03-04 15:00:00';
-- TransactionMetric documents (time-bucketed velocity data)
INSERT INTO TransactionMetric SET accountId = 'a1', txCount = 5, totalAmount = 1200.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a1', txCount = 3, totalAmount = 800.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a1', txCount = 4, totalAmount = 950.00, recordedAt = '2026-03-15 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a2', txCount = 2, totalAmount = 400.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a2', txCount = 3, totalAmount = 600.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a3', txCount = 4, totalAmount = 1500.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a3', txCount = 2, totalAmount = 700.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a4', txCount = 15, totalAmount = 25000.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a4', txCount = 22, totalAmount = 48000.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a4', txCount = 30, totalAmount = 72000.00, recordedAt = '2026-03-15 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a5', txCount = 8, totalAmount = 12000.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a5', txCount = 18, totalAmount = 35000.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a6', txCount = 25, totalAmount = 60000.00, recordedAt = '2026-03-01 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a6', txCount = 35, totalAmount = 95000.00, recordedAt = '2026-03-08 00:00:00';
INSERT INTO TransactionMetric SET accountId = 'a6', txCount = 40, totalAmount = 120000.00, recordedAt = '2026-03-15 00:00:00';
-- === Recommendation Domain: Users ===
INSERT INTO User SET userId = 'u1', preferenceVec = [0.9, 0.1, 0.1, 0.1];
INSERT INTO User SET userId = 'u2', preferenceVec = [0.7, 0.3, 0.1, 0.1];
INSERT INTO User SET userId = 'u3', preferenceVec = [0.1, 0.9, 0.1, 0.1];
INSERT INTO User SET userId = 'u4', preferenceVec = [0.1, 0.1, 0.9, 0.1];
INSERT INTO User SET userId = 'u5', preferenceVec = [0.4, 0.4, 0.2, 0.1];
-- Products
INSERT INTO Product SET productId = 'p1', name = 'Laptop', category = 'Electronics', price = 999.99, embedding = [0.9, 0.1, 0.1, 0.1];
INSERT INTO Product SET productId = 'p2', name = 'Phone', category = 'Electronics', price = 699.99, embedding = [0.8, 0.2, 0.1, 0.1];
INSERT INTO Product SET productId = 'p3', name = 'Headphones', category = 'Electronics', price = 199.99, embedding = [0.7, 0.2, 0.2, 0.1];
INSERT INTO Product SET productId = 'p4', name = 'ML Textbook', category = 'Books', price = 79.99, embedding = [0.1, 0.9, 0.1, 0.1];
INSERT INTO Product SET productId = 'p5', name = 'Data Science Guide', category = 'Books', price = 49.99, embedding = [0.2, 0.8, 0.1, 0.1];
INSERT INTO Product SET productId = 'p6', name = 'Python Cookbook', category = 'Books', price = 39.99, embedding = [0.1, 0.8, 0.2, 0.1];
INSERT INTO Product SET productId = 'p7', name = 'Running Shoes', category = 'Sports', price = 89.99, embedding = [0.1, 0.1, 0.9, 0.1];
INSERT INTO Product SET productId = 'p8', name = 'Yoga Mat', category = 'Sports', price = 29.99, embedding = [0.1, 0.1, 0.8, 0.2];
-- PURCHASED edges (u1+u2 share Laptop and Phone -> collab recommends ML Textbook to u1)
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u1') TO (SELECT FROM Product WHERE productId = 'p1');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u1') TO (SELECT FROM Product WHERE productId = 'p2');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u1') TO (SELECT FROM Product WHERE productId = 'p3');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u2') TO (SELECT FROM Product WHERE productId = 'p1');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u2') TO (SELECT FROM Product WHERE productId = 'p2');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u2') TO (SELECT FROM Product WHERE productId = 'p4');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u3') TO (SELECT FROM Product WHERE productId = 'p4');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u3') TO (SELECT FROM Product WHERE productId = 'p5');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u3') TO (SELECT FROM Product WHERE productId = 'p6');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u4') TO (SELECT FROM Product WHERE productId = 'p7');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u4') TO (SELECT FROM Product WHERE productId = 'p8');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u5') TO (SELECT FROM Product WHERE productId = 'p1');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u5') TO (SELECT FROM Product WHERE productId = 'p5');
CREATE EDGE PURCHASED FROM (SELECT FROM User WHERE userId = 'u5') TO (SELECT FROM Product WHERE productId = 'p7');
-- === Maintenance Domain: Equipment ===
INSERT INTO Equipment SET equipmentId = 'eq1', name = 'Main Compressor', specifications = 'Industrial 500HP', failureRate = 0.02;
INSERT INTO Equipment SET equipmentId = 'eq2', name = 'Cooling Unit A', specifications = 'Glycol cooling 200kW', failureRate = 0.05;
INSERT INTO Equipment SET equipmentId = 'eq3', name = 'Pump Station B', specifications = 'Centrifugal 150GPM', failureRate = 0.03;
INSERT INTO Equipment SET equipmentId = 'eq4', name = 'Generator Alpha', specifications = 'Diesel 800kVA', failureRate = 0.01;
INSERT INTO Equipment SET equipmentId = 'eq5', name = 'Control Panel C', specifications = 'PLC-based HMI', failureRate = 0.08;
-- DEPENDS_ON edges (eq2,eq3 depend on eq1; eq5 depends on eq4; eq4 depends on eq1)
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq2') TO (SELECT FROM Equipment WHERE equipmentId = 'eq1') SET criticality = 'high';
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq3') TO (SELECT FROM Equipment WHERE equipmentId = 'eq1') SET criticality = 'medium';
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq4') TO (SELECT FROM Equipment WHERE equipmentId = 'eq1') SET criticality = 'high';
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Equipment WHERE equipmentId = 'eq5') TO (SELECT FROM Equipment WHERE equipmentId = 'eq4') SET criticality = 'high';
-- Sensors
INSERT INTO Sensor SET sensorId = 's1', sensorType = 'temperature', unit = 'celsius';
INSERT INTO Sensor SET sensorId = 's2', sensorType = 'vibration', unit = 'mm_per_sec';
INSERT INTO Sensor SET sensorId = 's3', sensorType = 'pressure', unit = 'bar';
-- MONITORED_BY edges
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq1') TO (SELECT FROM Sensor WHERE sensorId = 's1');
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq1') TO (SELECT FROM Sensor WHERE sensorId = 's2');
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq2') TO (SELECT FROM Sensor WHERE sensorId = 's1');
CREATE EDGE MONITORED_BY FROM (SELECT FROM Equipment WHERE equipmentId = 'eq3') TO (SELECT FROM Sensor WHERE sensorId = 's3');
-- SensorReading documents (eq1 showing anomalous high temperature and vibration)
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 85.2, vibration = 4.5, pressure = 6.1, recordedAt = '2026-03-15 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 92.1, vibration = 5.8, pressure = 6.3, recordedAt = '2026-03-16 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 98.5, vibration = 7.2, pressure = 6.5, recordedAt = '2026-03-17 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq1', temperature = 105.3, vibration = 9.1, pressure = 6.8, recordedAt = '2026-03-18 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 42.1, vibration = 1.2, pressure = 4.5, recordedAt = '2026-03-15 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 43.0, vibration = 1.3, pressure = 4.6, recordedAt = '2026-03-16 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 41.8, vibration = 1.1, pressure = 4.4, recordedAt = '2026-03-17 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq2', temperature = 42.5, vibration = 1.2, pressure = 4.5, recordedAt = '2026-03-18 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 55.0, vibration = 2.0, pressure = 8.1, recordedAt = '2026-03-15 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 54.5, vibration = 2.1, pressure = 8.0, recordedAt = '2026-03-16 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 56.2, vibration = 1.9, pressure = 8.2, recordedAt = '2026-03-17 08:00:00';
INSERT INTO SensorReading SET equipmentId = 'eq3', temperature = 55.8, vibration = 2.0, pressure = 8.1, recordedAt = '2026-03-18 08:00:00';
-- === Feature Store Infrastructure: FeatureSnapshots ===
INSERT INTO FeatureSnapshot SET entityId = 'a1', entityType = 'Account', featureVector = [4, 3, 5, 12, 2950, 0.15], computedAt = '2026-03-15 00:00:00', modelVersion = 'fraud-v2.1';
INSERT INTO FeatureSnapshot SET entityId = 'a4', entityType = 'Account', featureVector = [8, 6, 3, 67, 145000, 0.87], computedAt = '2026-03-15 00:00:00', modelVersion = 'fraud-v2.1';
INSERT INTO FeatureSnapshot SET entityId = 'a6', entityType = 'Account', featureVector = [11, 5, 1, 100, 275000, 0.99], computedAt = '2026-03-15 00:00:00', modelVersion = 'fraud-v2.1';
