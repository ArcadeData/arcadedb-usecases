-- Suppliers
INSERT INTO Supplier SET name = 'Shenzhen Micro Ltd', country = 'China', risk_score = 0.7, lead_time_avg = 14, quality_score = 0.85, certifications = 'ISO-9001', status = 'active', capability_vec = [0.9, 0.2, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Taiwan Semi Corp', country = 'Taiwan', risk_score = 0.3, lead_time_avg = 10, quality_score = 0.95, certifications = 'ISO-9001,ISO-14001', status = 'active', capability_vec = [0.8, 0.1, 0.3, 0.1];
INSERT INTO Supplier SET name = 'Seoul Chip Inc', country = 'South Korea', risk_score = 0.4, lead_time_avg = 12, quality_score = 0.90, certifications = 'ISO-9001', status = 'active', capability_vec = [0.85, 0.15, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Berlin Sensors GmbH', country = 'Germany', risk_score = 0.2, lead_time_avg = 8, quality_score = 0.98, certifications = 'ISO-9001,RoHS', status = 'active', capability_vec = [0.2, 0.9, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Sao Paulo Materials', country = 'Brazil', risk_score = 0.5, lead_time_avg = 21, quality_score = 0.80, certifications = 'ISO-14001', status = 'active', capability_vec = [0.1, 0.1, 0.9, 0.1];
INSERT INTO Supplier SET name = 'Tokyo Electronics', country = 'Japan', risk_score = 0.15, lead_time_avg = 7, quality_score = 0.97, certifications = 'ISO-9001,ISO-14001,RoHS', status = 'active', capability_vec = [0.85, 0.3, 0.1, 0.1];
INSERT INTO Supplier SET name = 'Mumbai Parts Ltd', country = 'India', risk_score = 0.45, lead_time_avg = 16, quality_score = 0.82, certifications = 'ISO-9001', status = 'active', capability_vec = [0.7, 0.1, 0.3, 0.2];
-- Components
INSERT INTO Component SET name = 'Microcontroller';
INSERT INTO Component SET name = 'Sensor Module';
INSERT INTO Component SET name = 'Circuit Board';
INSERT INTO Component SET name = 'Display Panel';
INSERT INTO Component SET name = 'Battery Pack';
-- Products
INSERT INTO Product SET sku = 'WIDGET-PRO-X', name = 'Widget Pro X', revenue_annual = 2500000.00, batch = 'BATCH-2026-0218';
INSERT INTO Product SET sku = 'WIDGET-LITE', name = 'Widget Lite', revenue_annual = 800000.00, batch = 'BATCH-2026-0301';
INSERT INTO Product SET sku = 'SENSOR-HUB-1', name = 'Sensor Hub', revenue_annual = 1200000.00, batch = 'BATCH-2026-0115';
-- Warehouses
INSERT INTO Warehouse SET name = 'US-East', stock_weeks = 6;
INSERT INTO Warehouse SET name = 'EU-Central', stock_weeks = 4;
INSERT INTO Warehouse SET name = 'APAC-South', stock_weeks = 3;
-- Customers
INSERT INTO Customer SET customerId = 'CUST-001', contact_email = 'ops@acmecorp.com';
INSERT INTO Customer SET customerId = 'CUST-002', contact_email = 'procurement@globex.com';
INSERT INTO Customer SET customerId = 'CUST-003', contact_email = 'supply@initech.com';
-- Shipping Routes
INSERT INTO ShippingRoute SET name = 'US-Express', transit_days = 3, cost = 450.00;
INSERT INTO ShippingRoute SET name = 'EU-Standard', transit_days = 7, cost = 200.00;
INSERT INTO ShippingRoute SET name = 'APAC-Freight', transit_days = 14, cost = 150.00;
-- Raw Materials
INSERT INTO RawMaterial SET name = 'Silicon Wafer', origin = 'Taiwan', certification = 'ISO-9001', lot = 'LOT-2026-001';
INSERT INTO RawMaterial SET name = 'Copper Wire', origin = 'Chile', certification = 'RoHS', lot = 'LOT-2026-002';
INSERT INTO RawMaterial SET name = 'Lithium', origin = 'Australia', certification = 'ISO-14001', lot = 'LOT-2026-003';
INSERT INTO RawMaterial SET name = 'Glass Substrate', origin = 'Japan', certification = 'ISO-9001', lot = 'LOT-2026-004';
INSERT INTO RawMaterial SET name = 'Rare Earth Elements', origin = 'China', certification = 'REACH', lot = 'LOT-2026-005';
-- SUPPLIES edges (multi-tier supply chain)
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Sao Paulo Materials') TO (SELECT FROM Supplier WHERE name = 'Taiwan Semi Corp');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Taiwan Semi Corp') TO (SELECT FROM Supplier WHERE name = 'Shenzhen Micro Ltd');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Seoul Chip Inc') TO (SELECT FROM Supplier WHERE name = 'Shenzhen Micro Ltd');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Shenzhen Micro Ltd') TO (SELECT FROM Component WHERE name = 'Microcontroller');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Berlin Sensors GmbH') TO (SELECT FROM Component WHERE name = 'Sensor Module');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Mumbai Parts Ltd') TO (SELECT FROM Component WHERE name = 'Circuit Board');
CREATE EDGE SUPPLIES FROM (SELECT FROM Supplier WHERE name = 'Tokyo Electronics') TO (SELECT FROM Component WHERE name = 'Display Panel');
-- ALTERNATIVE_FOR edges
CREATE EDGE ALTERNATIVE_FOR FROM (SELECT FROM Supplier WHERE name = 'Tokyo Electronics') TO (SELECT FROM Component WHERE name = 'Microcontroller');
CREATE EDGE ALTERNATIVE_FOR FROM (SELECT FROM Supplier WHERE name = 'Seoul Chip Inc') TO (SELECT FROM Component WHERE name = 'Circuit Board');
-- CONTAINS edges (bill of materials)
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Circuit Board') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Display Panel') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Battery Pack') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
CREATE EDGE `CONTAINS` FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
-- ASSEMBLED_FROM edges (traceability: RawMaterial -> Component -> Product)
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Silicon Wafer') TO (SELECT FROM Component WHERE name = 'Microcontroller');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Copper Wire') TO (SELECT FROM Component WHERE name = 'Circuit Board');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Rare Earth Elements') TO (SELECT FROM Component WHERE name = 'Sensor Module');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Glass Substrate') TO (SELECT FROM Component WHERE name = 'Display Panel');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM RawMaterial WHERE name = 'Lithium') TO (SELECT FROM Component WHERE name = 'Battery Pack');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Circuit Board') TO (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Display Panel') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Battery Pack') TO (SELECT FROM Product WHERE sku = 'WIDGET-LITE');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Sensor Module') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
CREATE EDGE ASSEMBLED_FROM FROM (SELECT FROM Component WHERE name = 'Microcontroller') TO (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1');
-- STORED_AT edges
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Warehouse WHERE name = 'US-East');
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Warehouse WHERE name = 'EU-Central');
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'WIDGET-LITE') TO (SELECT FROM Warehouse WHERE name = 'EU-Central');
CREATE EDGE STORED_AT FROM (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1') TO (SELECT FROM Warehouse WHERE name = 'APAC-South');
-- SHIPS_VIA edges
CREATE EDGE SHIPS_VIA FROM (SELECT FROM Warehouse WHERE name = 'US-East') TO (SELECT FROM ShippingRoute WHERE name = 'US-Express');
CREATE EDGE SHIPS_VIA FROM (SELECT FROM Warehouse WHERE name = 'EU-Central') TO (SELECT FROM ShippingRoute WHERE name = 'EU-Standard');
CREATE EDGE SHIPS_VIA FROM (SELECT FROM Warehouse WHERE name = 'APAC-South') TO (SELECT FROM ShippingRoute WHERE name = 'APAC-Freight');
-- SHIPPED_TO edges
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Customer WHERE customerId = 'CUST-001');
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'WIDGET-LITE') TO (SELECT FROM Customer WHERE customerId = 'CUST-002');
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'SENSOR-HUB-1') TO (SELECT FROM Customer WHERE customerId = 'CUST-003');
CREATE EDGE SHIPPED_TO FROM (SELECT FROM Product WHERE sku = 'WIDGET-PRO-X') TO (SELECT FROM Customer WHERE customerId = 'CUST-003');
-- DeliveryMetric documents (time-series delivery performance data)
INSERT INTO DeliveryMetric SET supplierId = 'Shenzhen Micro Ltd', lead_time_hrs = 336, on_time = true, delayed = false, quantity = 500, recordedAt = '2026-01-15 08:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Shenzhen Micro Ltd', lead_time_hrs = 400, on_time = false, delayed = true, quantity = 300, recordedAt = '2026-02-01 10:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Shenzhen Micro Ltd', lead_time_hrs = 360, on_time = true, delayed = false, quantity = 450, recordedAt = '2026-02-20 09:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Taiwan Semi Corp', lead_time_hrs = 240, on_time = true, delayed = false, quantity = 1000, recordedAt = '2026-01-10 07:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Taiwan Semi Corp', lead_time_hrs = 250, on_time = true, delayed = false, quantity = 800, recordedAt = '2026-02-05 11:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Berlin Sensors GmbH', lead_time_hrs = 192, on_time = true, delayed = false, quantity = 200, recordedAt = '2026-01-20 06:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Berlin Sensors GmbH', lead_time_hrs = 200, on_time = true, delayed = false, quantity = 250, recordedAt = '2026-02-15 08:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Mumbai Parts Ltd', lead_time_hrs = 420, on_time = false, delayed = true, quantity = 600, recordedAt = '2026-01-25 09:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Mumbai Parts Ltd', lead_time_hrs = 384, on_time = true, delayed = false, quantity = 550, recordedAt = '2026-02-10 10:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Mumbai Parts Ltd', lead_time_hrs = 450, on_time = false, delayed = true, quantity = 400, recordedAt = '2026-03-01 07:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Tokyo Electronics', lead_time_hrs = 168, on_time = true, delayed = false, quantity = 350, recordedAt = '2026-01-18 08:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Tokyo Electronics', lead_time_hrs = 175, on_time = true, delayed = false, quantity = 400, recordedAt = '2026-02-22 09:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Seoul Chip Inc', lead_time_hrs = 288, on_time = true, delayed = false, quantity = 700, recordedAt = '2026-01-30 10:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Seoul Chip Inc', lead_time_hrs = 310, on_time = false, delayed = true, quantity = 650, recordedAt = '2026-02-25 11:00:00';
INSERT INTO DeliveryMetric SET supplierId = 'Sao Paulo Materials', lead_time_hrs = 504, on_time = false, delayed = true, quantity = 2000, recordedAt = '2026-02-01 06:00:00';
