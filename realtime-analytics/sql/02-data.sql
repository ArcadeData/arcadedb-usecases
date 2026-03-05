-- Buildings
INSERT INTO Building SET name = 'HQ'
INSERT INTO Building SET name = 'Data Center'
-- Floors
INSERT INTO Floor SET name = 'HQ-1', level = 1
INSERT INTO Floor SET name = 'HQ-2', level = 2
INSERT INTO Floor SET name = 'DC-1', level = 1
INSERT INTO Floor SET name = 'DC-2', level = 2
-- Sensors
INSERT INTO Sensor SET name = 'Temp Sensor A', sensor_id = 's-A'
INSERT INTO Sensor SET name = 'Temp Sensor B', sensor_id = 's-B'
INSERT INTO Sensor SET name = 'Temp Sensor C', sensor_id = 's-C'
INSERT INTO Sensor SET name = 'Temp Sensor D', sensor_id = 's-D'
INSERT INTO Sensor SET name = 'Temp Sensor E', sensor_id = 's-E'
INSERT INTO Sensor SET name = 'Temp Sensor F', sensor_id = 's-F'
-- Servers
INSERT INTO Server SET name = 'Web Server 1', server_id = 'srv-1'
INSERT INTO Server SET name = 'App Server 2', server_id = 'srv-2'
INSERT INTO Server SET name = 'DB Server 3', server_id = 'srv-3'
-- Services
INSERT INTO Service SET name = 'api-gateway', service_id = 'api-gateway'
INSERT INTO Service SET name = 'auth-service', service_id = 'auth-service'
INSERT INTO Service SET name = 'user-service', service_id = 'user-service'
INSERT INTO Service SET name = 'payment-service', service_id = 'payment-service'
INSERT INTO Service SET name = 'notification-service', service_id = 'notification-service'
-- HAS_FLOOR edges (Building -> Floor)
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'HQ') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'HQ') TO (SELECT FROM Floor WHERE name = 'HQ-2')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'Data Center') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'Data Center') TO (SELECT FROM Floor WHERE name = 'DC-2')
-- INSTALLED_IN edges (Sensor -> Floor)
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-A') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-B') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-C') TO (SELECT FROM Floor WHERE name = 'HQ-2')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-D') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-E') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-F') TO (SELECT FROM Floor WHERE name = 'DC-2')
-- RUNS_ON edges (Service -> Server)
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Server WHERE server_id = 'srv-1')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'auth-service') TO (SELECT FROM Server WHERE server_id = 'srv-1')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'user-service') TO (SELECT FROM Server WHERE server_id = 'srv-2')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'payment-service') TO (SELECT FROM Server WHERE server_id = 'srv-2')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'notification-service') TO (SELECT FROM Server WHERE server_id = 'srv-3')
-- DEPENDS_ON edges (Service -> Service)
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Service WHERE service_id = 'auth-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Service WHERE service_id = 'user-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'user-service') TO (SELECT FROM Service WHERE service_id = 'payment-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'payment-service') TO (SELECT FROM Service WHERE service_id = 'notification-service')
-- SensorReading time-series data (2-hour window, 10-15 min intervals)
-- s-A (HQ-1): regular readings
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-A', 'hq', 22.1, 55.0, 1013.2)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:15:00Z', 's-A', 'hq', 22.3, 55.2, 1013.1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:30:00Z', 's-A', 'hq', 22.5, 55.5, 1013.0)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:45:00Z', 's-A', 'hq', 23.0, 56.0, 1012.9)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-A', 'hq', 23.2, 56.3, 1012.8)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:15:00Z', 's-A', 'hq', 23.8, 57.0, 1012.7)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:30:00Z', 's-A', 'hq', 24.1, 57.5, 1012.6)
-- s-B (HQ-1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-B', 'hq', 21.8, 54.0, 1013.3)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:30:00Z', 's-B', 'hq', 22.0, 54.5, 1013.1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-B', 'hq', 22.5, 55.0, 1012.9)
-- s-C (HQ-2): deliberate gap between 10:15 and 11:00 for interpolation query
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-C', 'hq', 23.0, 58.0, 1013.0)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:15:00Z', 's-C', 'hq', 23.2, 58.2, 1012.9)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-C', 'hq', 25.0, 60.0, 1012.5)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:30:00Z', 's-C', 'hq', 25.5, 61.0, 1012.3)
-- s-D (DC-1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-D', 'dc', 19.0, 45.0, 1014.0)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:30:00Z', 's-D', 'dc', 19.2, 45.5, 1013.9)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-D', 'dc', 19.5, 46.0, 1013.8)
-- s-E (DC-1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-E', 'dc', 18.5, 44.0, 1014.1)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-E', 'dc', 18.8, 44.5, 1014.0)
-- s-F (DC-2)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T10:00:00Z', 's-F', 'dc', 20.0, 48.0, 1013.5)
INSERT INTO SensorReading (ts, sensor_id, location, temperature, humidity, pressure) VALUES ('2026-02-20T11:00:00Z', 's-F', 'dc', 20.5, 48.5, 1013.3)
-- ServiceMetrics time-series data (same 2-hour window)
-- api-gateway on srv-1: high traffic
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'api-gateway', 'srv-1', 15000, 12, 45.2)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'api-gateway', 'srv-1', 15500, 8, 42.1)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:10:00Z', 'api-gateway', 'srv-1', 16200, 15, 48.7)
-- auth-service on srv-1
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'auth-service', 'srv-1', 8000, 3, 22.0)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'auth-service', 'srv-1', 8200, 2, 21.5)
-- user-service on srv-2
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'user-service', 'srv-2', 5000, 5, 35.0)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'user-service', 'srv-2', 5200, 4, 33.8)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:10:00Z', 'user-service', 'srv-2', 5100, 6, 36.5)
-- payment-service on srv-2: some errors
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'payment-service', 'srv-2', 2000, 25, 120.5)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'payment-service', 'srv-2', 2100, 30, 135.2)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:10:00Z', 'payment-service', 'srv-2', 1800, 45, 180.0)
-- notification-service on srv-3
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:00:00Z', 'notification-service', 'srv-3', 3000, 1, 15.0)
INSERT INTO ServiceMetrics (ts, service_id, server_id, request_count, error_count, latency_ms) VALUES ('2026-02-20T10:05:00Z', 'notification-service', 'srv-3', 3100, 0, 14.5)
